# Spekifier Add-on Structure

## Folder Organization

### Core/
Contains the fundamental systems and initialization logic:
- **Init.lua** - Initializes the add-on namespace and main frame
- **Database.lua** - Manages saved variables (SpekifierDB) and settings
- **Debug.lua** - Centralized debug output management
- **Events.lua** - Handles WoW events (ADDON_LOADED, PLAYER_LOGIN, etc.)

### UI/
Contains all user interface components:
- **Skins.lua** - Built-in skin registry, styling, responsive layout and saved resizing
- **MainWindow.lua** - Creates and manages the main window frame
- **Options.lua** - Shared Retail Addons settings page, preview gear and minimap visibility preference
- **Minimap.lua** - Draggable native preview/options launcher
- **SpecColumns.lua** - Creates and manages specialization columns

### Modules/
Contains feature modules:
- **Commands.lua** - Slash command registration and handling (/spek, /spekifier)
- **EncounterResolver.lua** - Verified raid and dungeon reward-source identity
- **LootProvider.lua** - Per-spec Journal loot requests, delayed data, cancellation, and memory caching
- **AutoShow.lua** - Automatic window display based on resolved game contexts

### Root Files
- **Spekifier.toc** - Add-on manifest file (defines load order)
- **Spekifier.lua** - Main entry point (loaded last)

## Load Order
Files are loaded in the order specified in Spekifier.toc:
1. Core files (Init, Database, Debug, Events)
2. EncounterResolver, LootProvider and LootSpecialization
3. UI files (Skins, Options, Minimap, MainWindow, SpecColumns)
4. Remaining modules (Commands, AutoShow)
5. Main entry point (Spekifier.lua)

