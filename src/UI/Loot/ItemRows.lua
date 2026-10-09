-- Pooled item buttons with tooltip, scrolling and selection routing.
local _, addonTable = ...
local UI = addonTable.LootUI
local HideTooltip, ShowItemTooltip, ReadableFont = UI.HideTooltip, UI.ShowItemTooltip, UI.ReadableFont
local rowHeight = UI.rowHeight
local function CreateRow(self, column, index)
    local row = CreateFrame("Button", nil, column.content)
    row:SetSize(column.listWidth, rowHeight)
    row:SetPoint("TOPLEFT", column.content, "TOPLEFT", 0, -(index - 1) * rowHeight)
    row:RegisterForClicks("LeftButtonUp")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(40, 40)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ReadableFont(row.name, 18)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 52, -4)
    row.name:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 4)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(true)
    row:SetScript("OnClick", function(_, button) self:HandleSpecColumnClick(column.specID, button) end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) column:Scroll(delta) end)
    row:SetScript("OnEnter", ShowItemTooltip)
    row:SetScript("OnLeave", HideTooltip)
    row:SetScript("OnHide", HideTooltip)
    if self.StyleLootElement then self:StyleLootElement(row) end
    column.rows[index] = row
    return row
end


UI.CreateRow = CreateRow
