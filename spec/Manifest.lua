-- Load the exact release manifest into a fresh namespace using the game mocks.
local output = print
local setup = dofile("spec/UI/Window/LootBinding.lua")
local _, state, _, journal = setup({ skins = true, discovery = true, selectionModule = true })
local namespace, loaded, checks = {}, {}, 0
local function expect(value, label)
    assert(value, label)
    checks = checks + 1
end
for line in io.lines("src/Spekifier.toc") do
    local path = line:match("^%s*(.-%.lua)%s*$")
    if path then
        path = path:gsub("\\", "/")
        expect(not loaded[path], "manifest loads each file once: " .. path)
        loaded[path] = true
        assert(loadfile("src/" .. path))("Spekifier", namespace)
    end
end
local addon = namespace.Spekifier
expect(addon == _G.Spekifier, "manifest shares the exported addon instance")
addon.frame:Fire("OnEvent", "ADDON_LOADED", "Spekifier")
addon.frame:Fire("OnEvent", "PLAYER_LOGIN")
local window = addon:GetMainWindow()
expect(window:IsShown(), "manifest startup opens a supported raid context")
expect(#addon:GetAllSpecColumns() == 3, "all specialization controls are available")
expect(window.encounterData.state == "ready", "Journal results reach the window after manifest startup")
expect(journal.difficulty == 16 and journal.slot == 10 and journal.classID == 2 and journal.specID == 65,
    "query preserves observable Journal filters")
expect(window.resizeGrip and window.skinBackground, "layout and skin modules initialize")
expect(addon.optionsPanel.windowSkin and addon.minimapButton, "options and launcher initialize")
local data, token = window.encounterData, addon:GetWindowState().lootToken
addon:SetWindowSkin("elles")
expect(window.encounterData == data and addon:GetWindowState().lootToken == token,
    "skin changes preserve data and request ownership")
addon:HideWindow("dismissed")
local dismissed = addon:GetWindowState().dismissedContextKey
expect(addon:GetDebugLootData().state == "ready", "separate diagnostics module loads loot while hidden")
expect(not window:IsShown() and addon:GetWindowState().dismissedContextKey == dismissed,
    "diagnostics preserve hidden lifecycle and dismissal")
addon:ShowWindow("manual")
expect(window:IsShown() and window.encounterData.state == "ready", "manual reopening binds cached results")
expect(addon:HandleSpecColumnClick(2, "LeftButton"), "selection gate works across extracted modules")
expect(state.lootSpec == 2 and not window:IsShown(), "confirmed selection closes the window")
output("Passed " .. checks .. " manifest startup and integration checks")
