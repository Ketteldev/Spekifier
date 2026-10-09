# Phase 8 automatic-opening options

## API and policy evidence

Difficulty identifiers were verified on 2026-10-09 against Blizzard's exported [DifficultyUtil_Base.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/DifficultyUtil_Base.lua). Mapping is explicit: Normal 3/4/9/14, Heroic 5/6/15, LFR 7/17, Mythic 16/233, World Raid 250; dungeon Mythic+ preview 8/23. Legacy 40-player (9) is assigned Normal. Story (220), Timewalking (33), and unknown IDs fail closed. World Raid (250) now has its own persistent, default-on control for supported raid/lair targets. Category mapping is independent of supported-context resolution and does not add encounters.

Existing Settings canvas registration, UICheckButtonTemplate, options entry points and initialization order are retained. Children use SetEnabled plus dimmed labels; their checked/saved values are preserved. UI changes route through SetAutoShowPreference, which refreshes controls and lifecycle without clearing dismissal or resetting visit consumption.

## Automated evidence

Run `python spec/run_tests.py` with Lupa (Lua 5.1). AutoShowPreferences uses production options/database/lifecycle/commands with the shared mocked fixture. It covers all mapped IDs, parent/child truth tables and independent categories, immediate closing, manual preview/combat, consumed visits, raid dismissal, retargeting, exit/re-entry, deferred visits, upgrades/mixed false values/new login, checkbox routing and debug output. Existing lifecycle, loot, selection, launcher and integration suites remain required. The old dungeon-to-raid test now supplies actual raid difficulty 14 rather than retaining dungeon difficulty 8.

Automated run on 2026-10-09: all nine suites, Lua 5.1 syntax and 14-file manifest validation passed (1,167 unique checks; 317 new preference checks), using the ignored local `.test-venv` with Lupa 2.8.

## Manual procedure (pending)

Record Retail version/build/interface, date, character, UI scale, installed UI addons and results here. Automated evidence does not establish live acceptance.

1. Open Spekifier via Addons settings, preview gear, `/spek options`/`o`, and minimap right-click. Confirm one shared page with Auto-show and six indented child controls, readable Mythic+ explanation, and independent minimap control. Disable Auto-show: children must be disabled and dimmed but retain their checked values. Verify layout at multiple UI scales.
2. Save mixed child values and an off parent. Reload and log in again; verify values and dependencies. Re-enable the parent and confirm mixed choices remain. Check an upgrade with existing enabled=false and child preferences missing; children should default on without overwriting the parent or minimap choice.
3. With supported living raid targets outside combat, exercise LFR, Normal, Heroic and Mythic separately: parent off suppresses all; parent on permits only the applicable checked child. Disable it while an automatic window is open and confirm immediate closing. Change unrelated children and confirm no effect. Dismiss, toggle preferences, and confirm no reopening until clearing/retargeting or the existing combat reset. Verify supported legacy difficulties where available and unknown/unsupported contexts fail closed.
4. Enter a supported ordinary Mythic dungeon before starting a key and a supported active-key dungeon. Verify Mythic+ gating, once-per-visit consumption, dismissal, keystone coalescing, and no reopening after toggling options on a consumed visit. With the preference initially off, enable during an eligible unshown visit and confirm a prompt; repeat in combat and confirm deferral until combat ends. Exit before combat ends and confirm cancellation. Verify Normal/Heroic entry remains excluded.
5. Exercise manual preview with parent/children off, including empty/unsupported contexts. Preference changes must preserve the manual preview, while combat still closes/prevents it. Verify supported-context resolution, confirmed selection, dungeon target independence and raid post-wipe behavior remain intact. Check `/spek debug` for the applicable preference and effective permission. Check for Lua errors.

## Live evidence

Pending; tracked in PLAN.md Manual Acceptance. No Phase 8 live checks have been performed in this environment.
