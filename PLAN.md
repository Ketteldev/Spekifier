# Spekifier implementation plan

## Goal and scope

Before a raid boss fight, targeting a supported living boss inside a raid instance opens a window with one column per player specialization. Each column shows its spec icon and eligible boss loot for the current raid difficulty. Hovering highlights the whole column; clicking sets the player's loot specialization and visibly confirms the result.

Entering a supported dungeon on Mythic difficulty also opens the window with the dungeon-wide Mythic+ end-of-run chest loot table. This preview does not require a boss target or an active key and must clearly identify the loot as Mythic+, even on ordinary Mythic entry. Automatic opening otherwise excludes non-Mythic dungeons, outdoor areas, ordinary enemies, dead targets, and combat. Dungeon targets do not trigger opening. Being in a raid group alone is insufficient.

## Working approach

- Complete phases in order. Each numbered work item is a small, reviewable chunk.
- Keep the existing Core, Modules, and UI organization; add focused modules as needed.
- Verify API availability, restrictions, and events against the supported Retail client before implementing integrations. The current interface declaration, `120000`, is not proof of current compatibility.
- Use focused mocked tests for state transitions, encounter resolution, and delayed data. Verify game APIs and frame interaction inside WoW.
- Checked items record completed implementation or automated validation. Live visual/input checks remain unchecked until performed in WoW. Unimplemented future work also remains unchecked.

Live verification update (2026-10-08): The user confirmed completion of all 17 previously unchecked live-validation items in Phases 1 through 6.5. Those items are now checked based on that confirmation. Earlier validation paragraphs and supporting test documents describe the implementation-time status; their pending-live statements are superseded by this update for these items. Applying the Phase 9 skins to shared-item controls remains unchecked until Phase 9.

## Phase 1: Correct automatic opening

Addresses finding 1: ordinary hostile targets currently pass the boss check.

### 1.1 Repair target eligibility

- [x] Replace the incorrect `not value == expected` comparisons with explicit inequality comparisons.
- [x] Reject missing, non-attackable, and dead targets.
- [x] Retain the raid-instance requirement and honor the existing `enabled` setting.
- [x] Treat classification/level detection as an interim heuristic until Phase 3 supplies encounter identity.

### 1.2 Evaluate a consistent state snapshot

- [x] Read instance, target, and combat state before making a single visibility decision. Current initialization evaluates between partial updates and can act on stale values.
- [x] Route world entry, zone changes, target changes, and combat transitions through this refresh path.
- [x] Make initialization safe to repeat without duplicate frames or handlers.

Primary files: `Modules/AutoShow.lua`, `Core/Events.lua`.

Acceptance checks:

- [x] Ordinary raid trash, dungeon bosses, and outdoor world bosses do not trigger opening.
- [x] A qualifying raid boss opens the window outside combat.
- [x] Login/reload during combat does not briefly open the window using an uninitialized combat value.
- [x] The disabled setting prevents automatic opening.

Live acceptance (user):

- [x] In WoW, verify raid boss prompting, trash/dungeon/outdoor exclusions, disabled automation, and login/reload during combat.

Validation: Phase 1 originally passed 25 mocked Lua checks. The suite is expanded by Phase 2 below. Live WoW validation remains pending. Classification/skull-level detection is an interim heuristic; encounter identity remains Phase 3 work. Phase 2 removes the previous saved visibility restoration.

## Phase 2: Define window lifecycle and dismissal

Addresses findings 4 and 5: visibility escapes the intended context, and closing can leave saved state inconsistent.

### 2.1 Separate visibility from saved preferences

- [x] Track opening reason (`automatic` or `manual`) and dismissal in runtime state.
- [x] Stop persisting automatic visibility and remove unconditional `windowShown` restoration at login.
- [x] Migrate existing settings safely and merge missing defaults without overwriting user preferences.
- [x] Centralize show/hide operations and synchronize state through frame scripts, including the template close button and Escape.

### 2.2 Implement predictable transitions

- [x] Hide automatically opened windows when the target becomes invalid, the player leaves the raid, or combat begins.
- [x] Suppress reopening after dismissal while the same boss remains continuously targeted. Clearing/changing the target or ending combat permits another prompt.
- [x] Keep `/spek toggle` as a manual preview/debug path. Outside valid raid context, display an explanatory empty state and disable selection.
- [x] Hide manual previews on entering combat as well; clean up consistently for every close reason.
- [x] Clear the previous boss's displayed data immediately when the encounter context changes.

Primary files: `UI/MainWindow.lua`, `Modules/AutoShow.lua`, `Core/Events.lua`, `Core/Database.lua`, `Modules/Commands.lua`.

Acceptance checks:

- [x] Close button, Escape, and slash-command closing produce consistent state.
- [x] Reloading outside a raid does not restore a previous automatic popup.
- [x] Dismissal does not cause an immediate reopening loop; clearing and retargeting allows reopening.
- [x] After a wipe, ending combat permits a fresh prompt for a valid living boss.

Live acceptance (user):

- [x] In WoW, verify close button, Escape, dismissal/retargeting, post-wipe prompting, manual preview, and combat/zone closing.

Validation: `Tests/AutoShow.lua` passes 78 checks and exercises the production database, event, window, column, command, and auto-show modules with Lua 5.1 frame mocks. Live WoW validation of the template close button, Escape, combat frame interaction, and event timing remains pending; checked acceptance items reflect mocked coverage.

Implementation details:

- `windowShown` is removed during migration. Missing defaults are merged using nil checks, preserving false values and unrelated preferences.
- Runtime state records opening reason, displayed context, dismissed context, and close reason. Frame hooks synchronize direct template/Escape hides; programmatic hides supply an explicit reason.
- Continuous target context uses a local generation advanced by `PLAYER_TARGET_CHANGED` and raid-context changes, avoiding restricted unit GUID reads. Combat end resets dismissal. Phase 3 will add resolved encounter/difficulty identity.
- Target health, flags, faction, and classification events refresh eligibility without requiring a target switch. Non-target unit updates are ignored.
- Manual preview remains available with automatic opening disabled, stays open with explanatory empty state outside valid context, and cannot open during combat.
- Selection remains unavailable until encounter resolution and the confirmed selection pipeline exist in Phases 3 and 6. Context changes immediately discard the window's encounter-data reference; future loot rendering must consume this boundary.
- API integration was checked against Blizzard's exported [unit event documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) and [Escape window management source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua). The current `120000` declaration still does not establish full Retail compatibility.

