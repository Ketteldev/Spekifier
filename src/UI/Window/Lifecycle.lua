-- Window lifecycle and dismissal are session-only state.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local mainWindow
local windowState = { selectionAllowed = false }
local resolutionMessages = {
    ["challenge-data-unavailable"] = "Mythic+ dungeon data is still loading. Try again shortly.",
    ["journal-instance-unavailable"] = "The Journal has no instance data available for this raid yet.",
    ["journal-discovery-api-unavailable"] = "Journal target discovery is unavailable.",
    ["journal-discovery-incomplete"] = "Journal encounter data is incomplete. Try again shortly.",
    ["ambiguous-target"] = "This target matches multiple Journal encounters.",
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
        mainWindow.status:SetText("Preview: target a living raid boss or enter a Mythic dungeon " ..
            "outside combat. Selection is unavailable. " ..
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
    mainWindow.dragArea:SetHeight(88)
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
    mainWindow.title:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 96, -28)
    mainWindow.title:SetPoint("TOPRIGHT", mainWindow, "TOPRIGHT", -60, -28)
    mainWindow.title:SetHeight(22)
    mainWindow.title:SetJustifyH("LEFT")
    mainWindow.title:SetText("Spekifier")
    if self.CreateOptionsGear then mainWindow.optionsGear = self:CreateOptionsGear(mainWindow) end
    mainWindow.logo = mainWindow:CreateTexture(nil, "ARTWORK")
    mainWindow.logo:SetSize(64, 64)
    mainWindow.logo:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 20, -26)
    mainWindow.logo:SetTexture("Interface\\AddOns\\Spekifier\\Media\\logo_64.tga")
    mainWindow.header = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainWindow.header:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 96, -52)
    mainWindow.header:SetPoint("TOPRIGHT", mainWindow, "TOPRIGHT", -60, -52)
    mainWindow.header:SetHeight(38)
    mainWindow.header:SetJustifyH("LEFT")
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
            mainWindow:SetSize(math.max(lw, math.min(hw, mainWindow:GetWidth())), math.max(lh,
                math.min(hh, mainWindow:GetHeight())))
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
