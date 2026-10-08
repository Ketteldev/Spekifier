-- Request/result API independent of UI frames; events belong to this module.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local Provider = { cache = {}, cacheOrder = {}, generation = 0 }
Spekifier.LootProvider = Provider
local MAX_ATTEMPTS, MAX_CACHE = 6, 64
local trackedInstance, trackedEncounter
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = Copy(v) end
    return result
end
local function Key(c, classID, specID)
    return table.concat({ c.kind, c.instanceID, c.journalInstanceID,
        c.encounterID or 0, c.challengeModeID or 0, c.difficultyID, c.lootMode,
        c.rewardSource and c.rewardSource.kind or "raid",
        c.rewardSource and c.rewardSource.challengeModeID or 0,
        C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID() or 0,
        classID, specID }, ":")
end
local function Validate(c, classID, specs)
    if type(c) ~= "table" or type(classID) ~= "number" or classID <= 0 or
        type(specs) ~= "table" or #specs == 0 then return "invalid-request" end
    for _, field in ipairs({ "instanceID", "journalInstanceID", "difficultyID" }) do
        if type(c[field]) ~= "number" or c[field] <= 0 then return "invalid-context" end
    end
    for _, id in ipairs(specs) do
        if type(id) ~= "number" or id <= 0 then return "invalid-specialization" end
    end
    if c.kind == "raid" and c.lootMode == "raid" and
        type(c.encounterID) == "number" and c.encounterID > 0 then return end
    if c.kind == "dungeon" and c.lootMode == "mythic-plus" and
        (c.difficultyID == 23 or c.difficultyID == 8) and
        type(c.visitID) == "number" and type(c.challengeModeID) == "number" and
        c.rewardSource and c.rewardSource.kind == "challenge-mode-end-of-run" and
        c.rewardSource.challengeModeID == c.challengeModeID then return end
    return "unsupported-context"
end
function Provider:Initialize()
    if self.frame then return end
    -- No public selected-instance getter in Retail. Observe later selections;
    -- Blizzard UI fields supply any selection made before this module loaded.
    if hooksecurefunc and EJ_SelectInstance and EJ_SelectEncounter then
        hooksecurefunc("EJ_SelectInstance", function(id)
            trackedInstance, trackedEncounter = id, nil
        end)
        hooksecurefunc("EJ_SelectEncounter", function(id) trackedEncounter = id end)
    end
    self.frame = CreateFrame("Frame")
    for _, event in ipairs({ "EJ_LOOT_DATA_RECIEVED", "GET_ITEM_INFO_RECEIVED",
        "ITEM_DATA_LOAD_RESULT", "CHALLENGE_MODE_MAPS_UPDATE", "PLAYER_REGEN_ENABLED" }) do
        self.frame:RegisterEvent(event)
    end
    self.frame:SetScript("OnEvent", function(_, event, itemID, success)
        self:OnEvent(event, itemID, success)
    end)
end
function Provider:Cancel(token)
    if self.active and (not token or self.active.token == token) then self.active = nil end
end
function Provider:IsCurrent(r)
    return self.active == r and (not r.isCurrent or r.isCurrent(r.context))
end
function Provider:Publish(r)
    if not self:IsCurrent(r) then return end
    local result = { state = "ready", context = Copy(r.context), classID = r.classID,
        specs = Copy(r.results), token = r.token }
    local empty, pending, failure, failureReason = true, false, nil, nil
    for _, id in ipairs(r.specs) do
        local spec = result.specs[id]
        if not spec or spec.state == "loading" then pending = true end
        if spec and (spec.state == "failed" or spec.state == "unsupported") then
            failure, failureReason = spec.state, spec.reason
        end
        if spec and #spec.items > 0 then empty = false end
    end
    result.state = pending and "loading" or failure or (empty and "empty" or "ready")
    result.reason = failureReason
    r.state = result.state
    r.callback(result)
