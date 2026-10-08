-- Automatic opening requires a verified encounter or dungeon context.
local addonName, addonTable = ...
local Spekifier = addonTable.Spekifier
local autoShowState = { inRaidInstance = false, targetingBoss = false, inCombat = false }
local targetGeneration, visitGeneration = 1, 0
local dungeonVisit
local entryRetryGeneration = 0

local function RequestDungeonData()
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        C_MythicPlus.RequestMapInfo()
    end
end

-- Instance/Journal data can lag behind entry. Each retry reads current state
-- and respects combat, dismissal and the once-per-visit prompt.
function Spekifier:RetryDungeonEntry()
    entryRetryGeneration = entryRetryGeneration + 1
    local generation, attempts = entryRetryGeneration, 0
    if not C_Timer or not C_Timer.After then return end
    local function retry()
        if generation ~= entryRetryGeneration then return end
        attempts = attempts + 1
        self:RefreshAutoShow("DUNGEON_ENTRY_RETRY")
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "party" and
            not autoShowState.resolvedContext and attempts < 5 then
            C_Timer.After(1, retry)
        end
    end
    C_Timer.After(1, retry)
end

function Spekifier:RefreshAutoShow(event, allowOpening)
    local inCombat = event == "PLAYER_REGEN_DISABLED" or not not InCombatLockdown()
    local inInstance, instanceType = IsInInstance()
    local inRaidInstance = not not (inInstance and instanceType == "raid")
    local name, _, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
    -- Actual instance difficulty: 23 = Mythic, 8 = Mythic Keystone.
    -- A key is not required; the resolver gates supported reward identities.
    local eligibleDungeon = inInstance and instanceType == "party" and
        (difficultyID == 23 or difficultyID == 8) and instanceID and instanceID > 0
    if not eligibleDungeon then
        dungeonVisit = nil
    elseif not dungeonVisit or dungeonVisit.instanceID ~= instanceID then
        visitGeneration = visitGeneration + 1
        dungeonVisit = { kind = "dungeon", instanceID = instanceID,
            visitID = visitGeneration, contextKey = "dungeon:" .. visitGeneration,
            lootMode = "mythic-plus", prompted = false }
        RequestDungeonData()
    end
    if dungeonVisit then
        dungeonVisit.name = name
        dungeonVisit.difficultyID = difficultyID
    end
    local context, failureReason
    if dungeonVisit then
        context, failureReason = self:ResolveDungeonContext(dungeonVisit)
    elseif inRaidInstance and not inCombat then
        context, failureReason = self:ResolveRaidContext(instanceID, difficultyID)
    else
        failureReason = inCombat and "combat" or "ineligible-instance"
    end
    local targetingBoss = context and context.kind == "raid" or false
    local windowState = self:GetWindowState()
    if event == "PLAYER_TARGET_CHANGED" or
        inRaidInstance ~= autoShowState.inRaidInstance then
        targetGeneration = targetGeneration + 1
        if not dungeonVisit then windowState.dismissedContextKey = nil end
    end
    if event == "PLAYER_REGEN_ENABLED" or (autoShowState.inCombat and not inCombat) then
        if not dungeonVisit then windowState.dismissedContextKey = nil end
    end
    autoShowState.inRaidInstance = inRaidInstance
    autoShowState.targetingBoss = targetingBoss
    autoShowState.inCombat = inCombat
    autoShowState.dungeonVisit = dungeonVisit
    autoShowState.resolvedContext = context
    autoShowState.failureReason = failureReason
    autoShowState.instanceID = instanceID
    autoShowState.instanceName = name and name ~= "" and name or "Unknown instance"
    autoShowState.difficultyName = difficultyName and difficultyName ~= "" and difficultyName or
        (difficultyID == 0 and "None" or "Unknown difficulty")
    autoShowState.difficultyID = difficultyID
    autoShowState.contextKind = context and context.kind or nil
    -- Raid display identity includes difficulty and actual unit identity, even
    -- when a refresh arrives without PLAYER_TARGET_CHANGED.
    autoShowState.contextKey = context and (context.kind == "dungeon" and
        context.contextKey or table.concat({ "raid", targetGeneration, instanceID,
            context.journalInstanceID, context.encounterID, difficultyID,
            context.targetIdentity }, ":")) or nil
    if context then context.contextKey = autoShowState.contextKey end
    autoShowState.shouldAutoShow = not not (self:GetSetting("enabled") and
        autoShowState.contextKey and not inCombat)
    -- Validity and permission to prompt are separate: shown visits stay valid.
    autoShowState.canPrompt = autoShowState.shouldAutoShow and
        (not dungeonVisit or not dungeonVisit.prompted)

    local window = self:GetMainWindow()
    if inCombat then
        self:HideWindow("combat")
        self:DebugAutoShow(event)
        return
    end
    if window and window:IsShown() and windowState.contextKind == "dungeon" and
        not (inInstance and instanceType == "party") then
        self:HideWindow("invalid-context")
    end
    if window and window:IsShown() then
        self:UpdateWindowContext(autoShowState.contextKey)
        if context and context.kind == "dungeon" then self:MarkDungeonPromptShown() end
        if windowState.openingReason == "automatic" and not autoShowState.shouldAutoShow then
            self:HideWindow("invalid-context")
        end
    end
    if allowOpening ~= false and autoShowState.canPrompt and
        windowState.dismissedContextKey ~= autoShowState.contextKey and
        (not window or not window:IsShown()) then
        if self:ShowWindow("automatic") then
            self:DebugPrint("Auto-showing window", autoShowState.contextKind)
        end
    end
    self:DebugAutoShow(event)
end

function Spekifier:InitializeAutoShow()
    if not self.autoShowFrame then
        local frame = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
            "PLAYER_DIFFICULTY_CHANGED", "CHALLENGE_MODE_MAPS_UPDATE", "CHALLENGE_MODE_START", "CHALLENGE_MODE_RESET",
            "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
            "UNIT_HEALTH", "UNIT_FLAGS", "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED" }) do
            frame:RegisterEvent(event)
        end
        frame:SetScript("OnEvent", function(_, event, unit)
            if event:sub(1, 5) == "UNIT_" and unit ~= "target" then return end
            Spekifier:RefreshAutoShow(event)
            if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
                Spekifier:RetryDungeonEntry()
            end
        end)
        self.autoShowFrame = frame
        RequestDungeonData()
        self:RetryDungeonEntry()
    end
    self:RefreshAutoShow()
end

function Spekifier:GetAutoShowState() return autoShowState end

-- Manual display also consumes the visit prompt, including with auto-show disabled.
function Spekifier:MarkDungeonPromptShown()
    if dungeonVisit and autoShowState.resolvedContext then
        dungeonVisit.prompted = true
        autoShowState.canPrompt = false
    end
end