## Phase 2.5: Add Mythic dungeon-entry prompting

Extends the raid-only eligibility and target-driven lifecycle completed in Phases 1 and 2. Their checked tasks and validation remain a record of the original raid behavior.

### 2.5.1 Recognize dungeon entry

- [x] Verify supported Retail difficulty APIs and world/zone/keystone events. Recognize ordinary Mythic entry and entry into an active Mythic+ instance without requiring a key to start.
- [x] Add a dungeon-entry context independent of target state, honoring `enabled` and combat restrictions. Exclude Normal/Heroic entry.
- [x] Prompt once per dungeon visit. Coalesce duplicate entry events and keystone-start transitions so they do not create another prompt.
- [x] Treat login/reload inside an eligible dungeon as a fresh entry evaluation without restoring saved visibility. Defer entry during combat until combat ends only if the same eligible visit remains current.

### 2.5.2 Extend lifecycle and dismissal

- [x] Keep the dungeon window valid without a target. Target changes, target death, and clearing targets neither hide it nor reopen a dismissed prompt.
- [x] Hide on combat or dungeon exit; invalidate displayed data when dungeon identity or eligibility changes. Once shown, do not automatically prompt again after combat during the same visit.
- [x] Preserve dismissal for the visit, including keystone start. Leaving and re-entering permits a fresh prompt.
- [x] Allow manual preview in supported dungeon contexts, including with automatic opening disabled. Preserve explanatory empty states outside supported contexts.
- [x] Preserve existing raid targeting, dismissal, and post-wipe behavior. Gate loot rendering and selection on resolved contexts from later phases.

Primary files: `Modules/AutoShow.lua`, `Core/Events.lua`, `UI/MainWindow.lua`, `Tests/AutoShow.lua`.

Acceptance checks:

- [x] Mythic entry prompts without a target or active key; Normal/Heroic entry and dungeon boss targeting do not.
- [x] Duplicate events, target changes, combat cycles after the prompt, and keystone start do not repeatedly open the window.
- [x] Dismissal, exit/re-entry, combat-deferred entry, login/reload, active-key entry, disabled automatic opening, and manual preview follow the rules above.
- [x] Existing raid lifecycle checks still pass.
- [x] Verify actual entry and keystone event timing in WoW.

Validation: `Tests/AutoShow.lua` passes 199 checks using Lua 5.1 through Lupa, exercising the production lifecycle, UI, commands, events, and settings modules. This includes all original raid checks and dungeon entry, duplicate events, target independence, dismissal, combat deferral/cancellation, login/reload, active-key difficulty, disabled automation, manual preview, identity/difficulty invalidation, and exit/re-entry. Live WoW validation remains pending; checked acceptance items reflect mocked coverage.

Implementation details:

- `GetInstanceInfo()` supplies actual instance difficulty and instance ID; the preferred difficulty from `GetDungeonDifficultyID()` is deliberately unused. Party instances at difficulty 23 (Mythic) or 8 (Mythic Keystone) are provisionally eligible. No active key, target, target GUID, or target health read is required. Supported dungeon/reward mappings remain Phase 3 work.
- A runtime dungeon visit carries explicit `kind`, instance ID, visit generation, localized name, actual difficulty, and intended `mythic-plus` loot mode. It survives duplicate world/zone events, target events, combat, and Mythic-to-Mythic+ transitions. Observing exit, a different dungeon, or ineligibility ends the eligible visit interval. Re-entry creates a fresh generation. A fresh Lua session evaluates entry again; repeat initialization does not reset the visit.
- Context validity is separate from permission to prompt. The first automatic or manual display consumes the visit prompt, including when an already-visible preview transitions into the dungeon. Combat hides every window but only an unshown visit can prompt afterward. Manual reopening remains available outside combat.
- Dismissal is preserved across dungeon target/combat/keystone events. Dungeon exit closes automatic and manual dungeon windows. A manual preview that becomes ineligible while still inside a party instance displays the explanatory empty state. Existing raid dismissal and post-wipe reset behavior remain intact.
- Context-key or actual dungeon-difficulty changes discard displayed encounter data. Dungeon status explicitly labels the intended Mythic+ end-of-run preview, including on ordinary Mythic entry. Loot rendering and selection remain gated until later phases resolve supported contexts and implement the provider/setter.
- `/spek debug` includes context kind, dungeon instance/visit, actual difficulty, intended loot mode, consumed prompt state, and current prompt permission.
- Retail integration was verified against Blizzard's exported [instance API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua), [difficulty constants](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/DifficultyUtil_Base.lua), [world-entry events](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemDocumentation.lua), [difficulty-change event](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua), and [keystone events](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChallengeModeInfoDocumentation.lua). Registration retains the existing world/zone refresh path and adds `PLAYER_DIFFICULTY_CHANGED`, `CHALLENGE_MODE_START`, and `CHALLENGE_MODE_RESET`.

## Phase 3: Resolve raid encounters and Mythic+ dungeon contexts

Addresses findings 1 and 3: reliable boss identification and missing encounter context.

### 3.1 Establish the supported lookup

- [x] Add `Modules/EncounterResolver.lua` and register it before its consumers in the manifest.
- [x] Resolve the current game instance to its Encounter Journal instance and capture raid difficulty.
- [x] Investigate supported APIs/data for mapping a pre-combat target to an encounter. Do not assume journal creature identifiers equal NPC IDs from unit GUIDs.
- [x] Prefer verified NPC-to-encounter mappings; add a small documented fallback dataset only where API data is insufficient.
- [x] Support encounters with multiple boss units and avoid relying solely on localized names.
- [x] Define the initial supported raids. Unknown or ambiguous targets must fail closed instead of displaying another boss's loot.

### 3.2 Integrate encounter identity

