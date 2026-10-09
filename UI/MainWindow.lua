-- Window lifecycle and dismissal are session-only state.
local addonName, addonTable = ...
local Spekifier = addonTable.Spekifier
local mainWindow
local windowState = { selectionAllowed = false }
local resolutionMessages = {
    ["challenge-data-unavailable"] = "Mythic+ dungeon data is still loading. Try again shortly.",
    ["unsupported-raid"] = "This raid is not supported.",
    ["unsupported-target"] = "This target is not a supported raid boss.",
    ["unsupported-dungeon"] = "This dungeon has no supported Mythic+ reward source.",
    ["ambiguous-dungeon"] = "This dungeon's Mythic+ reward source is ambiguous.",
    ["restricted-target-identity"] = "The target's identity is unavailable.",
    ["ineligible-target"] = "Target a living, attackable supported boss.",
    ["ineligible-instance"] = "Enter a supported raid or Mythic dungeon.",
}

function Spekifier:GetWindowState() return windowState end
function Spekifier:GetMainWindow() return mainWindow end

-- All encounter-specific display data must be owned by this context.
-- Context changes discard obsolete rows and results.
function Spekifier:UpdateWindowContext(contextKey)
    local state = self:GetAutoShowState()
    local context = contextKey and state.resolvedContext or nil
    local difficultyID = context and context.difficultyID or nil
    local sourceKey = context and table.concat({ context.kind,
        context.journalInstanceID, context.encounterID or context.challengeModeID }, ":") or nil
    if windowState.contextKey ~= contextKey or windowState.difficultyID ~= difficultyID or
        windowState.sourceKey ~= sourceKey then
        windowState.contextKey = contextKey
        windowState.selectionNotice = nil
        if self.ClearLootSelectionNotice then self:ClearLootSelectionNotice() end
        if mainWindow then mainWindow.encounterData = nil end
    end
    windowState.sourceKey = sourceKey
    windowState.difficultyID = difficultyID
    windowState.contextKind = contextKey and state.contextKind or nil
    windowState.resolvedContext = context
    windowState.dungeonContext = context and context.kind == "dungeon" and context or nil
    -- Selection requires resolved encounters and a confirmed setter (Phases 3/6).
    windowState.selectionAllowed = false
    if self.RefreshLootSpecialization then self:RefreshLootSpecialization() end
    if not mainWindow then return end
    if context and context.kind == "dungeon" then
        mainWindow.header:SetText((context.name or "Dungeon") .. ": Mythic+")
    elseif context then
        local difficulty = GetDifficultyInfo and GetDifficultyInfo(context.difficultyID)
        mainWindow.header:SetText(context.bossName .. "\n" .. (difficulty or ("Difficulty " .. context.difficultyID)))
    else
        mainWindow.header:SetText("Loot comparison preview")
        mainWindow.status:SetText("Preview: target a living raid boss or enter a Mythic dungeon outside combat. Selection is unavailable. " ..
            (resolutionMessages[state.failureReason] or "Encounter information is unavailable. Try again shortly."))
    end
    self:RefreshWindowLoot(context)
    self:RenderWindowLoot(mainWindow.encounterData)
end

