# Phase 3 lookup evidence and validation

Inspected on 2026-10-08. This module resolves identity only. It does not claim a validated loot pool or working specialization selection.

## Retail API evidence

Blizzard exported UI source, snapshot `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [Encounter Journal API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncounterJournalDocumentation.lua): `C_EncounterJournal.GetInstanceForGameMap(mapID)` returns the journal instance for a **game map**, not a UI map.
- [Encounter Journal UI](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua): `EJ_GetEncounterInfo(id)` returns name, description, journal encounter ID, root section, link, journal instance ID, dungeon encounter ID, game map ID. The resolver checks the three identity fields. The UI uses `EJ_GetCreatureInfo` IDs for journal creature/search/model selection; these are not verified NPC IDs and are deliberately unused for GUID matching.
- [Unit API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua): `UnitGUID` is secret when unit identity is restricted. The resolver avoids target reads during combat and rejects secret GUIDs with `issecretvalue` before inspecting them. It never logs or stores rejected GUIDs. Missing GUIDs and non-Creature/malformed identities fail closed.
- [Challenge Mode API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChallengeModeInfoDocumentation.lua): `GetMapTable` supplies challenge-map IDs; `GetMapUIInfo` returns name, challenge ID, time limit, texture, background, **game map ID**. `CHALLENGE_MODE_MAPS_UPDATE` permits retry after catalog arrival. No active-key API is needed.
- [Challenges UI](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.lua): challenge-map IDs address dungeon runs and their completion banner. Weekly chest APIs are separate and are not used as end-of-run sources here.

No inspected API supplies a verified pre-combat target NPC-to-journal-encounter mapping. The original implementation therefore used an explicit NPC catalog. The Journal-first architecture follow-up below supersedes its raid allowlist and adds unique localized Journal name matching. Journal creature IDs remain separate from NPC IDs.

## Verified raid fallback

The Voidspire mappings come from the encounter module declarations and `SetCreatureID`/adjacent multi-boss comments in [DBM's VoidSpire modules](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/8f65199172db959a795f1dc208f394c16a287d60/DBM-Raids-Midnight/VoidSpire). `NewMod` supplies journal encounter and instance IDs, whereas `SetEncounterID` supplies a different dungeon encounter ID; these must not be interchanged.

| Game instance | Journal instance | Encounter | Journal encounter | NPC IDs |
| --- | --- | --- | --- | --- |
| 2912 | 1307 | Imperator Averzian | 2733 | 240435 |
| 2912 | 1307 | Vorasius | 2734 | 240434 |
| 2912 | 1307 | Vaelgor & Ezzorak | 2735 | 250892, 254109 |
| 2912 | 1307 | Fallen-King Salhadaar | 2736 | 240432 |
| 2912 | 1307 | Lightblinded Vanguard | 2737 | 250589, 250588, 250587 |
| 2912 | 1307 | Crown of the Cosmos | 2738 | 244761 |
| 2657 | 1273 | The Silken Court | 2608 | 217489, 217491 |
| 3004 | 1320 | Nek'zali the Soulcoiler | 2888 | 259927 |

Nek'zali's IDs were verified on 2026-10-09 from [DBM's encounter declaration](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/2d9711d0b4fb55c53703c891929d664fa657a3c3/DBM-Raids-Midnight/TheVenomousAbyss/NekzalitheSoulcoiler.lua): `SetZone(3004)`, `NewMod(2888, ..., 1320)`, and `SetCreatureID(259927)`. Its `SetEncounterID(3470)` is a dungeon encounter ID, not the Journal encounter used for loot. The full raid catalog was added in the subsequent tier follow-up below. The user reported `unsupported-raid` there on LFR difficulty 17, outside combat with automatic opening enabled. Regression coverage checks all four modern raid difficulties, dismissal/retargeting, unknown-unit rejection, and mismatched Journal identity rejection.

Live follow-up remains pending: install `dist/Spekifier-nekzali-candidate.zip`, reload outside combat, and target a living, attackable Nek'zali in LFR. Confirm the automatic window names Nek'zali at LFR difficulty and compare its loot with the Adventure Guide. Verify dismissal/retargeting and combat closing. Record the client build and results in PLAN.md Manual Acceptance.

The older encounter's NPCs, game instance, and journal encounter are verified by [BigWigs' Silken Court declaration](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/b894465a3cb0879304f4b50fd9de39922a287af6/NerubarPalace/TheSilkenCourt.lua). The runtime API must confirm journal instance 1273 and game instance 2657 before opening. Other Nerub'ar Palace encounters, other raids, encounter adds, pets, and unknown units are unsupported. Names shown in the window come from the client's localized Journal data.

## Dungeon support and reward-source contract

The supported set is the client's challenge-map catalog, rather than an assumed season roster or a list of all party instances. An eligible Mythic/Keystone visit must have exactly one catalog challenge map whose game-map ID equals `GetInstanceInfo`'s instance ID and a journal instance from `GetInstanceForGameMap`. Distinct challenge IDs for the same game map are ambiguous and fail closed. Duplicate copies of the same challenge ID are harmless.

A resolved dungeon context contains `challengeModeID`, `journalInstanceID`, `instanceID`, `visitID`, actual `difficultyID`, `lootMode = "mythic-plus"`, and `rewardSource = { kind = "challenge-mode-end-of-run", challengeModeID = ... }`. This is the verified mapping to the dungeon-wide reward **identity**, not an item enumeration API. There is no encounter/target requirement and no known key level on ordinary Mythic entry.

Phase 4 must verify the actual eligible item pool and its retrieval source. Neither ordinary Mythic boss loot nor weekly/Great Vault rewards are implicitly substituted. No journal filters or selected difficulty are changed by Phase 3.

## Dungeon entry and debug regression fix

The [Blizzard Challenges UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.lua) calls `C_MythicPlus.RequestMapInfo()` when shown; [MythicPlus API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MythicPlusInfoDocumentation.lua) declares that request. Spekifier now requests data independently at initialization and eligible dungeon entry. Five bounded one-second entry retries cover data becoming available without another lifecycle event. Empty or incomplete challenge data is reported separately from an unsupported dungeon and never consumes a prompt.

The production debug module is loaded by the test fixture. Regression checks cover immediate toggle diagnostics, failed entry messages, quiet disabled mode, deduplicated unit events, delayed instance/Journal/map data, retry limits, exit, combat, and dismissal. These reproduce a missing-data failure; the exact cause of the reported live entry still requires in-game confirmation.

## Automated and live acceptance

`lua spec/Modules/Context/AutoShow.lua` exercises the production modules, using Lua 5.1 mocks. 363 checks pass. The fixtures deliberately use normal classification and non-skull levels for known bosses and skull levels for unknown NPCs. They cover every supported current unit, the older shared encounter, fail-closed identities/data/APIs, difficulty/context/source invalidation, delayed catalog resolution, and all prior visibility/dismissal/combat/visit scenarios. Journal mutation/opening functions raise errors if called.

This verifies code behavior against the documented contracts, not the live game's NPC placement or API restrictions. In WoW, target all mapped units before combat, verify localized Journal identity and actual difficulty, exercise reload/entry/catalog timing, and confirm no Journal disruption. Live checks remain pending; the interface metadata alone is not proof of Retail compatibility.

## Complete Season 2 raid catalog follow-up (2026-10-09)

All Venomous Abyss identities are declared by [DBM at revision 2d9711d0b4fb55c53703c891929d664fa657a3c3](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/2d9711d0b4fb55c53703c891929d664fa657a3c3/DBM-Raids-Midnight/TheVenomousAbyss). Each module's NewMod, SetZone, and SetCreatureID establish Journal encounter/instance, game map, and NPC identities respectively. The Lost Explorers module additionally identifies Mor'zahi (261584) in its adjacent comment.

| Game instance | Journal instance | Encounter | Journal encounter | NPC IDs |
| --- | --- | --- | --- | --- |
| 3004 | 1320 | Nek'zali the Soulcoiler | 2888 | 259927 |
| 3004 | 1320 | Entombed Sentinels | 2874 | 258558, 258557 |
| 3004 | 1320 | Vashnik the Malignant | 2882 | 259181 |
| 3004 | 1320 | The Lost Explorers | 2894 | 261835, 261843, 261848, 261584 |
| 3004 | 1320 | Sszorak | 2871 | 257347 |
| 3004 | 1320 | The Twin Fangs | 2887 | 257368, 257361 |
| 3004 | 1320 | The Coiled Altar | 2883 | 259854, 257911 |
| 3004 | 1320 | Ula'tek | 2895 | 257758 |
| 2987 | 1317 | Nymrissa Wavecaller | 2849 | 252959 |

Nymrissa's declaration comes from [DBM's Tidebound Grotto module](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/8f65199172db959a795f1dc208f394c16a287af6/DBM-Lairs-Midnight/TideboundGrotto/NymrissaWavecaller.lua). Blizzard's [DifficultyUtil](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/DifficultyUtil_Base.lua) defines RaidWorld=250 and RaidMythicFlexible=233. World difficulty gets its own default-on World Raid preference; flexible Mythic uses Mythic Raid. [Blizzard's lair announcement](https://worldofwarcraft.blizzard.com/en-us/news/24295085) describes World/Normal/Heroic/flexible Mythic availability. No difficulty conversion or outdoor-target opening is introduced. Journal identity checks still apply to every target, and loot queries retain actual instance difficulty.

Automated validation: 363 lifecycle/resolver/debug checks, 373 preference checks (including World Raid upgrade defaults, routing, independence, saved false values and manual/combat behavior), and 48 provider/window checks. The added provider integration cases cover Vashnik LFR, Mor'zahi Heroic, and Nymrissa World/flexible Mythic with actual Journal query difficulty. All 11 suites, Lua 5.1 syntax and manifest validation pass.

Manual procedure (pending): install `dist/Spekifier-season2-candidate.zip` and reload. Outside combat, target each listed living attackable boss unit in its raid, including every multi-boss unit, and verify the localized encounter name, actual difficulty and loot against the Adventure Guide. Exercise Venomous Abyss LFR/Normal/Heroic/Mythic and Grotto World/Normal/Heroic/flexible Mythic. Verify preference gating (including World Raid), manual opening with auto-show disabled, dismissal/retargeting, combat closing, confirmed loot-spec selection and rejection of trash/outdoor targets. Record client build, tested units/difficulties and results in PLAN.md; unperformed combinations remain pending.

## Journal-first architecture follow-up (2026-10-09)

Root cause: the original raid resolver rejected game maps absent from the static catalog before calling the Journal. Adding tier entries repaired individual cases while preserving that architectural restriction. The resolver now calls `GetInstanceForGameMap` first, enumerates `EJ_GetEncounterInfoByIndex(index, journalInstanceID)`, and matches the target's exact localized name against encounter names and `EJ_GetCreatureInfo(index, encounterID)` creature names. Explicit identity arguments avoid changing the Journal selection. Blizzard's [Journal UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua) demonstrates encounter enumeration and creature name retrieval; the explicit-instance enumeration contract needs live confirmation with the current Retail client.

A match must be unique across the instance's encounters, and encounter identities must agree with the live Journal instance and game map. Duplicate creature names within one encounter are harmless. Ambiguity, mismatched identities, restricted target names and incomplete bounded enumeration fail closed and cannot be hidden by an NPC hint. Enumeration is bounded at 100 encounters/creatures to avoid unbounded refresh work. No Journal selection, filters, difficulty or UI is mutated by resolution. No discovered data is cached, so unavailable data may recover on the next context refresh.

The catalog now contains only supplemental game-map-scoped NPC-to-encounter hints, without hardcoded Journal instance IDs. Hints apply when exact-name matching has no result, the discovery API is absent, or the target name is unavailable. The final hinted encounter still requires live Journal identity validation. `/spek debug` reports `Target Lookup Source` as `journal-name` or `npc-mapping`. This does not guarantee automatic identification of every possible boss: absent/ambiguous names without a usable hint remain clearly unavailable.

Validation: all 11 suites, Lua 5.1 syntax and manifest checks pass; 372 lifecycle/resolver/debug checks include an entirely uncatalogued raid, encounter and individual-creature name matching, no Journal data, unmatched trash, ambiguous names, mismatched game maps, Journal-first ordering, Journal priority over conflicting hints, and rejection of ambiguity despite a known NPC hint. Existing tier and loot checks remain passing.

Live procedure (pending): install `dist/Spekifier-journal-first-candidate.zip`, reload outside combat, and target bosses in a raid absent from RaidCatalog.lua. Confirm `journal-name` resolution and correct encounter/difficulty/loot. Retest individual multi-boss units, tier NPC fallback, trash and outdoor rejection, combat/dismissal, and delayed Journal data. Keep the Adventure Guide on a different instance and verify resolver reads do not change its selection. Record build/units/results in PLAN.md Manual Acceptance. This architectural behavior is not yet live-accepted.
