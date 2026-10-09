-- Options control consuming the public skin registry.
local _, ns = ...
local S = ns.Spekifier
function S:RefreshSkinDropdown()
    local d = self.optionsPanel and self.optionsPanel.windowSkin
    if d and UIDropDownMenu_SetText then
        for _, skin in ipairs(self:GetWindowSkins()) do
            if skin.id == self:GetSetting("windowSkin") then
                UIDropDownMenu_SetText(d, skin.label)
                return
            end
        end
        UIDropDownMenu_SetText(d, "Original")
    end
end
function S:CreateSkinDropdown(panel, anchor)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -24, -24); label:SetText("Theme")
    local d = CreateFrame("Frame", "SpekifierSkinDropdown", panel, "UIDropDownMenuTemplate")
    d:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, -8)
    panel.windowSkin = d
    UIDropDownMenu_SetWidth(d, 180)
    UIDropDownMenu_Initialize(d, function(_, level)
        for _, skin in ipairs(self:GetWindowSkins()) do
            local id = skin.id
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = skin.label, id
            info.checked = self:GetSetting("windowSkin") == id
            info.func = function() self:SetWindowSkin(id) end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end
