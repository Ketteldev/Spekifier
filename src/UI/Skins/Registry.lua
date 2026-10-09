-- Registration, saved choice and startup defaults.
local _, ns = ...
local S = ns.Spekifier
local registry, order = {}, {}
function S:RegisterWindowSkin(id, label, palette)
    assert(type(id) == "string" and type(label) == "string" and type(palette) == "table")
    if not registry[id] then order[#order + 1] = id end
    registry[id] = { id = id, label = label, palette = palette }
end
function S:GetWindowSkins()
    local result = {}
    for _, id in ipairs(order) do result[#result + 1] = registry[id] end
    return result
end
function S:InitializeWindowSkin()
    local id = self:GetSetting("windowSkin")
    if id == nil then
        local function loaded(name)
            if C_AddOns and C_AddOns.IsAddOnLoaded then
                -- The first return includes addons still loading; require completion.
                return select(2, C_AddOns.IsAddOnLoaded(name))
            end
            return IsAddOnLoaded and IsAddOnLoaded(name)
        end
        id = (loaded("EllesmereUI") or loaded("ElvUI")) and "elles" or "original"
    end
    self:SetSetting("windowSkin", registry[id] and id or "original")
end
function S:GetWindowPalette()
    return (registry[self:GetSetting("windowSkin")] or registry.original).palette
end
function S:SetWindowSkin(id)
    self:SetSetting("windowSkin", registry[id] and id or "original")
    self:ApplyWindowSkin()
    self:RefreshSkinDropdown()
end