- [x] Return journal instance ID, encounter ID, boss name, difficulty, and target identity as one context.
- [x] Use explicit raid and dungeon context kinds. Dungeon contexts carry dungeon identity, visit identity, and intended Mythic+ loot mode without requiring an encounter or target; distinguish loot mode from current instance difficulty.
- [x] Define supported Mythic+ dungeons and verified mappings to their dungeon-wide reward sources. Unsupported dungeons fail closed.
- [x] Make successful context resolution the final automatic-opening gate: encounter resolution replaces the raid heuristic, and dungeon resolution gates the entry prompt.
- [x] Detect encounter and difficulty changes even when the window is already visible.
- [x] Include lookup results and failure reasons in `/spek debug`.

Primary files: new `Modules/EncounterResolver.lua`, `Modules/AutoShow.lua`, `Modules/Commands.lua`, `Spekifier.toc`.

Acceptance checks:

- [x] Supported current raid bosses resolve before combat.
- [x] Members of a supported multi-boss fight resolve to the appropriate shared encounter.
- [x] At least one older supported raid works without depending on skull-level classification.
- [x] Trash and unsupported targets never produce misleading loot.
- [x] A difficulty change invalidates the previous context.

Live acceptance (user):

- [x] In WoW, verify supported current/older raid targets, multi-boss identities, unsupported-target rejection, and difficulty/context changes.

Validation: `Tests/AutoShow.lua` passes 237 checks with Lua 5.1 through Lupa, including all earlier lifecycle scenarios updated to use resolved identities. Phase 3 coverage includes all six Voidspire encounters, both Silken Court units without skull-level classification, unknown/trash/malformed/restricted identities, missing APIs and journal data, mismatched instance/encounter IDs, raid difficulty and encounter changes, unsupported/ambiguous dungeons, delayed challenge-map catalog, reward-source changes, and no shared Journal mutations. Checked acceptance items reflect mocked coverage. Live pre-combat targeting and Retail API/event timing remain pending.

Implementation details:

- Initial raid scope is The Voidspire (all six encounters) and Nerub'ar Palace's The Silken Court only. Multi-unit mappings cover Vaelgor/Ezzorak, all three Vanguard members, and both Court members. Unknown units, other raids/encounters, and restricted GUIDs fail closed. Mapping/API evidence is documented in `Tests/EncounterSources.md`.
- `C_EncounterJournal.GetInstanceForGameMap` maps the actual game instance to the journal. Verified NPC fallbacks supply journal encounter IDs, then `EJ_GetEncounterInfo` verifies encounter, journal instance, and game map and supplies the localized boss name. Journal creature IDs and localized names are never used as NPC identity. Resolution never changes Journal selection, filters, difficulty, or visibility.
- Dungeon support is defined by the client's `C_ChallengeMode.GetMapTable()` catalog and a unique `GetMapUIInfo()` game-map match with a journal instance. Contexts identify the challenge-mode end-of-run reward source, visit, actual difficulty, and intended Mythic+ loot mode separately. This identifies the reward source; full item-pool retrieval and verification remain Phase 4, without assuming ordinary Mythic or Great Vault loot is equivalent. No target or active key is required.
- Missing catalog data does not consume a visit prompt; `CHALLENGE_MODE_MAPS_UPDATE` reevaluates it. Existing visit dismissal, keystone coalescing, and combat deferral remain intact. Visible contexts discard data on difficulty, encounter, unit, visit, journal instance, or reward-source changes.
- `/spek debug` reports resolved identity and explicit failure reasons; unsupported manual previews show the reason with disabled selection. Selection remains gated until Phase 6.

## Phase 4: Retrieve loot per specialization

Addresses finding 3: the missing boss-to-loot pipeline.

### 4.1 Build the loot provider

- [x] Add `Modules/LootProvider.lua` with a request/result interface independent of UI frames.
- [x] Select the resolved journal instance, encounter, and actual raid difficulty using verified client APIs.
- [x] For dungeon contexts, use the combined Mythic boss tables at Journal difficulty 23 as the dungeon-wide Mythic+ comparison pool, per the agreed source mapping. Deduplicate items and exclude Journal per-player bonus drops and Great Vault sources.
- [x] Support the entry loot table without a known key level; do not imply an exact reward item level when the level is unknown.
- [x] Query each player class/spec combination and return item IDs, links, names, icons, and available display metadata.
- [x] Preserve and restore shared journal selection/filter state where APIs permit; prevent existing search or slot filters from silently hiding loot.
- [x] Ensure data queries do not unexpectedly open or disrupt the Adventure Guide.

### 4.2 Handle delayed and stale results

- [x] Represent loading, ready, empty, unsupported, and failed states separately.
- [x] Handle journal loot and item-data completion events; use bounded retries only where necessary.
- [x] Associate results with encounter, difficulty, class, and spec. Discard callbacks from obsolete requests.
- [x] Include context kind, dungeon identity, and Mythic+ loot mode in dungeon request/cache keys. Bind result delivery to the current visit so prior-visit callbacks cannot update the window.
- [x] Cache completed results in memory using those context fields and invalidate appropriately.
- [x] Avoid overlapping mutations of shared journal filters and repeated full queries for an unchanged target.

Primary files: new `Modules/LootProvider.lua`, provider-owned event handling, `Spekifier.toc`.

Acceptance checks:

- [x] Each spec's items match the Adventure Guide under equivalent encounter, difficulty, and filters. (Live comparison pending.)
- [x] Empty eligible loot is distinguishable from loading or failure.
- [x] Rapid boss/difficulty changes never render obsolete results.
- [x] Missing names/icons populate after data arrives without a reload.
- [x] Existing Adventure Guide filters neither affect results nor remain unexpectedly changed afterward.

Live acceptance (user):

- [x] Compare dungeon item identities with live Mythic+ rewards, including before a key starts; confirm the agreed comparison pool is accurate.
- [x] In WoW, verify queries preserve Adventure Guide filters/selection, do not open or disrupt the Guide, and recover delayed names/icons without a reload.

Validation: 386 Lua 5.1 mocked checks pass through Lupa: 79 provider checks, 40 production provider/window integration checks, and all 267 existing lifecycle/resolver/debug checks. Checked acceptance items reflect mocked coverage; live Adventure Guide equivalence, full current Mythic+ chest-pool accuracy, UI/event behavior, and client restrictions remain pending. Evidence, request/result contract, restoration limits, and the live acceptance procedure are documented in `Tests/LootSources.md`.

