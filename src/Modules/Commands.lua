-- Modules/Commands.lua
-- Slash command registration and handling

local addonName, addonTable = ...
local Spekifier = addonTable.Spekifier

-- Prefer window results; a dismissed preview can query the current context.
local function PrintSpecLootCounts()
    local data, unavailableReason = Spekifier:GetDebugLootData()
    if not data and unavailableReason then print("  Loot Counts Unavailable: " .. unavailableReason) end
    if data then print("  Loot Comparison State: " .. tostring(data.state or "unavailable")) end
    if data and data.specs then
        for _, column in ipairs(Spekifier:GetAllSpecColumns()) do
            local result = data.specs[column.specID]
            if result and result.journalDifficultyID then
                print("  Loot Query Journal Difficulty ID: " .. result.journalDifficultyID)
                if data.context and data.context.kind == "dungeon" then
                    print("  Loot Query Scope: all dungeon bosses; Mythic+ preview")
                end
                break
            end
            local diagnostic = result and result.difficultyDiagnostics
            if diagnostic then
                if result.explanation then print("  Loot Source: " .. result.explanation) end
                print("  Requested Journal Difficulty ID: " .. tostring(diagnostic.requestedID))
                print("  Base Journal Difficulty ID: " .. tostring(diagnostic.baseID))
                local ids = {}
                for _, id in ipairs(diagnostic.availableIDs) do ids[#ids + 1] = tostring(id) end
                print("  Available Journal Difficulty IDs: " .. (#ids > 0 and table.concat(ids, ", ") or "none"))
                break
            end
        end
    end
    print("  Loot Items Per Spec:")
    for _, column in ipairs(Spekifier:GetAllSpecColumns()) do
        local result = data and data.specs and data.specs[column.specID]
        local state = result and result.state or "unavailable"
        local label = (column.specName or "Specialization") .. " (" .. column.specID .. "): "
        if state == "ready" or state == "empty" then
            local count = #(result.items or {})
            label = label .. count .. (count == 1 and " item" or " items")
        elseif result and result.items and #result.items > 0 then
            local count = #result.items
            label = label .. count .. (count == 1 and " item" or " items") .. " received; count incomplete"
        else
            label = label .. "count unavailable"
        end
        print("    " .. label .. " [" .. state ..
            (result and result.reason and ": " .. result.reason or "") .. "]")
        if result and result.completeness and (state == "loading" or state == "failed") then
            local missing = result.completeness
            print("      Missing data: rows=" .. missing.missingRows .. ", names=" .. missing.missingNames ..
                ", icons=" .. missing.missingIcons .. ", links=" .. missing.missingLinks ..
                "; Journal refresh pending=" .. tostring(missing.journalOutOfDate))
        end
    end
end

-- Slash command handler
local function HandleSlashCommand(msg)
    msg = string.lower(msg or ""):match("^%s*(.-)%s*$")

    if msg == "" or msg == "help" then
        Spekifier:Print("Commands:")
        print("  /spek - Show this help")
        print("  /spek toggle (or t) - Toggle the manual preview (outside combat)")
        print("  /spek options (or o) - Open addon options")
        print("  /spek minimap (or mm) - Show/hide the minimap button")
        print("  All commands also work with /spekifier")
        print("  /spek debug - Show auto-show debug information")
        print("  /spek debugmode (or dm) - Toggle debug mode on/off")
    elseif msg == "toggle" or msg == "t" then
        Spekifier:ToggleWindow()
    elseif msg == "options" or msg == "o" then
        Spekifier:OpenOptions()
    elseif msg == "minimap" or msg == "mm" then
        Spekifier:ToggleMinimapButton()
    elseif msg == "debugmode" or msg == "dm" then
        Spekifier:ToggleDebug()
    elseif msg == "debug" then
        Spekifier:RefreshAutoShow(nil, false)
        local state = Spekifier:GetAutoShowState()
        local windowState = Spekifier:GetWindowState()
        Spekifier:Print("Auto-Show Debug:")
        print("  In Raid Instance: " .. tostring(state.inRaidInstance))
        print("  Context Kind: " .. tostring(state.contextKind))
        local context = state.resolvedContext
        print("  Lookup Result: " .. (context and "resolved" or "unresolved"))
        print("  Lookup Failure: " .. tostring(state.failureReason))
        print("  Game Instance: " .. state.instanceName)
        print("  Journal Instance: " .. tostring(context and context.journalInstanceID))
        print("  Journal Encounter: " .. tostring(context and context.encounterID))
        print("  Boss Name: " .. tostring(context and context.bossName))
        print("  Target NPC: " .. tostring(context and context.npcID))
        print("  Target Identity: " .. tostring(context and context.targetIdentity))
        print("  Challenge Map: " .. tostring(context and context.challengeModeID))
        print("  Reward Source: " .. tostring(context and context.rewardSource and context.rewardSource.kind))
        local visit = state.dungeonVisit
        print("  Dungeon Instance: " .. tostring(visit and state.instanceName))
        print("  Dungeon Visit: " .. tostring(visit and visit.visitID))
        print("  Instance Difficulty: " .. state.difficultyName)
        print("  Instance Difficulty ID: " .. tostring(state.difficultyID))
        print("  Intended Loot Mode: " .. tostring(visit and visit.lootMode))
        print("  Visit Prompt Consumed: " .. tostring(visit and visit.prompted))
        print("  Can Prompt: " .. tostring(state.canPrompt))
        print("  Targeting Boss: " .. tostring(state.targetingBoss))
        print("  In Combat: " .. tostring(state.inCombat))
        print("  Auto-Show Preference: " .. tostring(state.preferenceKey or "unmapped"))
        print("  Difficulty Preference Enabled: " .. tostring(state.preferenceEnabled))
        print("  Effective Auto-Show Permission: " .. tostring(state.autoShowPermission))
        print("  Should Auto-Show: " .. tostring(state.shouldAutoShow))
        print("  Preview Window Shown: " .. tostring(not not (Spekifier:GetMainWindow() and Spekifier:GetMainWindow():IsShown())))
        print("  Opening Reason: " .. tostring(windowState.openingReason))
        print("  Context: " .. tostring(windowState.contextKey))
        print("  Dismissed Context: " .. tostring(windowState.dismissedContextKey))
        print("  Last Close Reason: " .. tostring(windowState.lastCloseReason))
        print("  Loot State: " .. tostring(windowState.lootState))
        print("  Loot Failure: " .. tostring(windowState.lootFailureReason))
        PrintSpecLootCounts()
        -- Refresh from the game even when the preview is dismissed.
        if Spekifier.RefreshLootSpecialization then Spekifier:RefreshLootSpecialization() end
        print("  Loot Specialization Setting: " .. tostring(windowState.lootSpecSetting))
        print("  Loot Specialization Mode: " .. (windowState.lootSpecSetting == 0 and
            "Current Specialization" or (windowState.confirmedSpecID and "Explicit" or "Unavailable")))
        print("  Confirmed Loot Specialization ID: " .. tostring(windowState.confirmedSpecID))
        local confirmedName
        for _, column in ipairs(Spekifier:GetAllSpecColumns()) do
            if column.specID == windowState.confirmedSpecID then confirmedName = column.specName end
        end
        print("  Confirmed Loot Specialization: " .. tostring(confirmedName or "unavailable"))
        print("  Selection Allowed: " .. tostring(windowState.selectionAllowed))
    else
        Spekifier:Print("Unknown command. Type /spek help for commands.")
    end
end

-- Register slash commands
SLASH_SPEKIFIER1 = "/spekifier"
SLASH_SPEKIFIER2 = "/spek"
SlashCmdList["SPEKIFIER"] = HandleSlashCommand

