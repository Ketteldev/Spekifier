-- Visible subscription and stale-delivery rejection.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local PlayerLootRequest = addonTable.PlayerLootRequest
function Spekifier:RefreshWindowLoot(context)
    local mainWindow, windowState = self:GetMainWindow(), self:GetWindowState()
    local provider = self.LootProvider
    if not provider or not mainWindow then return end
    local binding, classID, specs = PlayerLootRequest(self, context)
    if binding == windowState.lootBinding then
        if not context or mainWindow.encounterData then return end
        -- Repair a lost display reference from the active request without
        -- querying again. If it was canceled, request fresh/cached data below.
        if provider.active and provider.active.token == windowState.lootToken then
            provider:Publish(provider.active)
            if mainWindow.encounterData then return end
        end
    end
    provider:Cancel(windowState.lootToken)
    windowState.lootBinding, windowState.lootToken, windowState.lootState = binding, nil, nil
    windowState.lootFailureReason = nil
    mainWindow.encounterData = nil
    self:RenderWindowLoot(nil)
    if not context then return end
    local function Current()
        return windowState.lootBinding == binding and windowState.contextKey == context.contextKey
    end
    windowState.lootToken = provider:Request(context, classID, specs, function(result)
        if not Current() then return end
        mainWindow.encounterData = result
        windowState.lootState, windowState.lootFailureReason = result.state, result.reason
        self:RenderWindowLoot(result)
    end, Current)
end