Implementation details:

- `Modules/LootProvider.lua` exposes a UI-independent comparison request, cancellation token, context guard, and per-spec results. Provider-owned event handling and coalesced bounded retries distinguish loading, ready, empty, unsupported, and failed.
- Raids use actual difficulty and the resolved encounter. Dungeons use the full Journal instance at Mythic difficulty 23, with no encounter, to collect the combined boss pool for the Mythic+ preview. This source mapping follows the user's explicit clarification after Murder Row (Journal 1304) reported support for 1, 2, and 23 rather than 8. Items are deduplicated by ID; per-player bonus drops are excluded. Actual entry difficulty and Mythic+ reward mode remain distinct from query difficulty, and the reward item level remains unknown without a key level. Live Guide/item-identity comparison remains pending.
- Queries preserve class/spec, slot, difficulty, and observable hidden Journal instance/encounter selection, leaving search untouched. Queries defer while the Adventure Guide is visible and never open/load it. Retail exposes no selected-instance getter or verified unset operation; an unobservable initial internal selection cannot be restored. All observable selection/filter restoration and error paths are covered by mocks.
- Completed results use a bounded memory cache keyed by context/reward source, actual difficulty, season, class, and spec. Visit/target delivery ownership is separate from reusable pools; obsolete callbacks are discarded. Item metadata can recover even after timeout without reload. Late Journal completion permits one further bounded retry round.
- `UI/MainWindow.lua` requests data only when its binding changes, clears/cancels it on lifecycle invalidation, and stores current results in `encounterData`. Missing display references are repaired from active requests. `/spek debug` reports loot state/failure and can query counts for a dismissed preview in the current valid context without reopening it; polling coalesces requests and delayed results retain current-visit/combat guards. Item-list rendering remains Phase 5 and selection remains Phase 6.

## Phase 5: Complete the loot comparison window

Addresses finding 2: columns currently contain only icons and labels.

### 5.1 Render encounter and item lists

- [x] Display boss name and raid difficulty in the header.
- [x] For dungeon contexts, display the compact one-line header "<Dungeon name>: Mythic+", including on ordinary Mythic entry; it still represents end-of-run loot.
- [x] Add scrollable loot lists beneath spec icons/names, with item icons, readable names, and item-link tooltips.
- [x] Render loading, empty, unsupported, and failure states clearly.
- [x] Reuse item rows on refresh and remove stale content when context changes.

### 5.1.1 Live feedback fixes

- [x] Increase the initial window to at least 1080 by 720 UI units, with wider columns and taller lists; fit smaller screens automatically.
- [x] Put the window on FULLSCREEN_DIALOG strata, below native item/comparison tooltips; retain native tooltip layering.
- [x] Preserve outside-combat opening and automatic hiding when combat begins.
- [x] Clear and hide column status messages when loot is ready instead of falling back to loading text.
- [x] Test compact dungeon headers, enlarged dimensions/layering, tooltip layering, and ready-message cleanup.
- [x] Enlarge spec icons/names to 56 pixels/22-point text and loot icons/names to 40 pixels/18-point text; increase row height and header spacing.
- [x] Use Blizzard's Journal-style `ProcessInfo` hyperlink tooltip path with `compareItem = true`, reset tooltip parent/alpha, and preserve hover across equivalent result refreshes.
- [x] After reload, verify larger icons/text and both the primary item tooltip and equipped-item comparisons remain visible above the window with the installed comparison addon.
- [x] After reload, visually confirm the larger window, primary item tooltip alongside equipped-item comparisons, compact Murder Row header, and disappearance of loading messages.

### 5.2 Add column interaction states

- [x] Highlight the entire column while hovering its header, background, or item rows.
- [x] Make hover, selected, and disabled states visually distinct.
- [x] Route eligible left-clicks throughout the column, including child rows, to one selection handler.
- [x] Restrict dragging to the title area so it does not compete with selection.
- [x] Keep spec headers visible while scrolling and accommodate varying spec counts, UI scales, and long localized names.

Primary files: `UI/MainWindow.lua`, `UI/SpecColumns.lua`; optionally new `UI/LootRows.lua`.

Automated acceptance:

- [x] Verify layout bounds for two, three, and four specs at multiple UI dimensions.
- [x] Verify long-list wheel/slider scrolling, fixed headers, row reuse, and scroll preservation/clamping.
- [x] Verify child enter/leave events do not clear the whole-column hover highlight.
- [x] Verify item-link tooltip cleanup, shared left-click routing, disabled/combat guards, and title-only drag wiring.

Live visual/input acceptance (user):

- [x] Different class spec counts fit without overlap or clipped lists in WoW, including long localized names and multiple UI scales.
- [x] Long loot lists remain usable through wheel and scrollbar scrolling in WoW; the last row is reachable and spec headers stay visible.
- [x] Moving across headers, background, child rows, and scrollbars does not flicker or lose the column highlight in WoW.
- [x] Tooltips, scrolling, title dragging, and the completed Phase 6 column-selection interaction do not interfere in WoW.
- [x] Visually verify raid/difficulty and dungeon/Mythic+ headers, item icons/names, and loading, empty, unsupported, failure, hover, and disabled states.

Validation: 507 unique checks pass under Lua 5.1 through Lupa: 267 lifecycle/resolver checks, 79 provider checks, 44 provider/window integration checks, and 117 presentation checks. The checked automated acceptance items reflect mocked coverage of two/three/four specs, UI dimensions, long lists, fixed headers, row reuse, scroll clamping/preservation, child hover continuity, item-link tooltips, disabled/selected states, shared left-click routing, and title-only dragging. Live WoW visual and input validation remains pending; follow `Tests/WindowSources.md`. The real confirmed specialization setter remains Phase 6; production selection stays disabled.

Implementation details:

