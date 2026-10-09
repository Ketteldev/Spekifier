local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local PlayerLootRequest = addonTable.PlayerLootRequest
-- Diagnostics can inspect a valid current context with the preview dismissed.
-- They never show the window or reset its dismissal/consumed-visit state.
local debugLootBinding, debugLootToken, debugLootData
function Spekifier:GetDebugLootData()
    local mainWindow = self:GetMainWindow()
    local provider, state = self.LootProvider, self:GetAutoShowState()
    local context = not state.inCombat and state.resolvedContext or nil
    local binding, classID, specs = PlayerLootRequest(self, context)
    if not provider or not binding then
        if provider then provider:Cancel(debugLootToken) end
        debugLootBinding, debugLootToken, debugLootData = nil, nil, nil
        return nil, state.inCombat and "combat" or state.failureReason or "no-current-context"
    end
    if mainWindow and mainWindow:IsShown() then
        self:RefreshWindowLoot(context)
        return mainWindow.encounterData
    end
    local function Current()
        local current = self:GetAutoShowState()
        return not current.inCombat and PlayerLootRequest(self, current.resolvedContext) == binding
    end
    if binding ~= debugLootBinding or not debugLootData then
        provider:Cancel(debugLootToken)
        debugLootBinding, debugLootData = binding, nil
    end
    -- Keep completed diagnostic data, or an active diagnostic request. A
    -- canceled partial request must restart so it cannot stay loading forever.
    local active = provider.active and provider.active.token == debugLootToken
    local completed = debugLootData and (debugLootData.state == "ready" or debugLootData.state == "empty")
    if not debugLootData or (debugLootData.state == "loading" and not active) then
        debugLootToken = provider:Request(context, classID, specs, function(result)
            if Current() and debugLootBinding == binding then debugLootData = result end
        end, Current)
    elseif not completed and not Current() then
        return nil, "obsolete-context"
    end
    return debugLootData
end
