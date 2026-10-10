-- Journal selection tracking and query/restore transactions.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local Provider = Spekifier.LootProvider
local Copy = addonTable.Loot.Copy
local CompleteItem = addonTable.Loot.CompleteItem
local trackedInstance, trackedEncounter
function Provider:InitializeJournal()
    -- No public selected-instance getter in Retail. Observe later selections;
    -- Blizzard UI fields supply any selection made before this module loaded.
    if hooksecurefunc and EJ_SelectInstance and EJ_SelectEncounter then
        hooksecurefunc("EJ_SelectInstance", function(id)
            trackedInstance, trackedEncounter = id, nil
        end)
        hooksecurefunc("EJ_SelectEncounter", function(id) trackedEncounter = id end)
    end
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
    for _, id in ipairs({ 1, 2, 8, 14, 15, 16, 17, 23, 24, 33, 233, 250 }) do
        if EJ_IsValidInstanceDifficulty(id) then available[#available + 1] = id end
    end
    return { requestedID = requested, baseID = base, availableIDs = available }
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
            -- Exclude bonus dungeon loot and out-of-season items using
            -- Blizzard's shared boss-pool and seasonal visibility rules.
            elseif not (c.kind == "dungeon" and info.displayAsPerPlayerLoot) and
                not (info.displaySeasonID and C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID and
                    info.displaySeasonID ~= C_SeasonInfo.GetCurrentDisplaySeasonID()) and
                not seen[info.itemID] then
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
        local classID, restoredSpecID = EJ_GetLootFilter()
        return EJ_GetDifficulty() == old.difficulty and classID == old.classID and
            restoredSpecID == old.specID and C_EncounterJournal.GetSlotFilter() == old.slot
    end)
    if not restored or not verified or not matches then
        return { state = "failed", reason = "journal-restore-failed", items = {} }
    end
    if not ok then return { state = "failed", reason = "journal-query-failed", items = {} } end
    return result
end
