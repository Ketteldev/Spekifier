-- Specialization headers, selection appearance and scrolling.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local UI = addonTable.LootUI
local HideTooltip, ReadableFont = UI.HideTooltip, UI.ReadableFont
local rowHeight, listHeight = UI.rowHeight, UI.listHeight
function Spekifier:RefreshColumnAppearance(column)
    local state = self:GetWindowState()
    local enabled = state.selectionAllowed and state.resolvedContext ~= nil
    local selected = state.resolvedContext ~= nil and state.confirmedSpecID == column.specID
    local hovered = column.frame:IsMouseOver()
    if column.lastEnabled == enabled and column.lastSelected == selected and column.lastHovered == hovered then
        return
    end
    column.lastEnabled, column.lastSelected, column.lastHovered = enabled, selected, hovered
    column.visualState = selected and "selected" or (enabled and "available" or "disabled")
    column.frame.bg:SetColorTexture(selected and 0.12 or 0.08, selected and 0.32 or 0.08,
        selected and 0.18 or 0.08, 0.85)
    if self.GetWindowPalette then
        local p = self:GetWindowPalette()
        local background = selected and p.selected or (enabled and p.bg or p.disabled)
        local accent = p.accent
        column.frame.bg:SetColorTexture(background[1], background[2], background[3], background[4])
        column.hover:SetColorTexture(accent[1], accent[2], accent[3], accent[4])
    end
    column.hover:SetAlpha(hovered and 0.18 or 0)
    column.marker:SetText(selected and "Selected" or (enabled and "Click to select" or "Selection unavailable"))
    column.frame.icon:SetAlpha(1)
end

-- All column surfaces route through the confirmed selection gate.
function Spekifier:HandleSpecColumnClick(specID, button)
    local state = self:GetWindowState()
    if button ~= "LeftButton" or not state.selectionAllowed or not state.resolvedContext or
        InCombatLockdown() then return false end
    if self.SelectLootSpecialization then return self:SelectLootSpecialization(specID) end
    return false
end

