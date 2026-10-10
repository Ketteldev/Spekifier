-- Tooltip ownership and readable font sizing for loot surfaces.
local _, addonTable = ...
local function HideTooltip(row)
    if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function ReadableFont(text, size)
    local font, _, flags = text:GetFont()
    text:SetFont(font, size, flags)
end

local function ShowItemTooltip(row)
    local item = row.item
    if not item or not GameTooltip then return end
    GameTooltip:Hide()
    GameTooltip:SetParent(UIParent)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    if item.link then
        -- Match Blizzard's Journal tooltip path, with native comparisons.
        -- ProcessInfo retains the original link and tooltip-data addon hooks.
        local info = CreateBaseTooltipInfo("GetHyperlink", item.link)
        info.compareItem = true
        GameTooltip:ProcessInfo(info)
    else
        GameTooltip:SetText(item.name or "Loading item...")
    end
    GameTooltip:SetAlpha(1)
    GameTooltip:Show()
end


addonTable.LootUI = { HideTooltip = HideTooltip, ShowItemTooltip = ShowItemTooltip,
    ReadableFont = ReadableFont, rowHeight = 64, listHeight = 420 }
