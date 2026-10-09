-- Native launcher with no bundled dependencies.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local shapes = {
    ROUND = { true, true, true, true }, SQUARE = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
}
function Spekifier:UpdateMinimapPosition()
    local button = self.minimapButton
    if not button then return end
    local angle = math.rad(self:GetSetting("minimapAngle") or 225)
    local x, y = math.cos(angle), math.sin(angle)
    local quadrant = (x < 0 and 1 or 0) + (y > 0 and 2 or 0) + 1
    local shape = shapes[GetMinimapShape and GetMinimapShape() or "ROUND"] or shapes.ROUND
    local rx, ry = Minimap:GetWidth() / 2 + 10, Minimap:GetHeight() / 2 + 10
    if not shape[quadrant] then
        x = math.max(-1, math.min(1, x * math.sqrt(2)))
        y = math.max(-1, math.min(1, y * math.sqrt(2)))
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * rx, y * ry)
end
function Spekifier:InitializeMinimap()
    if self.minimapButton or not Minimap then return end
    local button = CreateFrame("Button", "SpekifierMinimapButton", Minimap)
    self.minimapButton = button
    button:SetSize(32, 32)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    local mark = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    mark:SetText("S")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then self:OpenOptions() else self:ToggleWindow() end
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Spekifier")
        GameTooltip:AddLine("Left-click: Toggle preview", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Options", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move around the minimap", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local function stopDragging() button:SetScript("OnUpdate", nil) end
    button:SetScript("OnDragStart", function()
        GameTooltip:Hide()
        button:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            if not cx or not cy then return end
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local angle = math.deg(math.atan2(py / scale - cy, px / scale - cx)) % 360
            self:SetSetting("minimapAngle", angle)
            self:UpdateMinimapPosition()
        end)
    end)
    button:SetScript("OnDragStop", stopDragging)
    button:SetScript("OnHide", function()
        stopDragging()
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end)
    button:RegisterEvent("UI_SCALE_CHANGED")
    button:RegisterEvent("DISPLAY_SIZE_CHANGED")
    button:SetScript("OnEvent", function() self:UpdateMinimapPosition() end)
    self:UpdateMinimapPosition()
    self:SetMinimapHidden(self:GetSetting("hideMinimapButton"))
end
