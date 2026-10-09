local _, addonTable = ...
local Spekifier = addonTable.Spekifier
-- Presentation arrays never mutate provider results or cached pools.
function Spekifier:BuildLootDisplayLists(result)
    local columns, shared, lists, counts, first = self:GetAllSpecColumns(), {}, {}, {}, {}
    local complete = result and (result.state == "ready" or result.state == "empty") and #columns > 0
    for _, column in ipairs(columns) do
        local data = result and result.specs and result.specs[column.specID]
        if not data or (data.state ~= "ready" and data.state ~= "empty") then complete = false end
    end
    if not complete then return shared, lists, false end
    for _, column in ipairs(columns) do
        local seen = {}
        for _, item in ipairs(result.specs[column.specID].items or {}) do
            local id = item.itemID
            if id and not seen[id] then
                seen[id] = true
                counts[id] = (counts[id] or 0) + 1
                first[id] = first[id] or item
            end
        end
    end
    local sharedIDs = {}
    for id, count in pairs(counts) do
        if count == #columns then sharedIDs[id] = true; shared[#shared + 1] = first[id] end
    end
    -- Stable across delayed refreshes and changes in provider ordering.
    table.sort(shared, function(a, b) return a.itemID < b.itemID end)
    for _, column in ipairs(columns) do
        local items, seen = {}, {}
        for _, item in ipairs(result.specs[column.specID].items or {}) do
            if not sharedIDs[item.itemID] and not seen[item.itemID] then
                items[#items + 1] = item
                if item.itemID then seen[item.itemID] = true end
            end
        end
        lists[column.specID] = items
    end
    return shared, lists, true
end
