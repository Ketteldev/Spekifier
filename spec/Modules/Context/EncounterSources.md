# Phase 3 lookup evidence and validation

Inspected on 2026-10-08. This module resolves identity only. It does not claim a validated loot pool or working specialization selection.

## Retail API evidence

Blizzard exported UI source, snapshot `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [Encounter Journal API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncounterJournalDocumentation.lua): `C_EncounterJournal.GetInstanceForGameMap(mapID)` returns the journal instance for a **game map**, not a UI map.
- [Encounter Journal UI](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua): `EJ_GetEncounterInfo(id)` returns name, description, journal encounter ID, root section, link, journal instance ID, dungeon encounter ID, game map ID. The resolver checks the three identity fields. The UI uses `EJ_GetCreatureInfo` IDs for journal creature/search/model selection; these are not verified NPC IDs and are deliberately unused for GUID matching.
- [Unit API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua): `UnitGUID` is secret when unit identity is restricted. The resolver avoids target reads during combat and rejects secret GUIDs with `issecretvalue` before inspecting them. It never logs or stores rejected GUIDs. Missing GUIDs and non-Creature/malformed identities fail closed.
- [Challenge Mode API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChallengeModeInfoDocumentation.lua): `GetMapTable` supplies challenge-map IDs; `GetMapUIInfo` returns name, challenge ID, time limit, texture, background, **game map ID**. `CHALLENGE_MODE_MAPS_UPDATE` permits retry after catalog arrival. No active-key API is needed.
- [Challenges UI](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.lua): challenge-map IDs address dungeon runs and their completion banner. Weekly chest APIs are separate and are not used as end-of-run sources here.

No inspected API supplies a verified pre-combat target NPC-to-journal-encounter mapping. Consequently the fallback below is explicit and small; journal data validates the instance and encounter at runtime. No localized name matching, journal creature-ID assumption, or classification/level heuristic remains.

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

The older encounter's NPCs, game instance, and journal encounter are verified by [BigWigs' Silken Court declaration](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/b894465a3cb0879304f4b50fd9de39922a287af6/NerubarPalace/TheSilkenCourt.lua). The runtime API must confirm journal instance 1273 and game instance 2657 before opening. Other Nerub'ar Palace encounters, other raids, encounter adds, pets, and unknown units are unsupported. Names shown in the window come from the client's localized Journal data.

## Dungeon support and reward-source contract

The supported set is the client's challenge-map catalog, rather than an assumed season roster or a list of all party instances. An eligible Mythic/Keystone visit must have exactly one catalog challenge map whose game-map ID equals `GetInstanceInfo`'s instance ID and a journal instance from `GetInstanceForGameMap`. Distinct challenge IDs for the same game map are ambiguous and fail closed. Duplicate copies of the same challenge ID are harmless.

A resolved dungeon context contains `challengeModeID`, `journalInstanceID`, `instanceID`, `visitID`, actual `difficultyID`, `lootMode = "mythic-plus"`, and `rewardSource = { kind = "challenge-mode-end-of-run", challengeModeID = ... }`. This is the verified mapping to the dungeon-wide reward **identity**, not an item enumeration API. There is no encounter/target requirement and no known key level on ordinary Mythic entry.

Phase 4 must verify the actual eligible item pool and its retrieval source. Neither ordinary Mythic boss loot nor weekly/Great Vault rewards are implicitly substituted. No journal filters or selected difficulty are changed by Phase 3.

## Dungeon entry and debug regression fix

The [Blizzard Challenges UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.lua) calls `C_MythicPlus.RequestMapInfo()` when shown; [MythicPlus API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MythicPlusInfoDocumentation.lua) declares that request. Spekifier now requests data independently at initialization and eligible dungeon entry. Five bounded one-second entry retries cover data becoming available without another lifecycle event. Empty or incomplete challenge data is reported separately from an unsupported dungeon and never consumes a prompt.

The production debug module is loaded by the test fixture. Regression checks cover immediate toggle diagnostics, failed entry messages, quiet disabled mode, deduplicated unit events, delayed instance/Journal/map data, retry limits, exit, combat, and dismissal. These reproduce a missing-data failure; the exact cause of the reported live entry still requires in-game confirmation.

## Automated and live acceptance

`lua spec/Modules/Context/AutoShow.lua` exercises the production modules, using Lua 5.1 mocks. 267 checks pass. The fixtures deliberately use normal classification and non-skull levels for known bosses and skull levels for unknown NPCs. They cover every supported current unit, the older shared encounter, fail-closed identities/data/APIs, difficulty/context/source invalidation, delayed catalog resolution, and all prior visibility/dismissal/combat/visit scenarios. Journal mutation/opening functions raise errors if called.

This verifies code behavior against the documented contracts, not the live game's NPC placement or API restrictions. In WoW, target all mapped units before combat, verify localized Journal identity and actual difficulty, exercise reload/entry/catalog timing, and confirm no Journal disruption. Live checks remain pending; the interface metadata alone is not proof of Retail compatibility.
