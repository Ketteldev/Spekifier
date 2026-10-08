-- Core/Debug.lua
-- Centralized debug output management

local addonName, addonTable = ...
local Spekifier = addonTable.Spekifier

-- Debug print function
function Spekifier:DebugPrint(...)
    if not self:GetSetting("debugEnabled") then return end

    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    local message = table.concat(parts, " ")
    print("|cFF00FF00Spekifier [DEBUG]|r", message)
end

-- Regular print (always shows, for important user-facing messages)
function Spekifier:Print(...)
    local message = strjoin(" ", ...)
    print("|cFF00FF00Spekifier|r", message)
end

-- Toggle debug mode
function Spekifier:ToggleDebug()
    local currentState = self:GetSetting("debugEnabled") or false
    self:SetSetting("debugEnabled", not currentState)

    local newState = self:GetSetting("debugEnabled")
    local status = newState and "enabled" or "disabled"
    self:Print("Debug mode " .. status)
    if newState and self.RefreshAutoShow then
        self.lastAutoShowDebug = nil
        self:RefreshAutoShow("DEBUG_MODE_ENABLED", false)
    end

    return newState
end

-- Check if debug is enabled
function Spekifier:IsDebugEnabled()
    return self:GetSetting("debugEnabled") or false
end
-- Log failed lookups and opening decisions without inspecting restricted units.
function Spekifier:DebugAutoShow(event)
    if not self:IsDebugEnabled() then return end
    local state, windowState = self:GetAutoShowState(), self:GetWindowState()
    local window = self:GetMainWindow()
    local reason
    if state.inCombat then reason = "combat"
    elseif not self:GetSetting("enabled") then reason = "automatic-opening-disabled"
    elseif not state.resolvedContext then reason = state.failureReason or "unresolved"
    elseif window and window:IsShown() then reason = "window-shown"
    elseif windowState.dismissedContextKey == state.contextKey then reason = "dismissed"
    elseif state.dungeonVisit and state.dungeonVisit.prompted then reason = "visit-already-prompted"
    else reason = "ready-to-open" end
    local summary = table.concat({ "instance=" .. state.instanceName,
        "difficulty=" .. state.difficultyName,
        "context=" .. tostring(state.contextKind), "decision=" .. reason,
        "lookup=" .. tostring(state.failureReason or "resolved") }, " ")
    -- Unit events are frequent; log changed decisions and explicit zone/key events.
    if summary ~= self.lastAutoShowDebug or event == "PLAYER_ENTERING_WORLD" or
        event == "ZONE_CHANGED_NEW_AREA" or event == "CHALLENGE_MODE_START" then
        self:DebugPrint(event or "REFRESH", summary)
        self.lastAutoShowDebug = summary
    end
end
