local output = print
local fixture = dofile('spec/Modules/Context/AutoShow.lua')
local checks = 0
local function expect(value, label) assert(value, label); checks = checks + 1 end
local addon, state, event, frames = fixture({ selectionModule = true, discovery = true })
local function debugHas(text)
    for _, message in ipairs(state.messages) do
        if message:find(text, 1, true) then return true end
    end
    return false
end
local function debug()
    state.messages = {}
    SlashCmdList.SPEKIFIER('debug')
end
addon:HideWindow('dismissed')
local key = addon:GetWindowState().dismissedContextKey
local count = #frames
state.lootSpec = 2 -- Getter changed before its event arrived.
debug()
expect(debugHas('Loot Specialization Setting: 2'), 'debug reads fresh getter')
expect(debugHas('Loot Specialization Mode: Explicit'), 'explicit mode')
expect(debugHas('Confirmed Loot Specialization ID: 2'), 'confirmed ID')
expect(debugHas('Confirmed Loot Specialization: Spec 2'), 'confirmed name')
expect(not addon:GetMainWindow():IsShown(), 'debug leaves dismissed window closed')
expect(addon:GetWindowState().dismissedContextKey == key, 'debug preserves dismissal')
expect(#frames == count, 'debug does not create frames')
state.lootSpec, state.activeSpec = 0, 3
debug()
expect(debugHas('Loot Specialization Setting: 0'), 'current spec retains raw zero')
expect(debugHas('Loot Specialization Mode: Current Specialization'), 'current mode')
expect(debugHas('Confirmed Loot Specialization ID: 3'), 'effective active ID')
expect(debugHas('Confirmed Loot Specialization: Spec 3'), 'effective active name')
state.activeSpec = 1
debug()
expect(debugHas('Confirmed Loot Specialization ID: 1'), 'debug follows active spec changes')
state.lootSpec = 999
debug()
expect(debugHas('Loot Specialization Mode: Unavailable'), 'foreign ID unavailable')
expect(debugHas('Confirmed Loot Specialization ID: nil'), 'foreign ID not confirmed')
expect(debugHas('Confirmed Loot Specialization: unavailable'), 'no stale name')
GetLootSpecialization = function() error('restricted') end
debug()
expect(debugHas('Loot Specialization Setting: nil'), 'getter failure safe')
expect(debugHas('Selection Allowed: false'), 'getter failure disables selection')
state.combat = true; event('PLAYER_REGEN_DISABLED')
debug()
expect(not addon:GetMainWindow():IsShown(), 'combat debug stays closed')
expect(debugHas('Selection Allowed: false'), 'combat selection unavailable')
output('Passed ' .. checks .. ' integration debug checks')