- Each specialization has a fixed header and an independent mouse-wheel/slider list. Context changes clear rows/tooltips and reset scroll; same-context delivery reuses rows and preserves/clamps scroll. Loading and failed partial pools are not presented as complete tables.
- Window width follows spec count; screen fitting responds to UI-scale/display-size events. Wrapped spec/item names and full-name/item-link tooltips accommodate localized text. A single column rectangle hover check avoids child enter/leave flicker.
- `HandleSpecColumnClick` gates every selection surface and forwards eligible spec IDs to the future confirmed setter. Hover, confirmed selection, and unavailable selection have distinct visuals; scrollbar gestures are reserved for scrolling. Drag handlers exist only on the title area.

## Phase 5.5: Separate items shared by every specialization

Show loot eligible for all three specs once, as icons below the `[Dungeon Name]: [Difficulty]` title, so the columns emphasize differences between specs. For classes with two or four specs, apply the same rule across every displayed specialization.

### 5.5.1 Identify shared items

- [x] Compute the intersection of item IDs across all displayed specs for the current context and difficulty. An item qualifies only when it appears in every spec's complete loot pool.
- [x] Derive shared and per-column display lists without modifying the provider's original loot pools or cache. Deduplicate shared items and use a stable display order.
- [x] Remove universally shared items from every column. Items shared by only two of three specs remain in both eligible columns.
- [x] Wait until every spec's loot pool is complete before classifying shared items. Clear stale shared content on context changes and recompute on current-context data refreshes.

### 5.5.2 Render the shared icon row

- [x] Place a `Shared:` label directly below the dungeon/difficulty title, followed by a horizontal list of item icons only; do not show item names in this row.
- [x] Apply the same shared-items presentation beneath the encounter/difficulty header for raid previews.
- [x] Preserve item-link hover tooltips and equipped-item comparisons for shared icons. Shared icons must not select a specialization or highlight a spec column.
- [x] Hide the shared row and reclaim its space when no items are shared. Keep a large shared pool accessible with horizontal scrolling if needed, without overlapping the title or spec columns.
- [x] Position spec columns beneath the shared row, retain their fixed headers and independent scrolling, and show a clear empty state when a spec has no remaining non-shared items.
- [x] Reuse shared icon frames and clear obsolete icons/tooltips on refresh or invalidation. Expose the shared label, icons, and overflow controls through the window for Phase 9 skin application.
- [ ] Apply both Phase 9 skins to the shared label, icons, and overflow controls when that phase implements the skin registry.

Primary files: `UI/MainWindow.lua`, `UI/SpecColumns.lua`, shared item-icon rendering as needed, focused presentation and provider/window integration tests.

Acceptance checks:

- [x] With three specs, an item eligible for all three appears exactly once in the shared row and in none of the columns.
- [x] An item eligible for exactly two specs remains in those two columns; an item eligible for one remains only in its column.
- [x] Shared items appear as icons only, horizontally after `Shared:`, directly beneath the title, with working item/comparison tooltips.
- [x] No-shared, all-shared, duplicate-item, and two/four-spec cases render correctly without mutating source loot pools.
- [x] Loading, failed/partial results, delayed updates, and context/difficulty changes cannot produce a false or stale shared row.
- [x] In WoW, verify spacing, horizontal overflow, tooltip layering, column scrolling, and empty-column messaging at multiple UI scales.

Validation: `Tests/SharedLoot.lua` passes 166 focused Lua 5.1 checks, including real provider delivery/cache preservation, alongside the 507 existing checks (673 unique checks total). The new suite checks two/three/four-spec layouts at three UI sizes, universal/pairwise/unique loot, duplicates, immutable source arrays, missing/partial/failed pools, delayed completion, icon reuse, comparison tooltip ownership, horizontal overflow, empty-column messaging, and difficulty/context/combat invalidation. Checked acceptance items reflect automated coverage; native spacing, hit testing, clipping, tooltip layering, and scrolling still require the live procedure in `Tests/WindowSources.md`.

Implementation details:

- Presentation classification requires a final aggregate and final pools for every displayed specialization. Until then, completed individual pools retain their original loot and incomplete pools remain hidden; no shared row is inferred from partial data.
- Universal items are deduplicated by item ID and ordered by ascending ID, with original provider item metadata/links retained. Columns receive new arrays without universal IDs; pairwise items remain in each eligible column. Neither provider results nor cached arrays are modified.
- The pooled `window.sharedLoot` strip owns its label, icon frames, horizontal scroll child, slider/track/thumb, items, range, offset, and context binding. Native comparison tooltips use the same handler as column rows. Shared frames have no spec-selection handlers and lie outside column hover rectangles.
- The strip adds 64 UI units beneath the header, preserving 420-unit independent column viewports. Without shared items, the strip is hidden and those 64 units are reclaimed. Scale fitting uses the actual window height. Wheel/slider scrolling reaches the entire icon pool, clears moving tooltips, preserves same-context offset, and clamps after shrinkage; context changes reset it.
- Future Phase 9 skin application must cover `sharedLoot.label`, `sharedLoot.icons[*].icon`, and `sharedLoot.bar` (including track/thumb), including icons created after a skin change. The repository has no skin registry yet; both skin implementations remain Phase 9 work.

## Phase 6: Set and confirm loot specialization

Completes finding 2 and the addon's core player action.

### 6.1 Implement selection

- [x] Verify the client's loot-spec setter/getter and update event before wiring the handler.
- [x] Pass the stored specialization ID, not the column index, to the setter.
- [x] Recheck eligibility by context kind at click time: raid instance and encounter/target for raids, or the current supported dungeon visit for Mythic+ previews. Both require being outside combat; dungeon selection requires neither a target nor an active key.
- [x] Confirm selection from game state instead of assuming success because the setter was called.
- [x] Close the window after confirmed click selection and output the system message "Spekifier has set your loot specialization to [SPEC]."; suppress immediate automatic reopening.

### 6.2 Synchronize external changes

- [x] Initialize selection on opening and refresh when loot spec changes through Blizzard's UI.
- [x] Handle the game's "current specialization" loot setting and update the effective selected column when active spec changes.
- [x] Handle unavailable specialization information gracefully and retry at an appropriate lifecycle event.

Primary files: `UI/SpecColumns.lua`, `Modules/AutoShow.lua`; optionally new `Modules/LootSpecialization.lua`.

Acceptance checks:

