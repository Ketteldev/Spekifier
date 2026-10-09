-- Identity-only lookups; never mutate the Journal.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local raids = addonTable.RaidEncounters
local function JournalInstance(instanceID)
    if not C_EncounterJournal or not C_EncounterJournal.GetInstanceForGameMap then
        return nil, "journal-api-unavailable"
    end
    local journalID = C_EncounterJournal.GetInstanceForGameMap(instanceID)
    if not journalID then return nil, "journal-instance-unavailable" end
    return journalID
end
-- The client challenge-map catalog defines the supported dungeon set.
-- GetMapUIInfo's sixth result is the game map, not a UI map or journal ID.
-- This identifies the dungeon-wide end-of-run reward source. It does not
-- establish that ordinary Mythic EJ drops equal that pool (Phase 4).
function Spekifier:ResolveDungeonContext(visit)
    if not C_ChallengeMode or not C_ChallengeMode.GetMapTable or
        not C_ChallengeMode.GetMapUIInfo then return nil, "challenge-api-unavailable" end
    local maps = C_ChallengeMode.GetMapTable() or {}
    if #maps == 0 then return nil, "challenge-data-unavailable" end
    local match, missingData
    for _, challengeID in ipairs(maps) do
        local _, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(challengeID)
        if not mapID then missingData = true end
        if mapID == visit.instanceID then
            if match and match ~= challengeID then return nil, "ambiguous-dungeon" end
            match = challengeID
        end
    end
    if missingData then return nil, "challenge-data-unavailable" end
    if not match then return nil, "unsupported-dungeon" end
    local journalID, reason = JournalInstance(visit.instanceID)
    if not journalID then return nil, reason end
    return { kind = "dungeon", instanceID = visit.instanceID,
        journalInstanceID = journalID, challengeModeID = match,
        visitID = visit.visitID, contextKey = visit.contextKey,
        name = visit.name, difficultyID = visit.difficultyID,
        lootMode = "mythic-plus", rewardSource = {
            kind = "challenge-mode-end-of-run", challengeModeID = match,
        } }
end
-- Explicit instance/encounter arguments avoid changing the shared Journal selection.
-- Journal creature IDs are never compared to NPC IDs from UnitGUID.
local function FindJournalEncounter(journalID, instanceID, targetName)
    if not EJ_GetEncounterInfoByIndex or not EJ_GetCreatureInfo then
        return nil, "journal-discovery-api-unavailable"
    end
    if issecretvalue and issecretvalue(targetName) then return nil, "restricted-target-identity" end
    if type(targetName) ~= "string" or targetName == "" then return nil, "target-name-unavailable" end
    local match
    for index = 1, 100 do
        local name, _, encounterID = EJ_GetEncounterInfoByIndex(index, journalID)
        if not encounterID then
            if match then return match end
            return nil, "unsupported-target"
        end
        local _, _, returnedID, _, _, returnedInstance, _, gameMap = EJ_GetEncounterInfo(encounterID)
        if returnedID ~= encounterID or returnedInstance ~= journalID or gameMap ~= instanceID then
            return nil, "encounter-data-mismatch"
        end
        local matches = name == targetName
        for creatureIndex = 1, 100 do
            local creatureID, creatureName = EJ_GetCreatureInfo(creatureIndex, encounterID)
            if not creatureID then break end
            if creatureName == targetName then matches = true end
            if creatureIndex == 100 then return nil, "journal-discovery-incomplete" end
        end
        if matches then
            if match and match ~= encounterID then return nil, "ambiguous-target" end
            match = encounterID
        end
    end
    return nil, "journal-discovery-incomplete"
end

function Spekifier:ResolveRaidContext(instanceID, difficultyID)
    if InCombatLockdown() then return nil, "combat" end
    -- Discover the instance from live Journal data before consulting NPC hints.
    local journalID, reason = JournalInstance(instanceID)
    if not journalID then return nil, reason end
    local raid = raids[instanceID]
    if type(difficultyID) ~= "number" or difficultyID <= 0 then
        return nil, "difficulty-unavailable"
    end
    if not UnitExists("target") or not UnitCanAttack("player", "target") or
        UnitIsDeadOrGhost("target") then return nil, "ineligible-target" end
    local guid = UnitGUID("target")
    if issecretvalue and issecretvalue(guid) then return nil, "restricted-target-identity" end
    if type(guid) ~= "string" then return nil, "target-identity-unavailable" end
    local unitType, npcID = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-.+$")
    if unitType ~= "Creature" then return nil, "unsupported-target-type" end
    npcID = tonumber(npcID)
    if not EJ_GetEncounterInfo then return nil, "encounter-api-unavailable" end
    local encounterID
    local identitySource = "journal-name"
    local targetName = UnitName and UnitName("target")
    encounterID, reason = FindJournalEncounter(journalID, instanceID, targetName)
    -- Only supplemental verified NPC hints may bridge absent Journal names/APIs.
    -- Never override ambiguous or inconsistent Journal data.
    if not encounterID and (reason == "unsupported-target" or
        reason == "journal-discovery-api-unavailable" or reason == "target-name-unavailable") then
        encounterID = raid and raid.encounters[npcID]
        if encounterID then identitySource = "npc-mapping" end
    end
    if not encounterID then return nil, reason end
    local bossName, _, returnedID, _, _, encounterInstanceID, _, gameMapID =
        EJ_GetEncounterInfo(encounterID)
    if not bossName or returnedID ~= encounterID or encounterInstanceID ~= journalID or
        gameMapID ~= instanceID then return nil, "encounter-data-mismatch" end
    return { kind = "raid", instanceID = instanceID,
        journalInstanceID = journalID, encounterID = encounterID,
        bossName = bossName, difficultyID = difficultyID,
        targetIdentity = guid, npcID = npcID, identitySource = identitySource, lootMode = "raid" }
end
