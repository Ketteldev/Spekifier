-- Request validation, cache identity and item hydration.
local _, addonTable = ...
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

addonTable.Loot = { Copy = Copy, Key = Key, Validate = Validate, CompleteItem = CompleteItem }