- [x] Clicking each column passes the stored specialization ID and confirms from game state in mocked tests.
- [x] Hovering never changes loot spec.
- [x] External changes update the selected indicator without reopening.
- [x] Combat or invalid target changes immediately before clicking prevent an invalid selection attempt.
- [x] Failed selection preserves the prior confirmed state and provides useful feedback.

Live acceptance (user):

- [x] Verify each column's choice in Blizzard's loot specialization menu, including header, item-row and background clicks.
- [x] Verify hover, external changes, Current Specialization, active spec changes and dismissed-window behavior in WoW.
- [x] Verify combat/context changes, confirmation timing, unavailable data and any observed failure behavior on the supported Retail client.

Validation and checkbox evidence: [Phase 6 implementation matrix, automated acceptance and detailed live procedure](Tests/SelectionSources.md). `Tests/LootSpecialization.lua` passes 95 focused Lua 5.1 checks; all existing suites pass, for 768 unique checks. Checked acceptance items represent automated coverage; Blizzard UI and live input/event/taint checks remain pending. The setter/getter and update event were verified against Blizzard's exported API documentation before implementation.

Implementation: `Modules/LootSpecialization.lua` owns confirmed state, current-spec resolution, event synchronization and bounded confirmation. Every click re-resolves the actual context without opening a window. Failures never optimistically select a column. Selection remains available during loot loading for a supported context; unavailable specialization data fails closed and retries at lifecycle events. Confirmed clicks close as dismissal and print the exact named system-colored chat message once. Failure notices expire after three seconds; reopening reads the current game-confirmed indicator. Context changes and closing cancel obsolete pending requests/notices. No loot choice is saved by the addon or written on opening/hover/external updates.

## Phase 6.5: Add standard addon options and discovery

Make options accessible through the game settings, preview window, slash commands, and minimap. Establish the shared options page here; Phase 8 extends it with automatic-opening controls.

### 6.5.1 Register options and entry points

- [x] Verify supported Retail Settings APIs and register Spekifier under **Escape -> Options -> Addons**.
- [x] Centralize opening the registered options category so every entry point reaches the same page without duplicate registration.
- [x] Add `/spek options` and `/spek o` to open options directly; support the same subcommands under `/spekifier`.
- [x] Add a visible gear button with an **Options** tooltip to the `/spek t` window, including empty/unsupported preview states. Keep its hit area separate from title dragging, closing, and loot selection.
- [x] Keep options accessible independently of automatic-opening preferences and encounter eligibility; verify settings-opening behavior during combat on the supported client. Implementation and mocked independence checks pass; live combat verification remains pending.

### 6.5.2 Add a minimap launcher and visibility preference

- [x] Add a recognizable Spekifier minimap button, shown by default when no preference is saved. Left-click toggles the manual preview through its existing lifecycle; right-click opens options. Describe both actions in its tooltip.
- [x] Allow dragging the button around the minimap and persist its position across reload/login.
- [x] Add a **Hide minimap button** checkbox: checked hides the button; unchecked shows it. Apply changes immediately and persist the preference across reload/login.
- [x] Add `/spek minimap` and `/spek mm` as equivalent visibility toggles, also under `/spekifier`. Each invocation flips the saved preference, immediately updates the button and any visible checkbox, and prints whether the button is shown or hidden.
- [x] Use one shared preference/update path for checkbox and commands. Merge missing defaults without overwriting saved false values or existing preferences; repeated initialization must not duplicate buttons or handlers.
- [x] Keep options commands and the preview gear available while the minimap button is hidden so users can restore it easily.

### 6.5.3 Validate and document discoverability

- [x] Expand `/spek help` with options and minimap aliases; document all entry points, click actions, and the hide checkbox in `README.md`.
- [x] Register new runtime files and any chosen bundled launcher dependencies in the manifest in dependency order.
- [x] Add focused mocked coverage for shared options routing, command aliases, visibility synchronization, defaults/migration, saved position, and repeat initialization.
- [x] Verify in WoW that the Addons category, gear, options commands, and minimap right-click open the same page; verify minimap left-click preserves manual-preview combat/context behavior.
- [x] Verify checkbox and both minimap commands stay synchronized, apply immediately, survive reload/login, and restore a hidden button. Check dragging, tooltip, placement, and gear hit areas at multiple UI scales.

Validation: `Tests/Options.lua` passes 63 focused Lua 5.1 checks plus the existing 267 lifecycle checks. All seven suites pass (831 unique checks). Checked implementation and acceptance items reflect mocked coverage and source verification; live category rendering, combat Settings restrictions, input/drag/tooltip placement, persistence and multiple-scale checks remain pending. See [API evidence, automated coverage and required live procedure](Tests/OptionsSources.md). The combat-opening portion of 6.5.1 is implemented through Blizzard's native Settings path but still requires live verification.

Primary files: new `UI/Options.lua`, new `UI/Minimap.lua`, `UI/MainWindow.lua`, `Modules/Commands.lua`, `Core/Database.lua`, initialization wiring, `Spekifier.toc`, focused options/launcher tests, `README.md`.

Acceptance checks:

- [x] Spekifier appears in **Escape -> Options -> Addons**, and every options entry point reaches that same page.
- [x] The preview window has an identifiable, working options gear.
- [x] The minimap launcher supports preview/options access and persists its dragged position.
- [x] **Hide minimap button**, `/spek minimap`, and `/spek mm` share a persistent, immediately synchronized visibility preference; hidden buttons can be restored through commands or options.
- [x] Existing preview, automatic-opening, dismissal, and loot-selection behavior remains intact.

## Phase 7: Integration validation and release preparation

### 7.1 Validate the complete workflow

- [x] Add focused automated coverage for boss rejection, visibility/dismissal transitions, encounter mapping, and stale asynchronous results.
- [x] Test fresh saved variables and upgrades from the existing layout with mocked settings migration.
- [x] Verify with automated checks that repeated targeting does not accumulate frames, handlers, or unnecessary loot requests.

### 7.2 Document and package

