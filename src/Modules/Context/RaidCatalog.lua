local _, addonTable = ...
-- Verified NPC -> journal encounter fallbacks. Journal creature IDs are not
-- UnitGUID NPC IDs. Sources and supported scope: Tests/EncounterSources.md.
addonTable.RaidEncounters = {
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
