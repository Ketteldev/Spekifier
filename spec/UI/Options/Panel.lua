-- Run from repository root with Lua 5.1. Reuses the production lifecycle fixture.
local fixture = dofile("spec/Modules/Context/AutoShow.lua")
local checks = 0
local function expect(value, label) assert(value, label); checks = checks + 1 end
local function near(a, b) return math.abs(a - b) < 0.001 end
local addon, state, event, frames = fixture({ discovery = true, inInstance = false, instanceType = "none" })
local button, panel, window = addon.minimapButton, addon.optionsPanel, addon:GetMainWindow()
expect(button:IsShown() and addon:GetSetting("hideMinimapButton") == false, "fresh launcher shown")
expect(addon:GetSetting("minimapAngle") == 225, "default position")
expect(#state.categories == 1 and state.categories[1].name == "Spekifier", "one registered addon category")
expect(window.optionsGear ~= nil, "gear exists in unsupported preview")
expect(window.dragArea.point[4] == -60 and window.optionsGear.point[4] == -34, "gear separated from drag region")
local count = #frames
local bindings, registrations = button.bindings, button.registrations
addon:OnPlayerLogin(); addon:InitializeOptions(); addon:InitializeMinimap()
expect(#frames == count and #state.categories == 1, "repeat initialization does not duplicate frames/categories")
expect(button.bindings == bindings and button.registrations == registrations, "repeat initialization does not duplicate handlers")
expect(SLASH_SPEKIFIER1 == "/spekifier" and SLASH_SPEKIFIER2 == "/spek", "both slash roots use shared handler")
SlashCmdList.SPEKIFIER("options"); SlashCmdList.SPEKIFIER(" o ")
window.optionsGear:Fire("OnClick")
button:Fire("OnClick", "RightButton")
expect(#state.openedCategories == 4, "all options entry points route")
for _, id in ipairs(state.openedCategories) do expect(id == addon.optionsCategory:GetID(), "identical category ID") end
expect(not window:IsShown(), "options never opens preview")
window.optionsGear:Fire("OnEnter")
expect(GameTooltip.text == "Options" and GameTooltip.shown, "gear tooltip")
window.optionsGear:Fire("OnLeave")
expect(not GameTooltip.shown, "gear tooltip cleanup")
button:Fire("OnEnter")
expect(GameTooltip.text == "Spekifier" and #GameTooltip.lines == 3, "launcher tooltip documents actions and drag")
button:Fire("OnLeave")
expect(not GameTooltip.shown, "launcher tooltip cleanup")
button:Fire("OnClick", "LeftButton")
expect(window:IsShown() and addon:GetWindowState().openingReason == "manual", "launcher uses manual preview outside eligibility")
expect(not addon:GetWindowState().selectionAllowed, "unsupported manual preview retains disabled selection")
button:Fire("OnClick", "LeftButton")
expect(not window:IsShown() and addon:GetWindowState().lastCloseReason == "dismissed", "launcher toggle closes through dismissal")
addon:SetSetting("enabled", false)
SlashCmdList.SPEKIFIER("o")
expect(#state.openedCategories == 5, "options independent of auto-show preference")
button:Fire("OnClick", "LeftButton")
expect(window:IsShown(), "manual launcher works with auto-show disabled")
state.combat = true; event("PLAYER_REGEN_DISABLED")
expect(not window:IsShown(), "combat closes launcher preview")
button:Fire("OnClick", "LeftButton")
expect(not window:IsShown(), "combat prevents launcher preview")
button:Fire("OnClick", "RightButton")
expect(#state.openedCategories == 6, "options delegates to Settings even in combat")
state.settingsError = true
expect(addon:OpenOptions() == false and addon.message:find("outside combat"), "native settings error provides feedback")
state.settingsError, state.combat = false, false; event("PLAYER_REGEN_ENABLED")
panel:Show()
expect(panel.hideMinimap:GetChecked() == false, "checkbox reflects visible default")
panel.hideMinimap:SetChecked(true); panel.hideMinimap:Fire("OnClick")
expect(not button:IsShown() and addon:GetSetting("hideMinimapButton") and panel.hideMinimap:GetChecked(), "checkbox immediately hides and persists")
SlashCmdList.SPEKIFIER("minimap")
expect(button:IsShown() and not addon:GetSetting("hideMinimapButton") and not panel.hideMinimap:GetChecked(), "minimap command restores and synchronizes")
expect(addon.message == "Minimap button shown.", "shown feedback")
SlashCmdList.SPEKIFIER("mm")
expect(not button:IsShown() and panel.hideMinimap:GetChecked(), "mm command hides and synchronizes")
expect(addon.message == "Minimap button hidden.", "hidden feedback")
SlashCmdList.SPEKIFIER("options"); window.optionsGear:Fire("OnClick")
expect(#state.openedCategories == 8, "hidden launcher retains options command and gear")
panel.hideMinimap:SetChecked(false); panel.hideMinimap:Fire("OnClick")
expect(button:IsShown() and not addon:GetSetting("hideMinimapButton"), "checkbox restores launcher")
button:Fire("OnDragStart"); button:Fire("OnUpdate")
expect(near(addon:GetSetting("minimapAngle"), 0) and near(button.point[4], 80), "drag saves angle and positions on minimap edge")
state.minimapScale, state.cursorX, state.cursorY = 2, 200, 400
button:Fire("OnUpdate")
expect(near(addon:GetSetting("minimapAngle"), 90) and near(button.point[5], 80), "cursor conversion respects minimap effective scale")
button:Fire("OnDragStop")
expect(not button.scripts.OnUpdate, "drag stop removes update handler")
button:Fire("OnDragStart"); addon:SetMinimapHidden(true)
expect(not button.scripts.OnUpdate, "hide during drag cancels handler")
local saved = SpekifierDB
addon, state = fixture({ discovery = true, inInstance = false, instanceType = "none" }, saved)
expect(not addon.minimapButton:IsShown() and addon.optionsPanel.hideMinimap:GetChecked(), "hidden preference survives new login")
expect(near(addon:GetSetting("minimapAngle"), 90) and near(addon.minimapButton.point[5], 80), "drag position survives new login")
SlashCmdList.SPEKIFIER("mm")
expect(addon.minimapButton:IsShown(), "hidden saved launcher restored by alias")
addon, state = fixture({ discovery = true }, { settings = { enabled = false, debugEnabled = false, hideMinimapButton = false, minimapAngle = 405, unrelated = "keep" } })
expect(not addon:GetSetting("enabled") and not addon:GetSetting("debugEnabled") and addon:GetSetting("unrelated") == "keep", "migration retains preferences")
expect(addon.minimapButton:IsShown() and addon:GetSetting("hideMinimapButton") == false, "saved false preserved")
expect(addon:GetSetting("minimapAngle") == 45, "saved angle normalized")
state.minimapShape = "SQUARE"; addon:UpdateMinimapPosition()
expect(near(addon.minimapButton.point[4], 80) and near(addon.minimapButton.point[5], 80), "square map follows corner edge")
state.minimapShape = "unknown"; addon:UpdateMinimapPosition()
expect(near(addon.minimapButton.point[4], math.cos(math.rad(45)) * 80), "unknown shape falls back to round")
for _, value in ipairs({ "bad", math.huge, -math.huge, 0/0 }) do
    addon = fixture({ discovery = true }, { settings = { minimapAngle = value } })
    expect(addon:GetSetting("minimapAngle") == 225, "invalid saved position repaired")
end
addon, state, event = fixture({ discovery = true, instanceType = "party", difficultyID = 23 })
button = addon.minimapButton
expect(addon:GetMainWindow():IsShown(), "existing dungeon automatic prompt preserved")
button:Fire("OnClick", "LeftButton"); event("PLAYER_TARGET_CHANGED")
expect(not addon:GetMainWindow():IsShown(), "launcher dismissal preserves consumed visit")
button:Fire("OnClick", "LeftButton")
expect(addon:GetMainWindow():IsShown() and addon:GetWindowState().openingReason == "manual", "manual reopening of consumed dungeon visit")
local category = addon.optionsCategory
Settings = nil
expect(addon:OpenOptions() == false, "unavailable Settings produces feedback")
expect(addon.optionsCategory == category, "failed opening retains registered category")
-- Missing API at startup can be retried without creating duplicate panels.
addon, state = fixture({ discovery = true })
local settings = Settings
addon.optionsCategory = nil; Settings = nil
expect(not addon:InitializeOptions(), "registration safely handles unavailable APIs")
Settings = settings
expect(addon:InitializeOptions() and addon.optionsPanel == state.categories[1].panel, "registration retry reuses panel")
-- Help includes both routes and root aliases.
SlashCmdList.SPEKIFIER("help")
local help = table.concat(state.messages, "\n")
expect(help:find("options %(or o%)") and help:find("minimap %(or mm%)") and help:find("/spekifier"), "help documents aliases")
io.write("Passed " .. checks .. " options and launcher checks\n")
-- A raid dismissal and game-confirmed selection survive options access.
addon, state, event = fixture({ discovery = true, selectionModule = true })
button = addon.minimapButton
button:Fire("OnClick", "LeftButton")
local dismissed = addon:GetWindowState().dismissedContextKey
local confirmed = addon:GetWindowState().confirmedSpecID
SlashCmdList.SPEKIFIER("o"); addon:SetMinimapHidden(true); addon:SetMinimapHidden(false)
event("UNIT_FLAGS", "target")
expect(not addon:GetMainWindow():IsShown() and addon:GetWindowState().dismissedContextKey == dismissed,
    "options and visibility changes preserve raid dismissal")
expect(addon:GetWindowState().confirmedSpecID == confirmed and state.lootSpec == nil,
    "options and visibility never write loot specialization")
addon = fixture({ discovery = true }, { settings = { enabled = false, unrelated = 123 } })
expect(addon.minimapButton:IsShown() and not addon:GetSetting("enabled") and addon:GetSetting("unrelated") == 123,
    "upgrade adds shown default without overwriting existing preferences")
local manifest = assert(io.open("src/Spekifier.toc")):read("*a")
local optionsIndex = assert(manifest:find("UI\\Options\\Panel.lua", 1, true))
local minimapIndex = assert(manifest:find("UI\\Minimap.lua", 1, true))
local windowIndex = assert(manifest:find("UI\\Window\\Lifecycle.lua", 1, true))
expect(optionsIndex < minimapIndex and minimapIndex < windowIndex, "manifest loads shared routing before launcher and window")
io.write("Options and launcher final: " .. checks .. " focused checks passed\n")