- [x] Document raid-target and Mythic dungeon-entry workflows, supported scope, commands, preview behavior, and known limitations in `README.md`, including Mythic+ preview before a key starts.
- [ ] Document the live-validated supported Retail build and final confirmed-selection workflow after integration acceptance.
- [x] Expand `/spek debug` with encounter, difficulty, visibility reason, loading state, and per-spec loot counts while keeping normal operation quiet.
- [x] Add confirmed loot specialization to `/spek debug` after Phase 6.
- [ ] Set accurate interface/version metadata and replace the placeholder author when provided.
- [x] Verify runtime files introduced through Phase 5 appear in the correct manifest order.
- [x] Verify final manifest order for all current runtime files through Phase 7; repeat when Phases 8/9 introduce files.

Phase 7 automated validation (2026-10-08): all eight Lua 5.1 suites pass, totaling 850 unique checks. `Tests/Integration.lua` adds 19 confirmed-specialization debug checks. `Tests/run_tests.py` verifies syntax, exact manifest order and registration of all 14 runtime files, then optionally creates and validates a clean-install candidate archive. Debug reports the getter's raw setting, Current Specialization/explicit mode and effective confirmed ID/name even with the preview dismissed. The live integration checklist and release record are in `Tests/IntegrationSources.md`. Fresh/upgrade login, clean-folder installation, final build/interface and release author remain pending user evidence; prior Phase 1–6.5 confirmation is not counted as Phase 7 acceptance.

### Manual acceptance checks (in WoW)

Record the tested Retail version/build/interface and results in `Tests/IntegrationSources.md`. Check these items only after live verification; the earlier Phase 1 through 6.5 confirmation does not complete Phase 7 integration acceptance.

- [ ] Verify fresh saved variables and upgrades through actual WoW login/reload.
- [ ] Run in-game checks for outdoor areas, dungeon bosses, raid trash, supported raid bosses, multi-boss fights, dead bosses, combat, wipes, and zone exits.
- [ ] Exercise reload/login, rapid target changes, difficulty changes, slow item loading, dismissal, and manual preview.
- [ ] Validate Mythic entry before a key, active-key entry, keystone start, duplicate entry events, combat deferral, dismissal across target/combat changes, exit/re-entry, and Normal/Heroic exclusion.
- [ ] Confirm full dungeon-wide Mythic+ chest loot per spec and confirmed selection in WoW, including before a key starts. Verify obsolete dungeon results are discarded and dungeon exit prevents selection using stale context.
- [ ] Confirm repeated-target behavior and frame/handler stability in WoW.
- [ ] Check for Lua errors and API restrictions on the supported Retail build.
- [ ] Install from a clean addon folder and repeat the primary boss-target-to-loot-selection workflow.

## Phase 8: Add addon options for automatic opening

Let users choose where the loot comparison window opens automatically.

### 8.1 Extend the options UI and saved preferences

- [ ] Extend the Spekifier options page registered in Phase 6.5 with automatic-opening controls, retaining its entry points and independent minimap visibility preference.
- [ ] Add a parent **Auto-show** checkbox backed by the existing `enabled` preference.
- [ ] Add five indented child checkboxes: **Mythic+**, **LFR**, **Normal Raid**, **Heroic Raid**, and **Mythic Raid**.
- [ ] Disable child controls while Auto-show is off, retaining their saved values so re-enabling the parent restores the user's choices.
- [ ] Default all five child preferences to on to preserve existing automatic-opening behavior. Merge missing defaults without overwriting saved false values or the existing parent preference.
- [ ] Explain that Mythic+ controls the Mythic+ end-of-run loot preview on both ordinary Mythic dungeon entry and active Mythic+ entry, including before a key starts.
- [ ] Persist changes across reloads and logins, and document the options in `README.md`.

### 8.2 Apply preferences to automatic opening

- [ ] Require both the parent toggle and the matching child toggle before automatically opening the window.
- [ ] Map actual instance difficulty to the appropriate raid option using verified difficulty identifiers; explicitly define handling for supported legacy raid difficulties and fail closed for unmapped difficulties.
- [ ] Apply the Mythic+ preference to the existing dungeon-entry prompt without changing supported-context resolution or loot mode.
- [ ] Reevaluate automatic visibility immediately when an option changes. Turning off the applicable child or parent closes an automatically opened window; manual previews remain governed by the existing manual lifecycle.
- [ ] Keep `/spek toggle` available regardless of auto-show preferences, subject to existing combat and context restrictions.
- [ ] Preserve raid dismissal, combat deferral, and once-per-dungeon-visit prompting. Changing preferences must not clear dismissal or reset a consumed dungeon prompt; an eligible, unshown visit can prompt when enabled.
- [ ] Include the applicable difficulty preference and effective auto-show permission in `/spek debug`.

Primary files: `UI/Options.lua`, `Core/Database.lua`, `Modules/AutoShow.lua`, initialization wiring, `Modules/Commands.lua`, `Spekifier.toc`, `Tests/AutoShow.lua`, `README.md`.

Acceptance checks:

- [ ] The parent toggle suppresses automatic opening in all five categories, regardless of child values.
- [ ] Each child toggle independently controls its matching category when the parent is on.
- [ ] Disabling and re-enabling the parent preserves every child choice; saved choices survive reload/login and settings migration.
- [ ] Preference changes update automatic visibility immediately without reopening dismissed raid prompts or consumed dungeon prompts.
- [ ] Mythic+ controls both ordinary Mythic and active-key entry; Normal/Heroic dungeons remain excluded.
- [ ] Manual preview, supported-context checks, combat restrictions, and existing dismissal behavior still work with any preference combination.
- [ ] Focused mocked coverage verifies preference gating and lifecycle transitions; in-game checks verify settings registration, checkbox dependencies, persistence, and difficulty-specific prompting.

## Phase 9: Add selectable window skins and visual polish

Let players choose the window's appearance from the addon options. This phase includes implementing and polishing the actual window skins as well as the settings control.

### 9.1 Extend addon options with skin selection

