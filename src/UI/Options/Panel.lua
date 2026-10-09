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

local autoShowOptions = {
    { "autoShowMythicPlus", "Mythic+" }, { "autoShowLFR", "LFR" },
    { "autoShowNormalRaid", "Normal Raid" }, { "autoShowHeroicRaid", "Heroic Raid" },
    { "autoShowMythicRaid", "Mythic Raid" },
}

function Spekifier:RefreshAutoShowOptions()
    local panel = self.optionsPanel
    if not panel then return end
    local enabled = not not self:GetSetting("enabled")
    panel.autoShow:SetChecked(enabled)
    for _, option in ipairs(autoShowOptions) do
        local control = panel.autoShowChildren[option[1]]
        control:SetChecked(not not self:GetSetting(option[1]))
        control:SetEnabled(enabled)
        control.label:SetAlpha(enabled and 1 or 0.5)
    end
end

function Spekifier:SetAutoShowPreference(key, value)
    local valid = key == "enabled"
    for _, option in ipairs(autoShowOptions) do
        if option[1] == key then valid = true end
    end
    if not valid then return end
    self:SetSetting(key, not not value)
    self:RefreshAutoShowOptions()
    self:RefreshAutoShow("AUTO_SHOW_PREFERENCE_CHANGED")
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
        local function createOption(key, text, anchor, indent)
            local control = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            control:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent, -4)
            control.label = control:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            control.label:SetPoint("LEFT", control, "RIGHT", 4, 0)
            control.label:SetText(text)
            control:SetScript("OnClick", function(button) self:SetAutoShowPreference(key, button:GetChecked()) end)
            return control
        end
        panel.autoShow = createOption("enabled", "Auto-show", checkbox, 0)
        panel.autoShowChildren = {}
        local previous = panel.autoShow
        for index, option in ipairs(autoShowOptions) do
            previous = createOption(option[1], option[2], previous, index == 1 and 24 or 0)
            panel.autoShowChildren[option[1]] = previous
        end
        local explanation = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        explanation:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -12)
        explanation:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
        explanation:SetJustifyH("LEFT")
        explanation:SetWordWrap(true)
        explanation:SetText("Mythic+ controls the end-of-run loot preview on ordinary Mythic and active Mythic+ dungeon entry, including before a key starts.")
        panel.autoShowExplanation = explanation
        if self.CreateSkinDropdown then self:CreateSkinDropdown(panel, explanation) end
        panel:SetScript("OnShow", function()
            checkbox:SetChecked(not not self:GetSetting("hideMinimapButton"))
            self:RefreshAutoShowOptions()
            if self.RefreshSkinDropdown then self:RefreshSkinDropdown() end
        end)
        self.optionsPanel = panel
    end
    self.optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Spekifier")
    Settings.RegisterAddOnCategory(self.optionsCategory)
    self:RefreshAutoShowOptions()
    if self.RefreshSkinDropdown then self:RefreshSkinDropdown() end
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