function Spekifier:CreateMainWindow()
    if mainWindow then return end
    mainWindow = CreateFrame("Frame", "SpekifierMainWindow", UIParent, "BasicFrameTemplateWithInset")
    mainWindow:SetSize(1080, 720)
    mainWindow:SetPoint("CENTER")
    mainWindow:SetMovable(true)
    mainWindow:EnableMouse(true)
    mainWindow:SetClampedToScreen(true)
    mainWindow.dragArea = CreateFrame("Frame", nil, mainWindow)
    mainWindow.dragArea:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 8, -2)
    mainWindow.dragArea:SetPoint("TOPRIGHT", mainWindow, "TOPRIGHT", -60, -2)
    mainWindow.dragArea:SetHeight(22)
    mainWindow.dragArea:EnableMouse(true)
    mainWindow.dragArea:RegisterForDrag("LeftButton")
    mainWindow.dragArea:SetScript("OnDragStart", function() mainWindow:StartMoving() end)
    mainWindow.dragArea:SetScript("OnDragStop", function() mainWindow:StopMovingOrSizing() end)
    mainWindow:SetFrameStrata("FULLSCREEN_DIALOG")
    mainWindow:SetFrameLevel(100)
    -- Hide before installing lifecycle scripts: construction is not dismissal.
    mainWindow:Hide()
    mainWindow:HookScript("OnShow", function()
        windowState.openingReason = windowState.openingReason or "manual"
    end)
    mainWindow:HookScript("OnHide", function()
        local reason = windowState.pendingCloseReason or "dismissed"
        windowState.pendingCloseReason = nil
        windowState.lastCloseReason = reason
        if reason == "dismissed" then
            windowState.dismissedContextKey = windowState.contextKey
        end
        windowState.openingReason = nil
        mainWindow:StopMovingOrSizing()
        Spekifier:UpdateWindowContext(nil)
    end)
    local registered = false
    for _, name in ipairs(UISpecialFrames) do
        if name == "SpekifierMainWindow" then registered = true end
    end
    if not registered then table.insert(UISpecialFrames, "SpekifierMainWindow") end
    mainWindow.title = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainWindow.title:SetPoint("TOP", mainWindow.TitleBg, "TOP", 0, -3)
    mainWindow.title:SetText("Spekifier")
    if self.CreateOptionsGear then mainWindow.optionsGear = self:CreateOptionsGear(mainWindow) end
    mainWindow.header = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainWindow.header:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 20, -32)
    mainWindow.header:SetPoint("TOPRIGHT", mainWindow, "TOPRIGHT", -20, -32)
    mainWindow.header:SetHeight(54)
    mainWindow.header:SetWordWrap(true)
    mainWindow.status = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainWindow.status:SetPoint("BOTTOMLEFT", mainWindow, "BOTTOMLEFT", 20, 14)
    mainWindow.status:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -36, 14)
    mainWindow.status:SetHeight(38)
    mainWindow.status:SetWordWrap(true)
    self.mainWindow = mainWindow
    self:CreateSpecializationColumns()
    mainWindow:RegisterEvent("UI_SCALE_CHANGED")
    mainWindow:RegisterEvent("DISPLAY_SIZE_CHANGED")
    mainWindow:SetScript("OnEvent", function()
        if self.WindowSizeLimits then
            local lw, lh, hw, hh = self:WindowSizeLimits()
            mainWindow:SetResizeBounds(lw, lh, hw, hh)
            mainWindow:SetSize(math.max(lw, math.min(hw, mainWindow:GetWidth())), math.max(lh, math.min(hh, mainWindow:GetHeight())))
        end
        self:FitLootWindow()
    end)
    if self.InitializeWindowSize then self:InitializeWindowSize() end
    if self.ApplyWindowSkin then self:ApplyWindowSkin() end
    self:FitLootWindow()
    self:UpdateWindowContext(nil)
end

function Spekifier:ShowWindow(reason)
    reason = reason or "manual"
    -- Refresh without automatic opening so toggle cannot open and immediately close.
    self:RefreshAutoShow(nil, false)
    local state = self:GetAutoShowState()
    if state.inCombat then
        if reason == "manual" then self:Print("The preview is unavailable during combat.") end
        return false
    end
    if reason == "automatic" and (not state.canPrompt or
        windowState.dismissedContextKey == state.contextKey) then return false end
    self:CreateMainWindow()
    windowState.openingReason = reason
    self:UpdateWindowContext(state.contextKey)
    mainWindow:Show()
    self:MarkDungeonPromptShown()
    return true
end

function Spekifier:HideWindow(reason)
    reason = reason or "dismissed"
    if mainWindow and mainWindow:IsShown() then
        windowState.pendingCloseReason = reason
        mainWindow:Hide()
    else
        windowState.lastCloseReason = reason
        windowState.openingReason = nil
        self:UpdateWindowContext(nil)
    end
end

function Spekifier:ToggleWindow()
    if mainWindow and mainWindow:IsShown() then
        self:HideWindow("dismissed")
    else
        self:ShowWindow("manual")
    end
end

-- Bind provider delivery to the currently displayed context.
local function PlayerLootRequest(self, context)
    local classID
    if UnitClass then classID = select(3, UnitClass("player")) end
    local specs = {}
    for _, column in ipairs(self:GetAllSpecColumns()) do specs[#specs + 1] = column.specID end
    local binding = context and table.concat({ context.contextKey, context.kind, context.lootMode,
        context.rewardSource and context.rewardSource.kind or "raid",
        context.rewardSource and context.rewardSource.challengeModeID or 0,
        context.difficultyID, context.journalInstanceID,
        context.encounterID or context.challengeModeID, classID or 0,
        C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID() or 0,
        table.concat(specs, ",") }, ":") or nil
    return binding, classID, specs
end

function Spekifier:RefreshWindowLoot(context)
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

-- Diagnostics can inspect a valid current context with the preview dismissed.
-- They never show the window or reset its dismissal/consumed-visit state.
local debugLootBinding, debugLootToken, debugLootData
function Spekifier:GetDebugLootData()
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
