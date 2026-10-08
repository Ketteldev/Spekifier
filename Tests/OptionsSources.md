# Phase 6.5 options and launcher acceptance

Implementation targets the manifest's Retail 12.x client. Runtime additions are `UI/Options.lua` and `UI/Minimap.lua`, before the preview window in the manifest. There are no bundled launcher dependencies.

## API evidence

Verified on 2026-10-08 against Blizzard's exported live UI source:

- [Settings implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua): `RegisterCanvasLayoutCategory(frame, name)`, `RegisterAddOnCategory(category)`, and `OpenToCategory(categoryID)` provide registration and native routing. The addon retains one category and opens its `GetID()` through one method.
- [Settings utility API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SettingsUtilDocumentation.lua): the native opener is marked `HasRestrictions`. This documentation does not establish whether addon calls succeed in every combat situation. Spekifier calls the native opener without manipulating protected panels, catches thrown errors and offers outside-combat feedback. Native silent refusal remains possible and requires live validation.

The options panel uses a standard `UICheckButtonTemplate` with a shared immediate preference setter. Opening options never evaluates encounters, opens the preview, consumes a dungeon prompt, clears dismissal, or writes loot specialization. Launcher left-click delegates to the existing manual toggle. Drag coordinates are converted using the minimap's effective scale and stored as an angle, allowing reload at a different scale or map size. Round, square and mixed corner/side shapes are supported; unknown shapes fall back to round. Drag updates stop on release or hide.

## Automated evidence

Run `lua Tests/Options.lua` from the repository root with Lua 5.1. This also runs the 267-check lifecycle suite. The 63 focused checks exercise production registration/routing, both slash roots and aliases, gear and launcher actions/tooltips, default and migrated preferences, visible-checkbox synchronization, immediate hide/restore, messages, saved drag position, scale conversion, square/unknown shapes, invalid position recovery, repeat initialization and registration retry, Settings errors/unavailability, combat/manual behavior, dungeon prompt consumption, raid dismissal and preservation of confirmed selection. Manifest ordering is checked. All existing provider, presentation, shared-loot and selection suites must also pass.

Mocks verify calls and state, not Blizzard panel rendering, texture availability, native restrictions, physical hit areas or taint. No in-game result has been claimed for Phase 6.5.

## Required live procedure (pending)

Record actual Retail version/build, UI scale, other minimap addons and results before checking the live PLAN items.

1. With fresh saved variables, login outside supported content. Confirm the launcher is visible and Spekifier appears in Escape -> Options -> Addons. Open that page from `/spek options`, `/spek o`, both aliases under `/spekifier`, minimap right-click and the preview gear. Confirm the same page and one category after repeated initialization/reload.
2. Open `/spek t` outdoors and in unsupported content. Confirm the gear is visible, clearly identifiable and has the Options tooltip. Test its click separately from dragging the title, clicking close and clicking loot columns. Repeat at UI scales 0.64, 0.85 and 1.0, plus your usual scale; inspect clipping and overlap with long headers.
3. Check Hide minimap button. Verify immediate disappearance, then use `/spek minimap` and `/spek mm` with the page still visible. Each command must flip the checkbox immediately and print shown/hidden status. Repeat with `/spekifier`. Restore via checkbox and commands. Reload/login with each value and confirm persistence. Keep auto-show disabled for one pass to verify independent access.
4. Drag the launcher to every quadrant; confirm it remains around the edge. Reload/login and confirm the saved position. Repeat with a changed UI scale and square minimap if available. Verify launcher tooltip, placement, icon readability and lack of overlap with other minimap controls. Hide while dragging and confirm updates stop.
5. Left-click outdoors, with a supported raid boss, and on Mythic dungeon entry. Confirm manual opening/closing, unsupported empty state, selection, raid dismissal and consumed-visit behavior remain consistent. Options access and launcher visibility changes must never reset dismissal or select a spec.
6. In combat, left-click must not open preview. Use options commands and launcher right-click during combat; record whether the native Settings path opens or refuses and whether useful game/addon feedback appears. Confirm no Lua errors, blocked-action or taint errors, unexpected preview opening or deferred opening after combat. After combat all options routes must work.

Live acceptance remains pending until these checks are performed in WoW.