end
function Provider:Remember(key, result)
    if not self.cache[key] then
        self.cacheOrder[#self.cacheOrder + 1] = key
        if #self.cacheOrder > MAX_CACHE then self.cache[table.remove(self.cacheOrder, 1)] = nil end
    end
    self.cache[key] = Copy(result)
end
local function APIsAvailable()
    for _, name in ipairs({ "EJ_SelectInstance", "EJ_SelectEncounter", "EJ_GetDifficulty",
        "EJ_SetDifficulty", "EJ_GetLootFilter", "EJ_SetLootFilter", "EJ_GetNumLoot",
        "EJ_IsLootListOutOfDate", "EJ_IsValidInstanceDifficulty" }) do
        if type(_G[name]) ~= "function" then return false end
    end
    return C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex and
        C_EncounterJournal.GetSlotFilter and C_EncounterJournal.ResetSlotFilter and
        C_EncounterJournal.SetSlotFilter
end
local function DifficultyDiagnostics(requested)
    local base = C_EncounterJournal.GetBaseDifficultyID and
        C_EncounterJournal.GetBaseDifficultyID(requested) or requested
    local available = {}
    for _, id in ipairs({ 1, 2, 8, 14, 15, 16, 17, 23, 24, 33 }) do
        if EJ_IsValidInstanceDifficulty(id) then available[#available + 1] = id end
    end
    return { requestedID = requested, baseID = base, availableIDs = available }
end

local function CompleteItem(item)
    -- Preserve the Journal's bonus-bearing link rather than synthesizing one.
    if (not item.name or not item.icon) and C_Item and C_Item.GetItemInfo then
        local name, _, quality, level, _, _, _, _, equipLoc, icon =
            C_Item.GetItemInfo(item.link or item.itemID)
        item.name, item.icon = item.name or name, item.icon or icon
        item.quality, item.equipLoc, item.itemLevel = quality, equipLoc, level
    end
    return item.name and item.icon and item.link
end
-- Synchronous shared-state transaction. Search uses a separate result list,
-- so it is left untouched. Never load/open the Adventure Guide to query loot.
function Provider:Query(r, specID)
    if not APIsAvailable() then return { state = "unsupported", reason = "loot-api-unavailable", items = {} } end
    local journal = EncounterJournal
    if journal and not self.hookedJournal and journal.HookScript then
        self.hookedJournal = journal
        journal:HookScript("OnHide", function() self:ResumeBlocked("adventure-guide-open") end)
    end
    if journal and journal:IsShown() then return { state = "loading", reason = "adventure-guide-open", items = {} } end
    if InCombatLockdown() then return { state = "loading", reason = "combat", items = {} } end
    local c = r.context
    local old = { instance = trackedInstance or (journal and journal.instanceID),
        encounter = (not trackedInstance and journal and journal.encounterID) or trackedEncounter,
        difficulty = EJ_GetDifficulty(), slot = C_EncounterJournal.GetSlotFilter() }
    old.classID, old.specID = EJ_GetLootFilter()
    local ok, result = pcall(function()
        EJ_SelectInstance(c.journalInstanceID)
        -- Dungeon-wide Mythic boss loot supplies the comparison pool. The
        -- context retains actual entry difficulty and Mythic+ reward mode.
        local difficulty = c.kind == "dungeon" and 23 or c.difficultyID
        if not EJ_IsValidInstanceDifficulty(difficulty) then
            return { state = "unsupported", reason = "journal-difficulty-unavailable", items = {},
                difficultyDiagnostics = DifficultyDiagnostics(difficulty),
                explanation = c.kind == "dungeon" and
                    "This dungeon has no supported Mythic Journal loot table for the combined boss pool." or
                    "The selected Journal instance does not support the requested raid difficulty." }
        end
        EJ_SetDifficulty(difficulty)
        if EJ_GetDifficulty() ~= difficulty then
            return { state = "unsupported", reason = "journal-difficulty-mismatch", items = {} }
        end
        if c.kind == "raid" then EJ_SelectEncounter(c.encounterID) end
        EJ_SetLootFilter(r.classID, specID)
        C_EncounterJournal.ResetSlotFilter()
        local items, seen, pending = {}, {}, false
        local metadataOnly = true
        local completeness = { missingRows = 0, missingNames = 0, missingIcons = 0, missingLinks = 0,
            journalOutOfDate = not not EJ_IsLootListOutOfDate() }
        local count = EJ_GetNumLoot()
        if type(count) ~= "number" or count < 0 then error("Invalid loot count") end
        for index = 1, count do
            local info = C_EncounterJournal.GetLootInfoByIndex(index)
            if not info or not info.itemID then
                pending, metadataOnly = true, false
                completeness.missingRows = completeness.missingRows + 1
            elseif c.kind == "dungeon" and info.displayAsPerPlayerLoot then
                -- Blizzard categorizes these as bonus loot (e.g. recipes),
                -- rather than the shared specialization-dependent boss pool.
            elseif info.displaySeasonID and C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID and
                info.displaySeasonID ~= C_SeasonInfo.GetCurrentDisplaySeasonID() then
                -- Match Blizzard's seasonal loot visibility rule.
            elseif not seen[info.itemID] then
                seen[info.itemID] = true
                local item = Copy(info)
                if not CompleteItem(item) then
                    pending = true
                    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item.itemID) end
                end
                if not item.name then completeness.missingNames = completeness.missingNames + 1 end
                if not item.icon then completeness.missingIcons = completeness.missingIcons + 1 end
                if not item.link then completeness.missingLinks = completeness.missingLinks + 1 end
                if c.kind == "dungeon" then
                    item.itemLevel, item.rewardItemLevelKnown = nil, false
                end
                items[#items + 1] = item
            end
        end
        completeness.journalOutOfDate = completeness.journalOutOfDate or not not EJ_IsLootListOutOfDate()
        -- Blizzard's loot UI enumerates the full list even when this refresh
        -- flag is set. It is not a veto on fully populated nonempty results.
        -- A zero count with that flag still cannot prove an empty loot pool.
        if count == 0 and completeness.journalOutOfDate then pending, metadataOnly = true, false end
        return { state = pending and "loading" or (#items == 0 and "empty" or "ready"),
            items = items, metadataOnly = metadataOnly, completeness = completeness, journalDifficultyID = difficulty,
            rewardItemLevelKnown = c.kind ~= "dungeon" }
    end)
    -- An error restoring one field must not skip the remaining setters.
    local restored = true
    local function Restore(fn, ...)
        local success = pcall(fn, ...)
        restored = restored and success
    end
    if old.instance then
        Restore(EJ_SelectInstance, old.instance)
        if old.encounter then Restore(EJ_SelectEncounter, old.encounter) end
    end
    Restore(EJ_SetDifficulty, old.difficulty)
    Restore(EJ_SetLootFilter, old.classID, old.specID)
    Restore(C_EncounterJournal.SetSlotFilter, old.slot)
    local verified, matches = pcall(function()
        local classID, specID = EJ_GetLootFilter()
        return EJ_GetDifficulty() == old.difficulty and classID == old.classID and
            specID == old.specID and C_EncounterJournal.GetSlotFilter() == old.slot
    end)
    if not restored or not verified or not matches then
        return { state = "failed", reason = "journal-restore-failed", items = {} }
    end
    if not ok then return { state = "failed", reason = "journal-query-failed", items = {} } end
    return result
end
function Provider:FinishTimeout(r, reason)
    for _, id in ipairs(r.specs) do
        local result = r.results[id]
        if result.state == "loading" then
            result.waitReason = result.reason
            result.state, result.reason = "failed", reason
        end
    end
    self:Publish(r)
end
function Provider:Schedule(r)
    if r.scheduled or not self:IsCurrent(r) or r.state ~= "loading" then return end
    if not C_Timer or not C_Timer.After then self:FinishTimeout(r, "retry-api-unavailable"); return end
    r.scheduled = true
    C_Timer.After(1, function()
        r.scheduled = false
        if self:IsCurrent(r) and r.state == "loading" then self:Run(r) end
    end)
end
function Provider:Run(r)
    if not self:IsCurrent(r) or self.busy then return end
    self.busy = true
    r.attempts = r.attempts + 1
    for _, id in ipairs(r.specs) do
        local result = r.results[id]
        if result.state == "loading" then
            local ok, queried = pcall(self.Query, self, r, id)
            result = ok and queried or { state = "failed", reason = "journal-query-failed", items = {} }
            r.results[id] = result
            if result.state == "ready" or result.state == "empty" then
                self:Remember(Key(r.context, r.classID, id), result)
            end
        end
    end
    self.busy = false
    self:Publish(r)
    if r.attempts >= MAX_ATTEMPTS and r.state == "loading" then self:FinishTimeout(r, "loot-data-timeout")
    else self:Schedule(r) end
end
-- A replacement cancels the previous comparison. Context/visit delivery is
-- separately guarded; cache entries can be reused across targets and visits.
function Provider:Request(context, classID, specs, callback, isCurrent)
    self:Initialize()
    self:Cancel()
    self.generation = self.generation + 1
    local r = { token = self.generation, context = Copy(context), classID = classID,
        specs = Copy(specs), callback = callback, isCurrent = isCurrent, results = {}, attempts = 0 }
    self.active = r
    local reason = Validate(context, classID, specs)
    if reason then
        r.state = "unsupported"
        if self:IsCurrent(r) then callback({ state = "unsupported", reason = reason,
            context = Copy(context), specs = {}, token = r.token }) end
        return r.token
    end
    for _, id in ipairs(specs) do
        r.results[id] = Copy(self.cache[Key(context, classID, id)]) or { state = "loading", items = {} }
    end
    self:Publish(r)
    if self:IsCurrent(r) and r.state == "loading" then
        if self.busy then self:Schedule(r) else self:Run(r) end
    end
    return r.token
end
function Provider:Invalidate()
    self.cache, self.cacheOrder = {}, {}
end
function Provider:ResumeBlocked(reason)
    local r = self.active
    if not r or not self:IsCurrent(r) then return end
    local resumed = false
    for _, result in pairs(r.results) do
        if result.state == "failed" and result.reason == "loot-data-timeout" and result.waitReason == reason then
            result.state, result.reason, result.waitReason = "loading", nil, nil
            resumed = true
        end
    end
    if resumed then r.attempts = 0; self:Publish(r); self:Schedule(r) end
end
function Provider:OnEvent(event, itemID, success)
    if self.busy then return end
    if event == "PLAYER_REGEN_ENABLED" then self:ResumeBlocked("combat") end
    local r = self.active
    if event == "CHALLENGE_MODE_MAPS_UPDATE" then
        self:Invalidate()
        if r and self:IsCurrent(r) then
            for _, id in ipairs(r.specs) do r.results[id] = { state = "loading", items = {} } end
            r.state, r.attempts = "loading", 0
        end
    end
    if not r or not self:IsCurrent(r) then return end
    if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        local relevant = false
        for _, result in pairs(r.results) do
            for _, item in ipairs(result.items) do if item.itemID == itemID then relevant = true end end
        end
        if not relevant or success == false then return end
        -- Late successful item arrival can recover a timed-out list without a
        -- reload. Hydrate known identities directly, without a full EJ query.
        for _, id in ipairs(r.specs) do
            local result, complete = r.results[id], true
            if result.state == "loading" or result.reason == "loot-data-timeout" then
                for _, item in ipairs(result.items) do
                    if not CompleteItem(item) then complete = false end
                    if r.context.kind == "dungeon" then item.itemLevel = nil end
                end
                if #result.items > 0 and complete and result.metadataOnly then
                    result.state, result.reason = "ready", nil
                    if result.completeness then
                        result.completeness.missingNames, result.completeness.missingIcons,
                            result.completeness.missingLinks = 0, 0, 0
                    end
                    self:Remember(Key(r.context, r.classID, id), result)
                end
            end
        end
        self:Publish(r)
    end
    if event == "EJ_LOOT_DATA_RECIEVED" and r.state == "failed" and not r.lateJournalRecovery then
        local recover = false
        for _, result in pairs(r.results) do
            if result.reason == "loot-data-timeout" and not result.waitReason then
                result.state, result.reason = "loading", nil
                recover = true
            end
        end
        -- One additional bounded round after a late Journal completion signal.
        if recover then
            r.lateJournalRecovery, r.attempts = true, 0
            self:Publish(r)
        end
    end
    self:Schedule(r) -- coalesce bursts; every query counts toward the retry bound
end
