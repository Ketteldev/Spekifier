local _, addonTable = ...
-- Supplemental NPC -> Journal encounter hints; never a raid allowlist. Journal creature IDs are not
-- UnitGUID NPC IDs. Sources and supported scope: spec/Modules/Context/EncounterSources.md.
addonTable.RaidEncounters = {
    [3004] = { encounters = {
        [259927] = 2888, -- Nek'zali the Soulcoiler
        [258558] = 2874, [258557] = 2874, -- Entombed Sentinels
        [259181] = 2882, -- Vashnik the Malignant
        [261835] = 2894, [261843] = 2894, [261848] = 2894,
        [261584] = 2894, -- The Lost Explorers (Mor'zahi)
        [257347] = 2871, -- Sszorak
        [257368] = 2887, [257361] = 2887, -- The Twin Fangs
        [259854] = 2883, [257911] = 2883, -- The Coiled Altar
        [257758] = 2895, -- Ula'tek
    } },
    [2987] = { encounters = {
        [252959] = 2849, -- Nymrissa Wavecaller, The Tidebound Grotto
    } },
    [2912] = { encounters = {
        [240435] = 2733, [240434] = 2734,
        [250892] = 2735, [254109] = 2735,
        [240432] = 2736,
        [250589] = 2737, [250588] = 2737, [250587] = 2737,
        [244761] = 2738,
    } },
    [2657] = { encounters = {
        [217489] = 2608, [217491] = 2608,
    } },
}
