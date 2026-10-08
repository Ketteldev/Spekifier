-- Shared options page and preference routing; independent of encounter eligibility.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier

function Spekifier:SetMinimapHidden(hidden)
    hidden = not not hidden
    self:SetSetting("hideMinimapButton", hidden)
    if self.minimapButton then self.minimapButton:SetShown(not hidden) end
    if self.optionsPanel then self.optionsPanel.hideMinimap:SetChecked(hidden) end
end

function Spekifier:ToggleMinimapButton()
    self:SetMinimapHidden(not self:GetSetting("hideMinimapButton"))
    self:Print(self:GetSetting("hideMinimapButton") and "Minimap button hidden." or "Minimap button shown.")
end

function Spekifier:InitializeOptions()
    if self.optionsCategory then return true end
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return false end
    local panel = self.optionsPanel
    if not panel then
        panel = CreateFrame("Frame")
        panel:Hide()
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("Spekifier")
        local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
        description:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
        description:SetJustifyH("LEFT")
        description:SetWordWrap(true)
        description:SetText("Compare loot specializations for supported raids and Mythic+ dungeons.\nMinimap: left-click for preview, right-click for options; drag to reposition.")
        local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)
        local label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        label:SetText("Hide minimap button")
        checkbox:SetScript("OnClick", function(button) self:SetMinimapHidden(button:GetChecked()) end)
        panel.hideMinimap = checkbox
        panel:SetScript("OnShow", function() checkbox:SetChecked(not not self:GetSetting("hideMinimapButton")) end)
        self.optionsPanel = panel
    end
    self.optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Spekifier")
    Settings.RegisterAddOnCategory(self.optionsCategory)
    self:SetMinimapHidden(self:GetSetting("hideMinimapButton"))
    return true
end

function Spekifier:OpenOptions()
    if not self:InitializeOptions() or not Settings or not Settings.OpenToCategory then
        self:Print("Options are unavailable. Try again after the game finishes loading.")
        return false
    end
    -- Delegate to Blizzard's supported path and its native restrictions.
    local ok = pcall(Settings.OpenToCategory, self.optionsCategory:GetID())
    if not ok then self:Print("Options could not open. Try again outside combat.") end
    return ok
end

function Spekifier:CreateOptionsGear(parent)
    local gear = CreateFrame("Button", nil, parent)
    gear:SetSize(22, 22)
    gear:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -34, -2)
    local icon = gear:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    gear:SetScript("OnClick", function() self:OpenOptions() end)
    gear:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText("Options")
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)
    gear:SetScript("OnHide", function() if GameTooltip:IsOwned(gear) then GameTooltip:Hide() end end)
    return gear
end