## Installation
Place the entire Spekifier folder in:
`World of Warcraft\_retail_\Interface\AddOns\`

## Usage
- `/spek` or `/spek help` - Show help
- `/spek t` or `/spek toggle` - Toggle window
- `/spek options` or `/spek o` - Open Spekifier options
- `/spek minimap` or `/spek mm` - Toggle minimap button visibility
- All subcommands also work under `/spekifier`.
- `/spek debugmode` - Toggle debug mode on/off
- `/spek debug` - Show auto-show debug information (always available)

## Debug Mode
By default, Spekifier runs silently without chat output. Enable debug mode with `/spek debugmode` to see:
- Add-on load messages
- Player login messages
- Dungeon entry and keystone events, including localized instance and difficulty names supplied by the game
- Lookup failures and reasons the window stayed closed (combat, dismissal, consumed visit, or disabled automatic opening)
- Successful automatic openings

Enabling debug mode immediately reports the current context. Unchanged unit events are suppressed to avoid chat spam. Debug mode diagnoses window behavior; automatic opening still follows the normal eligibility and dismissal rules.

Debug mode persists between sessions.

## Auto-Show Feature
With automatic opening enabled, the window appears for a raid target when all three conditions are met:
1. Player is in a raid instance
2. Player has targeted a boss unit
3. Player is NOT in combat

Automatically opened windows close when the target becomes invalid, the player leaves the raid, or combat begins. Closing with the close button, Escape, or `/spek toggle` suppresses another prompt while the same boss remains continuously targeted. Clearing/changing the target or ending combat permits a fresh prompt.

Entering a Mythic or Mythic+ dungeon also opens the window once per eligible visit, without a target or active key. Normal/Heroic entry and dungeon boss targeting do not trigger it. The dungeon preview is explicitly labeled **Mythic+ end-of-run loot**, including on ordinary Mythic entry. Duplicate world/zone events, target changes, keystone start, and combat after the first display do not prompt again. Entry during combat is deferred until combat ends if an eligible visit is still current. Dismissal lasts for the visit; leaving and re-entering allows another prompt. Dungeon exit closes the window.

`/spek toggle` opens a manual preview outside combat, including when automatic opening is disabled. Outside eligible raid or dungeon context, it shows an explanatory empty state with dimmed specialization columns and selection disabled. Manual previews also close when combat begins, and dungeon previews close on dungeon exit. Manually displaying a dungeon preview consumes that visit's automatic prompt, even with automatic opening disabled; explicit manual reopening remains available. Window visibility is never restored from saved variables; login/reload evaluates current eligibility afresh.

Raid support currently covers **The Voidspire (all six encounters)** and **The Silken Court in Nerub'ar Palace**. Both units of Vaelgor/Ezzorak and the Silken Court, and all three Lightblinded Vanguard members, share their respective encounter. Boss classification, level, and localized target names do not determine eligibility. Unsupported targets, restricted identities, and unavailable or mismatched Journal data fail closed.

Dungeon support follows the Retail client's challenge-map catalog: the current game instance must uniquely match a challenge map and resolve to a Journal instance. Unsupported or ambiguous dungeons do not prompt. Mythic+ data is requested at initialization and on each new eligible dungeon visit. Entry retries for up to five seconds accommodate delayed instance, challenge-map, or Journal data; catalog updates can also resolve later without consuming the visit. Resolved contexts identify the dungeon-wide Mythic+ end-of-run reward source separately from actual Mythic/Keystone difficulty; the comparison retrieves the agreed combined Mythic boss pool without implying an exact reward item level.

Phase 3 targets Retail 12.x APIs; the manifest's `120000` declaration does not establish live build compatibility. See [lookup evidence and supported scope](Tests/EncounterSources.md). Loot comparison is available; confirmed specialization selection is implemented. `/spek debug` reports encounter, Journal instance, NPC/unit identity, difficulty, challenge map, reward source, and resolution failure, alongside lifecycle state. Unsupported manual previews explain why resolution failed.

## Validation
Run `lua Tests/AutoShow.lua` from the repository root for the mocked lifecycle and settings-migration checks (267 passing checks, including raid/dungeon transitions and encounter resolution). Live WoW validation of Escape, template closing, combat frame behavior, Retail API restrictions, dungeon entry, and keystone event timing remains pending.

## Phase 4 loot data

The window now owns per-specialization loot results for its resolved context. Raids query the actual Journal encounter/difficulty. Mythic dungeon entry queries the combined boss pool from the full dungeon Journal at Mythic difficulty 23, independently of entry difficulty or a started key. Items are deduplicated and per-player bonus drops (such as recipes) are excluded; the preview remains labeled Mythic+ end-of-run loot. Unsupported/coerced difficulties fail closed. No exact dungeon reward item level is claimed without a key level.

`/spek debug` reports the current loot state, failure reason, and item count for each named specialization (including its ID). Rejected difficulties also report requested/base and available Journal difficulty IDs. Ready/empty counts are final; loading/failed counts are explicitly incomplete or unavailable. Compare final counts with equivalent Adventure Guide filters, then check item identities as well: equal counts alone do not establish identical loot. Queries preserve observable Journal selections and filters, defer while the Adventure Guide is open, and cancel on stale contexts or visits. Finished pools are cached in memory. Live loot accuracy and Guide interaction still need validation; Item-list presentation is implemented; confirmed click selection is implemented.

Run `lua Tests/LootProvider.lua` and `lua Tests/WindowLoot.lua` from the repository root. The latter also runs the existing lifecycle suite. All 386 checks pass with Lua 5.1. See [loot API evidence and live acceptance procedure](Tests/LootSources.md) for the provider interface, delayed-data behavior, and Journal restoration limits.

Murder Row (Journal 1304) exposes difficulties 1, 2, and 23; it now uses the combined difficulty-23 boss pool instead of requiring difficulty 8. After `/reload`, enter the dungeon and run `/spek debug`. Look for `Loot Query Journal Difficulty ID: 23`, scope `all dungeon bosses; Mythic+ preview`, and final per-spec counts. Compare each specialization with the Adventure Guide's Mythic view across all bosses, with all slots and no search. Ignore the separate per-player bonus-loot category, and verify item identities as well as counts. Live acceptance remains pending until these comparisons pass.

Debug comparisons also work with the preview dismissed: `/spek debug` retrieves current-context counts without reopening the window or resetting the visit prompt. Repeated polls reuse the pending request, so delayed data can reach ready. `Loot Comparison State` describes these results independently of the preview's `Loot State`. If combat or context loss prevents inspection, `Loot Counts Unavailable` gives the reason. A missing display reference is repaired from the active request without repeating the query.

## Loot comparison window

The header identifies the raid boss and actual difficulty, or the compact dungeon header **<Dungeon name>: Mythic+** (including ordinary Mythic entry). This still identifies the end-of-run comparison pool. Each spec has a fixed icon/name header and an independent scrollable item list. Use the mouse wheel over a column or drag its scrollbar. Hover an item for its original item-link tooltip; hover a spec header for its full name. Drag the window by its title bar.

Rows are reused during refreshes. Changing context clears old items and tooltips immediately and resets scrolling; updates within the same context preserve scroll position. Loading, empty, unsupported, and failed results have explicit messages. Partial loading/failed pools are hidden to avoid suggesting that they are complete loot lists. The window adapts to specialization count and fits the current UI dimensions on display/scale changes.

Whole-column hover, selected, and unavailable-selection appearances are implemented. Click a spec header, column background or item row to select its loot specialization. Hovering never changes loot spec.

Run `lua Tests/WindowPresentation.lua`, `lua Tests/WindowLoot.lua`, and `lua Tests/LootProvider.lua`. The first two also execute the lifecycle suite. There are 507 unique passing Lua 5.1 checks. See [window acceptance procedure and API evidence](Tests/WindowSources.md); live WoW visual/input validation remains pending.

The initial window is now at least 1080?720 UI units, with width adjusted for spec count and scale reduced only when needed to fit the screen. It uses FULLSCREEN_DIALOG layering, beneath native item and comparison tooltips. Combat still closes the preview and prevents reopening. Ready columns clear their loading message.

Spec icons are 56 pixels with 22-point names; loot icons are 40 pixels with 18-point names and taller rows. Item hover uses the same native hyperlink/comparison tooltip data path as the Adventure Guide, with tooltip parent/alpha reset and no override of shared tooltip frame levels. Equivalent loot refreshes preserve an already-visible item tooltip.

## Shared loot (Phase 5.5)

After every displayed specialization has a complete loot pool, items eligible for every spec appear once as icons after **Shared:** directly beneath the raid or dungeon header. The columns then show the differences: items shared by only some specs remain in each eligible column. The rule includes classes with two or four specs. Shared items use a stable item-ID order and retain their original item links; provider pools, cached loot, and debug counts remain unchanged.

Hover shared icons for native item and equipped-item comparison tooltips. Shared icons never select or highlight a specialization. Use the wheel over the shared strip or drag its horizontal scrollbar to reach overflow items. Column lists retain independent vertical scrolling and fixed spec headers. A column with only universal loot says **All eligible loot is shared above.** Without shared items the row disappears and its space is reclaimed.

Loading or failed/partial pools never create a shared row. Completed individual columns keep their full lists until all pools finish. Refreshes reuse icon frames, preserve current-context horizontal scrolling, and remove obsolete links/tooltips; changing context or difficulty, closing, and combat clear the strip immediately.

Run `lua Tests/SharedLoot.lua` for 166 focused acceptance checks, including real provider callbacks and cache preservation. Together with the existing suites, 673 unique Lua 5.1 checks pass. Live WoW spacing, clipping, tooltip layering, overflow, and input acceptance at multiple scales remain pending; see [the acceptance procedure](Tests/WindowSources.md). Phase 9 must include the shared strip in both future skins.

## Confirmed loot specialization (Phase 6)

Click a specialization to set its stored spec ID. The addon rechecks the current supported raid target or dungeon visit and combat state at click time. Dungeon selection needs neither a target nor an active key; manual preview supports selection even with automatic opening disabled. Selection works while loot loads, but requires available player specialization information.

The Selected marker reflects the game's getter when the preview is open. A confirmed click closes the window and prints the system-colored chat message `Spekifier has set your loot specialization to [SPEC].` Closing counts as dismissal, preventing immediate automatic reopening. Silent/throwing failures preserve game-confirmed state and show feedback; an unconfirmed attempt times out after two seconds. External Blizzard menu changes refresh the marker without reopening a dismissed preview. Current Specialization follows the active spec; an explicit loot spec remains independent. The addon never saves or restores a loot choice.

Run `lua Tests/LootSpecialization.lua` for 95 focused checks plus the existing lifecycle suite. All suites pass with Lua 5.1 (768 unique checks). See [per-checkbox evidence and detailed live acceptance](Tests/SelectionSources.md). In-game Blizzard menu, event timing, visuals and taint validation remain pending.

## Options and minimap launcher

Find **Spekifier** under **Escape -> Options -> Addons**. The preview's title-bar gear (tooltip: **Options**), `/spek options`, `/spek o`, and minimap right-click all open this same page. Options access is independent of automatic opening and encounter eligibility. The gear remains available in empty and unsupported previews.

**Auto-show** enables automatic prompting. Its five indented choices (**Mythic+**, **LFR**, **Normal Raid**, **Heroic Raid**, **Mythic Raid**) independently control where prompts appear. All default to on, including when upgrading. Turning off Auto-show disables its child controls while preserving their choices; all choices survive reload/login. Minimap visibility remains independent.

Mythic+ covers the end-of-run loot preview on both ordinary Mythic dungeon entry and active Mythic+ entry, including before a key starts. Normal/Heroic dungeons remain excluded. Raid options use actual instance difficulty: LFR 7/17, Normal 3/4/9/14 (including legacy 40-player), Heroic 5/6/15, and Mythic 16/233. Unmapped difficulties, including Story, Timewalking and world raids, do not automatically prompt. These categories never expand the supported encounter scope.

Changes take effect immediately: disabling the applicable option closes an automatic preview; manual previews remain available through `/spek toggle` and the minimap launcher outside combat. Changing options preserves raid dismissal and consumed dungeon prompts. Enabling an eligible unshown visit permits its first prompt, with existing combat deferral. `/spek debug` includes the matching preference, its saved permission, and effective parent/child permission. See [Phase 8 validation and live procedure](Tests/AutoShowPreferencesSources.md).


The minimap button is shown by default. **Left-click** toggles the manual preview through its normal combat/context/dismissal lifecycle; **right-click** opens options. **Drag** around the minimap to reposition it. Its position is saved across reload/login and adapts to minimap scale and size.

On the options page, check **Hide minimap button** to hide it; uncheck to show it. `/spek minimap` and `/spek mm` each flip the same saved preference, apply immediately, synchronize an open checkbox and print whether the button is shown or hidden. Both commands also work under `/spekifier`. Restore a hidden button through the commands or options page; the options commands and preview gear remain accessible. Existing false preferences and unrelated settings are preserved during migration.

Options use Blizzard's native Settings opening path. Combat preview restrictions remain unchanged. Live Settings-opening behavior during combat, launcher placement, gear hit areas and multiple UI scales still require WoW validation. Run `lua Tests/Options.lua` for 63 focused options/launcher checks plus the lifecycle suite. All seven suites pass with Lua 5.1, totaling 831 unique checks. See [API evidence and the live acceptance procedure](Tests/OptionsSources.md).

## Integration validation and release candidate (Phase 7)

Run all eight mocked suites with Lua 5.1, including `lua Tests/Integration.lua`, or use `python Tests/run_tests.py` with the Python `lupa` package installed. All 850 unique checks pass. The runner also compiles all Lua files and verifies the final manifest order and complete registration of runtime files.

`/spek debug` now reads the game-confirmed loot specialization even with the preview dismissed. It reports the raw loot setting (0 means Current Specialization), mode, effective confirmed spec ID/name and selection availability. Getter failures and invalid IDs report unavailable confirmation. The command preserves dismissal and does not reopen the preview.

Build a clean-install candidate with `python Tests/run_tests.py --package Spekifier-phase7-candidate.zip`. The archive contains one `Spekifier` folder with the manifest, runtime files and documentation; it excludes development scripts and saved variables. All checks must pass before packaging, and archive contents are verified. Extract that folder into the Retail client's `Interface/AddOns` directory for the clean-install acceptance test.

The user's live confirmation covers Phases 1 through 6.5 and supersedes their earlier pending-live notes above. Phases 1-7 implementation is complete. Final integration acceptance, exact supported Retail version/build/interface, author metadata and clean-install testing are deferred until all implementation phases are complete and tracked in [Manual Acceptance](PLAN.md#manual-acceptance). The current manifest is not evidence of tested compatibility. Record results using [the Phase 7 acceptance checklist](Tests/IntegrationSources.md) before treating the candidate as a validated release. Future auto-show options and skins remain Phases 8 and 9.

## Window appearance and resizing

Choose **Window skin** on the shared Spekifier options page: **Original** retains Blizzard-style chrome and gold accents; **Elles** uses dark panels, restrained slate borders and cyan accents. Both are built in and work without other UI addons. The dropdown remains available with Auto-show off.

On the first login without a saved choice, Elles is selected if EllesmereUI or ElvUI has finished loading by PLAYER_LOGIN; otherwise Original is selected. Installed but disabled/unloaded addons do not count. Valid saved choices always win on subsequent logins, even if addons change. Unknown saved identifiers fall back to Original. Changes apply immediately without opening hidden windows or resetting dismissal, loot, scroll offsets, position or confirmed selection.

Drag the **diagonal bottom-right resize grip** to change width and height. The title still moves the window; the grip has a separate hit area. Columns and scrolling areas adapt, including shared-item overflow. Size persists across closing, reopening, reload and login, and survives skin switching. Invalid dimensions use defaults, finite dimensions are clamped to usable minimums and current display bounds, and small displays scale the minimum layout to fit. Appearance and size preferences are account-wide.

To add a built-in skin, call `Spekifier:RegisterWindowSkin("stable-id", "Display label", palette)` from a runtime file loaded after UI/Skins.lua and before PLAYER_LOGIN. Supply `bg`, `border`, `accent`, `selected`, `disabled`, and `text` as RGBA arrays plus a client-compatible `font` path; use the built-in palettes as examples. Stable identifiers are saved; labels appear automatically in the registry-driven dropdown. Shared styling owns reusable textures and resets template chrome on every switch. New/reused loot rows receive the active palette without changing item quality colors.

Phase 9 automated checks and the visual specification are recorded in [Tests/SkinsSources.md](Tests/SkinsSources.md). Live visuals, comparison screenshots, and WoW resizing/interaction acceptance remain pending in PLAN.md; automated validation does not establish release readiness.
