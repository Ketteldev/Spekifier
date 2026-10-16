-- Identity-only lookups; never mutate the Journal.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
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
-- Instance-scoped Journal enumeration never reads restricted target identity.
function Spekifier:ResolveRaidContext(instanceID, difficultyID, selectedEncounterID)
    if InCombatLockdown() then return nil, "combat" end
    if type(difficultyID) ~= "number" or difficultyID <= 0 then return nil, "difficulty-unavailable" end
    local journalID, reason = JournalInstance(instanceID)
    if not journalID then return nil, reason end
    if not EJ_GetEncounterInfoByIndex then return nil, "journal-discovery-api-unavailable" end
    local encounters, seen, selected = {}, {}, nil
    for index = 1, 100 do
        local name, _, encounterID = EJ_GetEncounterInfoByIndex(index, journalID)
        if not encounterID then
            if #encounters == 0 then return nil, "journal-discovery-incomplete" end
            selected = selected or encounters[1]
            return { kind = "raid", instanceID = instanceID, journalInstanceID = journalID,
                encounterID = selected.id, bossName = selected.name, encounters = encounters,
                difficultyID = difficultyID, identitySource = "encounter-picker", lootMode = "raid" }
        end
        if type(encounterID) ~= "number" or encounterID <= 0 or type(name) ~= "string" or
            name == "" or seen[encounterID] then return nil, "journal-discovery-incomplete" end
        local entry = { id = encounterID, name = name }
        encounters[#encounters + 1], seen[encounterID] = entry, true
        if encounterID == selectedEncounterID then selected = entry end
    end
    return nil, "journal-discovery-incomplete"
end