- [ ] Add a **Window skin** dropdown to the shared options page introduced in Phase 6.5 and extended in Phase 8 with exactly two initial choices: **Original** and **Elles**.
- [ ] Keep skin selection available independently of the Auto-show parent toggle so manual-preview users can also customize the window.
- [ ] When no skin preference is saved (including existing users upgrading), default to Elles if EllesmereUI or ElvUI is installed and running; otherwise default to Original. Check whether either addon is actually loaded after startup addon loading has completed; an installed but disabled or unloaded addon must not trigger the Elles default.
- [ ] Persist the selected skin across reloads/logins and never override a valid saved choice when addon availability changes. Safely fall back to Original for unknown saved skin identifiers.
- [ ] Populate the dropdown from an extensible skin registry using stable identifiers and display labels so future skins can be added without rewriting the options control.
- [ ] Apply changes immediately to an open window and use the saved choice whenever the window is created or reopened. Changing skins must not open a hidden window or reset its lifecycle state.

### 9.2 Implement both visual treatments

- [ ] Capture the window's established appearance as the Original skin, preserving its recognizable Blizzard-style presentation while completing consistent styling for all Phase 5 elements.
- [ ] Establish visual references for the Elles treatment, informed by the requested EllesmereUI/ElvUI aesthetic, and document its palette, typography, borders, spacing, and interaction states before implementation.
- [ ] Implement Elles as a complete alternate appearance with a clean dark background, restrained borders, readable typography, consistent spacing, and clear accent colors. Ship it as a built-in skin usable without installing EllesmereUI or ElvUI addons.
- [ ] Style the entire window in both skins: outer frame, title and encounter/difficulty header, close and options gear buttons, specialization headers/icons, column backgrounds, item rows, scrollbars, and status/confirmation messages.
- [ ] Give hover, confirmed selection, and disabled states distinct, readable treatments in both skins. Preserve item-quality readability and legible loading, empty, unsupported, and failure states.
- [ ] Centralize skin properties and application logic in a focused UI module. Ensure newly created or reused item rows receive the current skin, and remove the previous skin's textures, borders, and overrides when switching.
- [ ] Preserve window position, displayed loot, scroll position, confirmed loot specialization, and dismissal state across skin changes. Keep dragging, tooltips, scrolling, and click selection functional.
- [ ] Check both appearances with different specialization counts, long names, long loot lists, and multiple UI scales; adjust sizing and spacing to prevent clipping or overlap.

### 9.3 Add player-controlled window resizing

- [ ] Let players resize the window's width and height using a draggable bottom-right corner grip with the classic diagonal resize lines, styled consistently for both Original and Elles skins.
- [ ] Set minimum dimensions and screen bounds that keep controls and content usable; adapt columns, item rows, and scrollable content while resizing without clipping or overlap.
- [ ] Keep the resize grip's hit area separate from window dragging and loot selection.
- [ ] Persist the chosen window size across closing/reopening and reload/login, safely default missing or invalid saved dimensions, and preserve the size when switching skins.
- [ ] Verify resizing in WoW with both skins, different specialization counts, long loot lists, and multiple UI scales, including minimum dimensions, screen bounds, persistence, and skin switching.
- [ ] Document the diagonal resize grip and saved window-size behavior in `README.md`.

### 9.4 Validate and document the finished appearance

- [ ] Add focused coverage for default/migrated preferences, invalid-skin fallback, registry-driven selection, and repeated application to existing and newly created UI elements.
- [ ] Cover automatic defaults with EllesmereUI only, ElvUI only, both, neither, and installed-but-disabled/unloaded addons. Include an addon loading after Spekifier during startup, existing users with no skin preference, and preservation of either valid saved choice regardless of addon availability.
- [ ] Verify both skins in WoW, including repeated switching with the window open, changes while hidden or in combat, reload/login persistence, and interaction with the Phase 8 auto-show settings.
- [ ] Capture comparison screenshots of both completed skins and review all interaction and data-loading states for visual consistency and readability.
- [ ] Document the skin dropdown, addon-aware default, persistence, and how to register future skins in `README.md`; register new runtime files in the manifest in dependency order.

Primary files: new `UI/Skins.lua`, `UI/Options.lua`, `UI/MainWindow.lua`, `UI/SpecColumns.lua`, item-row rendering from Phase 5, `Core/Database.lua`, `Spekifier.toc`, focused UI/settings tests, `README.md`.

Acceptance checks:

- [ ] The options dropdown offers Original and Elles, and remains usable when Auto-show is disabled.
- [ ] With no saved skin preference, Elles is selected when EllesmereUI or ElvUI is installed and running, regardless of startup load order; otherwise Original is selected. A valid saved choice always takes precedence.
- [ ] Both choices produce complete, visibly distinct window appearances, covering loot rows and interaction states as well as the outer frame.
- [ ] Switching skins updates a visible window immediately without losing its content, position, scroll position, or confirmed selection, and without changing prompt/dismissal behavior.
- [ ] Hidden windows use the selected skin on their next opening; repeated switching leaves no leftover visuals, duplicate frames, or duplicate handlers.
- [ ] The selected appearance survives reload/login, unknown saved values fall back safely, and future skins can be registered through the same dropdown mechanism.
- [ ] Both skins remain readable and fully interactive across the tested layouts and UI scales, with in-game visual validation recorded.

## Definition of done

- [ ] Options are reachable through the game's Addons settings, preview gear, options commands, and minimap launcher; the hide checkbox and minimap commands immediately synchronize and persist button visibility.

- [ ] A supported living raid boss targeted outside combat opens the correct difficulty-aware loot comparison.
- [ ] Every specialization has an accurate eligible-loot list, column highlight, and working click selection.
- [ ] Selected state reflects the game's confirmed loot specialization.
- [ ] Supported Mythic dungeon entry prompts once per visit with dungeon-wide Mythic+ chest loot, without requiring a target or active key and subject to combat deferral.
- [ ] Non-Mythic dungeon entry, dungeon targets, outdoor areas, trash, and combat never trigger an automatic popup.
- [ ] Dismissal, target changes, reloads, and delayed data cannot restore stale or misleading UI.
- [ ] Unsupported encounters are handled clearly, supported scope is documented, and the integrated workflow has been verified in WoW.
- [ ] A persistent parent Auto-show option and independent Mythic+, LFR, Normal Raid, Heroic Raid, and Mythic Raid options control automatic opening while preserving manual preview and dismissal behavior.
- [ ] Players can choose complete Original and Elles window skins from a persistent, extensible options dropdown, with both appearances visually validated and existing interactions preserved.
