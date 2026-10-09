# Phase 10: Lua module structure

Layout update (Phase 11): runtime paths in this historical record are now relative to `src/`. Suite commands and links use the relocated `spec/` paths. Earlier candidate descriptions record the packaging at that time; current ZIPs contain only `src/` contents under `Spekifier/`, and acceptance documentation stays in the repository. See [current packaging instructions](../README.md#validation-and-packaging).

The 2026-10-09 refactor separates existing responsibilities without changing the addon feature set, saved-variable schema, supported encounter scope, or confirmed-selection contract. Runtime files grow from 15 to 31; the largest file falls from 468 to 169 lines. Small cohesive modules stay intact. No runtime dependency or module-loader framework is added.

## Ownership migration

Historical implementation and API-evidence documents refer to the original paths. Their evidence remains applicable to the extracted code; this table identifies its current owners.

| Previous file | Current owner(s) |
| --- | --- |
| `Modules/EncounterResolver.lua` | `Modules/Context/RaidCatalog.lua`, `Resolver.lua` |
| `Modules/AutoShow.lua` | `Modules/Context/AutoShow.lua` |
| `Modules/LootProvider.lua` | `Modules/Loot/Model.lua`, `Provider.lua`, `Journal.lua`, `Events.lua` |
| `Modules/LootSpecialization.lua` | `Modules/Loot/Selection.lua` |
| `UI/MainWindow.lua` | `UI/Window/Lifecycle.lua`, `LootBinding.lua`; request identity and hidden diagnostics in `Modules/Loot/RequestIdentity.lua`, `Diagnostics.lua` |
| `UI/SpecColumns.lua` | `UI/Loot/Tooltips.lua`, `DisplayLists.lua`, `SharedRow.lua`, `ItemRows.lua`, `Columns.lua`, `Renderer.lua`; screen fitting in `UI/Window/Fit.lua` |
| `UI/Skins.lua` | `UI/Skins/Registry.lua`, `Palettes.lua`, `Presentation.lua`; options control in `UI/Options/SkinDropdown.lua`; sizing in `UI/Window/Layout.lua` |
| `UI/Options.lua` | `UI/Options/Panel.lua` |
| `Spekifier.lua` | Removed: it contained no startup behavior. `Core/Events.lua` continues to own initialization. |

Core settings/events/logging, slash commands, and the minimap launcher retain their existing ownership. Internal helpers use the shared addon namespace. File-local Journal selection tracking remains private to the Journal transaction code; provider request/cache state remains on `Spekifier.LootProvider`. UI lifecycle state stays private to the lifecycle file and is accessed through the existing getters.

The manifest is the production loader. Every runtime file is listed once in dependency order. Tests retain isolated module fixtures and add `spec/Manifest.lua`, which loads the real manifest into a fresh addon namespace using the existing game mocks, fires startup events, and verifies end-to-end delivery and interactions. No mock regression assertions were relaxed to accommodate the move; manifest path assertions were updated.

## Automated validation

Baseline: the repository's `.test-venv/Scripts/python.exe spec/run_tests.py` passed all ten original Lua 5.1 suites (1,522 unique checks) before editing. The system Python launcher lacks Lupa; the existing local environment supplies it.

Final validation (2026-10-09): `.test-venv/Scripts/python.exe spec/run_tests.py --package Spekifier-phase10-candidate.zip` passes all eleven Lua 5.1 suites, 1,566 unique checks (the original 1,522 plus 44 manifest/startup checks), compilation of all Lua sources, the exact 31-file manifest contract, and ZIP integrity/content verification. `spec/Manifest.lua` covers the production load order and cross-module startup, Journal filter restoration, rendering, skin switching, dismissed diagnostics, manual reopening and confirmed selection. The package includes PLAN.md so its README and acceptance links resolve in a clean installation. The package never includes the virtual environment or test scripts.

## Manual procedure (pending)

1. Back up existing SavedVariables and install `Spekifier-phase10-candidate.zip` into a clean addon folder. Removing obsolete files avoids accidentally testing a mixture of layouts. Confirm that `Spekifier.toc` is directly inside `AddOns/Spekifier`.
2. Login and reload with existing preferences. Verify the saved skin, dimensions, automatic-opening choices, and minimap visibility, and check for missing-file or Lua errors.
3. Repeat the [integration procedure](IntegrationSources.md), [automatic-opening checks](Modules/Context/AutoShowPreferencesSources.md#manual-procedure-pending), and [skin/resizing checks](UI/Skins/SkinsSources.md#manual-procedure-pending). Include supported raid targets and Mythic dungeon entry, combat/dismissal, delayed data, shared-item scrolling, native tooltips, and confirmed loot selection.
4. Exercise every settings entry point and both skins. Run `/spek debug` while dismissed and confirm it reports loot without opening the window or resetting dismissal.
5. Record client build, content/difficulty, results, and screenshots where requested. Check Phase 10 Manual Acceptance in PLAN.md only after actual execution or explicit user confirmation. Prior confirmed results remain historical evidence, not a new live pass for this build.

WoW is unavailable in this workspace. Live regression and outstanding Phase 7/8/9 acceptance remain pending; automated success does not establish release readiness.