function Spekifier:CreateSpecializationColumns()
    local window = self:GetMainWindow()
    if not window or window.specColumns then return end
    local count = GetNumSpecializations() or 0
    if count == 0 then return end
    -- Wait for the complete class catalog rather than keeping partial columns.
    for i = 1, count do
        local id, name, _, icon = GetSpecializationInfo(i)
        if not id or id == 0 or not name or not icon then return end
    end
    window.specColumns = {}
    local width = math.min(1440, math.max(1080, count * 320 + 40))
    if not window.resizeGrip then window:SetSize(width, 720) end
    local step = (width - 40) / count
    for i = 1, count do
        local specID, specName, _, specIcon = GetSpecializationInfo(i)
        if specID then
            local frame = CreateFrame("Button", nil, window)
            frame:SetSize(step - 8, 572)
            frame:SetPoint("TOPLEFT", window, "TOPLEFT", 20 + (i - 1) * step, -102)
            frame:RegisterForClicks("LeftButtonUp")
            frame.bg = frame:CreateTexture(nil, "BACKGROUND")
            frame.bg:SetAllPoints()
            frame.icon = frame:CreateTexture(nil, "ARTWORK")
            frame.icon:SetSize(56, 56)
            frame.icon:SetPoint("TOP", frame, "TOP", 0, -8)
            frame.icon:SetTexture(specIcon)
            frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            ReadableFont(frame.name, 22)
            frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -70)
            frame.name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -70)
            frame.name:SetHeight(44)
            frame.name:SetWordWrap(true)
            frame.name:SetText(specName)
            local column = { frame = frame, specID = specID, specName = specName,
                specIcon = specIcon, rows = {}, listWidth = step - 30, offset = 0, range = 0 }
            column.hover = frame:CreateTexture(nil, "OVERLAY")
            column.hover:SetAllPoints()
            column.hover:SetColorTexture(1, 0.82, 0.25, 1)
            column.hover:SetAlpha(0)
            column.marker = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            column.marker:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 4)
            column.marker:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
            column.marker:SetHeight(20)
            column.scroll = CreateFrame("ScrollFrame", nil, frame)
            column.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -120)
            column.scroll:SetSize(column.listWidth, listHeight)
            column.content = CreateFrame("Frame", nil, column.scroll)
            column.content:SetSize(column.listWidth, listHeight)
            column.scroll:SetScrollChild(column.content)
            column.message = column.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            column.message:SetPoint("TOPLEFT", column.content, "TOPLEFT", 4, -4)
            column.message:SetWidth(column.listWidth - 8)
            column.message:SetWordWrap(true)
            column.bar = CreateFrame("Slider", nil, frame)
            column.bar.track = column.bar:CreateTexture(nil, "BACKGROUND")
            column.bar.track:SetAllPoints()
            column.bar.track:SetColorTexture(0.03, 0.03, 0.03, 0.8)
            column.bar.thumb = column.bar:CreateTexture(nil, "ARTWORK")
            column.bar.thumb:SetSize(10, 24)
            column.bar.thumb:SetColorTexture(0.75, 0.64, 0.3, 1)
            column.bar:SetThumbTexture(column.bar.thumb)
            column.bar:SetOrientation("VERTICAL")
            column.bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -126)
            column.bar:SetSize(12, listHeight - 12)
            column.bar:SetMinMaxValues(0, 0)
            column.bar:SetValueStep(1)
            column.bar:SetObeyStepOnDrag(true)
            function column:SetOffset(value)
                local offset = math.max(0, math.min(self.range, value))
                if offset ~= self.offset then
                    for _, row in ipairs(self.rows) do HideTooltip(row) end
                end
                self.offset = offset
                self.scroll:SetVerticalScroll(self.offset)
                self.bar:SetValue(self.offset)
            end
            function column:Scroll(delta) self:SetOffset(self.offset - delta * rowHeight) end
            column.bar:SetScript("OnValueChanged", function(_, value)
                if column.offset ~= value then
                    for _, row in ipairs(column.rows) do HideTooltip(row) end
                end
                column.offset = math.max(0, math.min(column.range, value))
                column.scroll:SetVerticalScroll(column.offset)
            end)
            for _, surface in ipairs({ frame, column.scroll, column.content, column.bar }) do
                surface:EnableMouse(true)
                surface:EnableMouseWheel(true)
                surface:SetScript("OnMouseWheel", function(_, delta) column:Scroll(delta) end)
            end
            frame:SetScript("OnEnter", function()
                if not GameTooltip then return end
                GameTooltip:Hide()
                GameTooltip:SetParent(UIParent)
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                GameTooltip:SetText(specName)
                GameTooltip:SetAlpha(1)
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", HideTooltip)
            frame:SetScript("OnClick", function(_, button) self:HandleSpecColumnClick(specID, button) end)
            -- ScrollFrame/background mouse-up is routed through the same gate.
            for _, surface in ipairs({ column.scroll, column.content }) do
                surface:SetScript("OnMouseUp", function(_, button) self:HandleSpecColumnClick(specID, button) end)
            end
            -- A single rectangle test includes children and scrollbars. Child
            -- enter/leave ordering cannot remove the whole-column highlight.
            frame:SetScript("OnUpdate", function() self:RefreshColumnAppearance(column) end)
            frame:SetScript("OnHide", function()
                column.lastHovered = nil
                column.hover:SetAlpha(0)
                HideTooltip(frame)
            end)
            window.specColumns[#window.specColumns + 1] = column
        end
    end
    if self.ApplyWindowSkin then self:ApplyWindowSkin() end
    if self.LayoutLootWindow then
        self:LayoutLootWindow()
        if window.resizeGrip then
            local lw, lh, hw, hh = self:WindowSizeLimits()
            window:SetResizeBounds(lw, lh, hw, hh)
            window:SetSize(math.max(lw, math.min(hw, window:GetWidth())), math.max(lh, math.min(hh,
                window:GetHeight())))
        end
    end
end

function Spekifier:GetSpecColumn(index)
    return self:GetAllSpecColumns()[index]
end
function Spekifier:GetAllSpecColumns()
    local window = self:GetMainWindow()
    return window and window.specColumns or {}
end
