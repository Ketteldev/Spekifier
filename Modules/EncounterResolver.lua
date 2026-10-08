-- Identity-only lookups; never mutate or open the shared Encounter Journal.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
-- Verified NPC -> journal encounter fallbacks. Journal creature IDs are not
-- UnitGUID NPC IDs. Sources and supported scope: Tests/EncounterSources.md.
local raids = {
    [2912] = { journalInstanceID = 1307, encounters = {
        [240435] = 2733, [240434] = 2734,
        [250892] = 2735, [254109] = 2735,
        [240432] = 2736,
        [250589] = 2737, [250588] = 2737, [250587] = 2737,
        [244761] = 2738,
    } },
    [2657] = { journalInstanceID = 1273, encounters = {
        [217489] = 2608, [217491] = 2608,
    } },
}
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
function Spekifier:ResolveRaidContext(instanceID, difficultyID)
    if InCombatLockdown() then return nil, "combat" end
    local raid = raids[instanceID]
    if not raid then return nil, "unsupported-raid" end
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
    local encounterID = raid.encounters[npcID]
    if not encounterID then return nil, "unsupported-target" end
    local journalID, reason = JournalInstance(instanceID)
    if not journalID then return nil, reason end
    if journalID ~= raid.journalInstanceID then return nil, "journal-instance-mismatch" end
    if not EJ_GetEncounterInfo then return nil, "encounter-api-unavailable" end
    local bossName, _, returnedID, _, _, encounterInstanceID, _, gameMapID =
        EJ_GetEncounterInfo(encounterID)
    if not bossName or returnedID ~= encounterID or encounterInstanceID ~= journalID or
        gameMapID ~= instanceID then return nil, "encounter-data-mismatch" end
    return { kind = "raid", instanceID = instanceID,
        journalInstanceID = journalID, encounterID = encounterID,
        bossName = bossName, difficultyID = difficultyID,
        targetIdentity = guid, npcID = npcID, lootMode = "raid" }
end
