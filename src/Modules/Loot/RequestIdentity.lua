-- Shared identity for visible and diagnostic requests.
local _, addonTable = ...
local function PlayerLootRequest(self, context)
    local classID
    if UnitClass then classID = select(3, UnitClass("player")) end
    local specs = {}
    for _, column in ipairs(self:GetAllSpecColumns()) do specs[#specs + 1] = column.specID end
    local binding = context and table.concat({ context.contextKey, context.kind, context.lootMode,
        context.rewardSource and context.rewardSource.kind or "raid",
        context.rewardSource and context.rewardSource.challengeModeID or 0,
        context.difficultyID, context.journalInstanceID,
        context.encounterID or context.challengeModeID, classID or 0,
        C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID() or 0,
        table.concat(specs, ",") }, ":") or nil
    return binding, classID, specs
end


addonTable.PlayerLootRequest = PlayerLootRequest
