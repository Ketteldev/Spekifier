-- Coalesced events and recovery of delayed results.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local Provider = Spekifier.LootProvider
local Key = addonTable.Loot.Key
local CompleteItem = addonTable.Loot.CompleteItem
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
