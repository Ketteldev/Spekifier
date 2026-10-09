local fixture = dofile("spec/Modules/Context/AutoShow.lua")
local checks = 0
local function expect(value, label) assert(value, label); checks = checks + 1 end
local categories = {
    { "autoShowMythicPlus", "party", {8, 23} },
    { "autoShowLFR", "raid", {7, 17} },
    { "autoShowNormalRaid", "raid", {3, 4, 9, 14} },
    { "autoShowHeroicRaid", "raid", {5, 6, 15} },
    { "autoShowMythicRaid", "raid", {16, 233} },
}
for _, category in ipairs(categories) do
    local key, kind, ids = unpack(category)
    for _, id in ipairs(ids) do
        local a, s, event = fixture({discovery = true, instanceType = kind, difficultyID = id})
        local w = a:GetMainWindow()
        expect(w:IsShown() and a:GetAutoShowState().preferenceKey == key, "mapped default " .. id)
        a:SetAutoShowPreference(key, false)
        expect(not w:IsShown() and not a:GetAutoShowState().autoShowPermission, "child closes immediately " .. id)
        a:SetAutoShowPreference(key, true)
        expect(w:IsShown() == (kind == "raid"), "consumed dungeon stays closed " .. id)
        a:SetAutoShowPreference("enabled", false)
        expect(not w:IsShown(), "parent closes " .. id)
        for _, other in ipairs(categories) do
            expect(not a.optionsPanel.autoShowChildren[other[1]]:IsEnabled(), "children disabled")
        end
        a:SetAutoShowPreference(key, false)
        a:SetAutoShowPreference("enabled", true)
        expect(not w:IsShown() and not a:GetSetting(key), "parent retains child false")
        for _, other in ipairs(categories) do
            expect(a.optionsPanel.autoShowChildren[other[1]]:IsEnabled(), "children enabled")
        end
        SlashCmdList.SPEKIFIER("toggle")
        expect(w:IsShown() and a:GetWindowState().openingReason == "manual", "manual ignores preferences")
        a:SetAutoShowPreference("enabled", false)
        expect(w:IsShown(), "manual remains open")
        s.combat = true; event("PLAYER_REGEN_DISABLED")
        expect(not w:IsShown(), "manual combat hides")
        SlashCmdList.SPEKIFIER("toggle")
        expect(not w:IsShown(), "manual combat blocked")
    end
end
for _, id in ipairs({0, 1, 2, 33, 220, 250, 999}) do
    local a = fixture({discovery = true, difficultyID = id})
    expect(not a:GetMainWindow():IsShown() and not a:GetAutoShowState().autoShowPermission, "unmapped raid closed " .. id)
end
for _, category in ipairs(categories) do
    local key, kind, ids = unpack(category)
    local saved = {settings = {[key] = false}}
    local a, s, event = fixture({discovery = true, instanceType = kind, difficultyID = ids[1]}, saved)
    expect(not a:GetMainWindow():IsShown(), "saved false gates")
    a:SetAutoShowPreference(key, true)
    expect(a:GetMainWindow():IsShown(), "unshown context opens immediately")
    a:ToggleWindow()
    local dismissed = a:GetWindowState().dismissedContextKey
    for _, value in ipairs({false, true}) do a:SetAutoShowPreference(key, value); a:SetAutoShowPreference("enabled", value) end
    expect(not a:GetMainWindow():IsShown() and a:GetWindowState().dismissedContextKey == dismissed, "dismissal preserved")
    if kind == "raid" then
        event("PLAYER_TARGET_CHANGED")
        expect(a:GetMainWindow():IsShown(), "new target allows prompt")
    else
        s.inInstance = false; event("ZONE_CHANGED_NEW_AREA")
        s.inInstance = true; event("ZONE_CHANGED_NEW_AREA")
        expect(a:GetMainWindow():IsShown(), "new visit allows prompt")
    end
end
-- Every parent/child combination, with unrelated children disabled.
for _, category in ipairs(categories) do
    for _, parent in ipairs({false, true}) do
        for _, child in ipairs({false, true}) do
            local settings = {enabled = parent}
            for _, other in ipairs(categories) do settings[other[1]] = false end
            settings[category[1]] = child
            local a = fixture({discovery=true, instanceType=category[2], difficultyID=category[3][1]}, {settings=settings})
            expect(a:GetMainWindow():IsShown() == (parent and child), "independent category truth table")
        end
    end
end
local saved = {settings = {enabled = false, hideMinimapButton = true, unrelated = "keep"}}
for i, category in ipairs(categories) do saved.settings[category[1]] = i % 2 == 0 end
local a = fixture({discovery = true}, saved)
a:SetAutoShowPreference("enabled", true); a:SetAutoShowPreference("enabled", false)
a = fixture({discovery = true}, SpekifierDB)
expect(not a:GetSetting("enabled") and a:GetSetting("hideMinimapButton") and a:GetSetting("unrelated") == "keep", "login retains independent preferences")
for i, category in ipairs(categories) do
    expect(a:GetSetting(category[1]) == (i % 2 == 0) and a.optionsPanel.autoShowChildren[category[1]]:GetChecked() == (i % 2 == 0), "mixed choices persist")
end
a = fixture({discovery = true}, {settings = {enabled = false}})
for _, category in ipairs(categories) do expect(a:GetSetting(category[1]) == true, "upgrade defaults on") end
for _, id in ipairs({8, 23}) do
    local a, s, event = fixture({discovery = true, instanceType = "party", difficultyID = id, combat = true}, {settings = {autoShowMythicPlus = false}})
    a:SetAutoShowPreference("autoShowMythicPlus", true)
    expect(not a:GetMainWindow():IsShown() and not a:GetAutoShowState().dungeonVisit.prompted, "combat keeps unshown visit")
    s.combat = false; event("PLAYER_REGEN_ENABLED")
    expect(a:GetMainWindow():IsShown(), "enabled deferred visit opens")
end
for _, overrides in ipairs({{instanceType="party", difficultyID=1}, {instanceType="party", difficultyID=2}, {npcID=999}, {dead=true}, {inInstance=false}}) do
    overrides.discovery = true
    local a = fixture(overrides)
    a:SetAutoShowPreference("enabled", false); a:SetAutoShowPreference("enabled", true)
    expect(not a:GetMainWindow():IsShown(), "preferences never bypass eligibility")
end
local a, s = fixture({discovery=true}, {settings={autoShowNormalRaid=false}})
SlashCmdList.SPEKIFIER("debug")
local log = table.concat(s.messages, "\n")
expect(log:find("Auto%-Show Preference: autoShowNormalRaid") and log:find("Effective Auto%-Show Permission: false"), "debug reports gate")
local control = a.optionsPanel.autoShowChildren.autoShowNormalRaid
control:SetChecked(true); control:Fire("OnClick")
expect(a:GetMainWindow():IsShown(), "checkbox routes immediate refresh")
a.optionsPanel.autoShow:SetChecked(false); a.optionsPanel.autoShow:Fire("OnClick")
expect(not a:GetMainWindow():IsShown() and not control:IsEnabled(), "parent checkbox routes dependencies")
io.write("Auto-show preferences: " .. checks .. " checks passed\n")
