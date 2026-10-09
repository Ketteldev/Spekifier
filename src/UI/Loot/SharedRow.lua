-- Shared-item strip and horizontal scrolling.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local UI = addonTable.LootUI
local HideTooltip, ShowItemTooltip = UI.HideTooltip, UI.ShowItemTooltip
function Spekifier:CreateSharedLootRow()
    local window = self:GetMainWindow()
    if window.sharedLoot then return window.sharedLoot end
    local strip = { icons = {}, offset = 0, range = 0, width = window:GetWidth() - 120 }
    window.sharedLoot = strip
    strip.frame = CreateFrame("Frame", nil, window)
    strip.frame:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -90)
    strip.frame:SetSize(window:GetWidth() - 40, 64)
    strip.label = strip.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    strip.label:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", 0, -12)
    strip.label:SetText("Shared:")
    strip.label:SetWidth(72)
    strip.label:SetJustifyH("LEFT")
    strip.scroll = CreateFrame("ScrollFrame", nil, strip.frame)
    strip.scroll:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", 80, 0)
    strip.scroll:SetSize(strip.width, 44)
    strip.content = CreateFrame("Frame", nil, strip.scroll)
    strip.content:SetSize(strip.width, 44)
    strip.scroll:SetScrollChild(strip.content)
    strip.bar = CreateFrame("Slider", nil, strip.frame)
    strip.bar:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", 80, -48)
    strip.bar:SetSize(strip.width, 10)
    strip.bar:SetOrientation("HORIZONTAL")
    strip.bar:SetMinMaxValues(0, 0)
    strip.bar:SetValueStep(1)
    strip.bar:SetObeyStepOnDrag(true)
    strip.bar.track = strip.bar:CreateTexture(nil, "BACKGROUND")
    strip.bar.track:SetAllPoints()
    strip.bar.track:SetColorTexture(0.03, 0.03, 0.03, 0.8)
    strip.bar.thumb = strip.bar:CreateTexture(nil, "ARTWORK")
    strip.bar.thumb:SetSize(24, 10)
    strip.bar.thumb:SetColorTexture(0.75, 0.64, 0.3, 1)
    strip.bar:SetThumbTexture(strip.bar.thumb)
    function strip:ApplyOffset(value)
        value = math.max(0, math.min(self.range, value))
        if value ~= self.offset then
            for _, icon in ipairs(self.icons) do HideTooltip(icon) end
        end
        self.offset = value
        self.scroll:SetHorizontalScroll(value)
    end
    function strip:SetOffset(value)
        self:ApplyOffset(value)
        self.bar:SetValue(self.offset)
    end
    strip.bar:SetScript("OnValueChanged", function(_, value) strip:ApplyOffset(value) end)
    function strip:Scroll(delta) self:SetOffset(self.offset - delta * 48) end
    for _, surface in ipairs({ strip.frame, strip.scroll, strip.content, strip.bar }) do
        surface:EnableMouseWheel(true)
        surface:SetScript("OnMouseWheel", function(_, delta) strip:Scroll(delta) end)
    end
    strip.frame:SetScript("OnHide", function()
        for _, icon in ipairs(strip.icons) do HideTooltip(icon) end
    end)
    strip.frame:Hide()
    return strip
end

function Spekifier:RenderSharedLoot(items)
    local window, state = self:GetMainWindow(), self:GetWindowState()
    local strip = window.sharedLoot
    if not strip and #items == 0 then return end
    strip = strip or self:CreateSharedLootRow()
    for i, item in ipairs(items) do
        local icon = strip.icons[i]
        if not icon then
            -- A mouse-enabled frame supplies tooltips without spec-click routing.
            icon = CreateFrame("Frame", nil, strip.content)
            icon:SetSize(40, 40)
            icon:SetPoint("TOPLEFT", strip.content, "TOPLEFT", (i - 1) * 48, -2)
            icon.icon = icon:CreateTexture(nil, "ARTWORK")
            icon.icon:SetAllPoints()
            icon:EnableMouse(true)
            icon:EnableMouseWheel(true)
            icon:SetScript("OnMouseWheel", function(_, delta) strip:Scroll(delta) end)
            icon:SetScript("OnEnter", ShowItemTooltip)
            icon:SetScript("OnLeave", HideTooltip)
            icon:SetScript("OnHide", HideTooltip)
            strip.icons[i] = icon
        end
        if icon.item and (icon.item.itemID ~= item.itemID or icon.item.link ~= item.link) then HideTooltip(icon) end
        if self.StyleLootElement then self:StyleLootElement(icon, true) end
        icon.item = item
        icon.icon:SetTexture(item.icon or 134400)
        icon:Show()
    end
    for i = #items + 1, #strip.icons do
        local icon = strip.icons[i]
        HideTooltip(icon)
        icon.item = nil
        icon.icon:SetTexture(nil)
        icon:Hide()
    end
    strip.items = items
    local width = math.max(strip.width, #items * 48 - 8)
    strip.content:SetWidth(width)
    strip.range = math.max(0, width - strip.width)
    strip.bar:SetMinMaxValues(0, strip.range)
    strip.bar:SetShown(strip.range > 0)
    if strip.contextKey ~= state.lootBinding then strip.offset = 0 end
    strip.contextKey = state.lootBinding
    strip:SetOffset(strip.offset)
    if self.StyleScrollbar then
        self:StyleScrollbar(strip.bar)
        local textColor = self:GetWindowPalette().text
        strip.label:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
    end
    strip.frame:SetShown(#items > 0)
    -- Retain the full column viewport, reclaiming all strip space when absent.
    if not self.LayoutLootWindow then window:SetHeight(#items > 0 and 784 or 720) end
    local columns = self:GetAllSpecColumns()
    local step = (window:GetWidth() - 40) / math.max(1, #columns)
    for i, column in ipairs(columns) do
        column.frame:ClearAllPoints()
        column.frame:SetPoint("TOPLEFT", window, "TOPLEFT", 20 + (i - 1) * step, #items > 0 and -154 or -90)
    end
    if self.LayoutLootWindow then self:LayoutLootWindow() end
    self:FitLootWindow()
end
