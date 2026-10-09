# Phase 5 window evidence and acceptance

The UI uses native ScrollFrame/Slider primitives instead of loading Adventure Guide frames or relying on its templates. Item tooltips use the provider's original link. API/source review on 2026-10-08:

- [Native scroll-frame API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua): `SetScrollChild` and `SetVerticalScroll`.
- [Native slider API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleSliderAPIDocumentation.lua): orientation, min/max, value steps, and texture-object thumb support.
- [Blizzard shared panel implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua): tooltip owner/anchor and full-text tooltip patterns.
- [Blizzard party pose UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GlueXML/WoWLabs/GluePartyPoseUI.lua): frame `IsMouseOver()` usage. Using one fixed column rectangle for hover continuity is Spekifier's implementation choice.
- [Blizzard World Map](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_WorldMap/Blizzard_WorldMap.lua): UI-scale/display-size event registration and responsive layout.
- [Blizzard tooltip implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua): tooltip anchoring and lifecycle.
- [Blizzard panel templates](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml): frame/title/close-button presentation. Spekifier creates its own vertical slider track/thumb and retains the existing BasicFrameTemplateWithInset close lifecycle.

## Mocked acceptance coverage

`spec/UI/Loot/Renderer.lua` runs the existing lifecycle fixture and adds 117 production UI checks. Two, three, and four specializations are checked at UI dimensions 1920?1080, 800?600, and 600?400. Native font rendering, clipping, cursor hit testing, and drag capture cannot be reproduced by these frame mocks. The hover test models a cursor remaining inside the column while child enter/leave events fire; it verifies that child events never clear the whole-column overlay.

The suite covers 60-row scroll extents, wheel/slider movement, stable headers, row pooling, scroll preservation, full item-link tooltip ownership/cleanup, selected/disabled appearances, left-click forwarding from header/background/rows, combat/right-click rejection, and title-only drag wiring. `spec/UI/Window/LootBinding.lua` additionally checks that real provider callbacks render and replace rows and clear them on cancellation/loading. Earlier stale request/visit checks continue to pass.

## Live acceptance procedure (pending)

1. On classes with two, three, and four specs, target a supported raid boss outside combat. Verify the localized boss and actual difficulty header. Enter ordinary Mythic and active Mythic+ dungeons; both must name the dungeon and use the one-line header `<Dungeon name>: Mythic+` for the end-of-run loot preview.
2. At several UI scales and display sizes, verify no overlapping columns, clipped list edges, or collision between header/status/close controls. Inspect long localized spec and item names; the full text must be available through header/item tooltips even when a row wraps or truncates visually.
3. Use a long loot pool. Wheel over the header, list background, item rows, and scrollbar; drag the thumb to both ends. Confirm the last row is reachable and headers remain fixed. Updates for the same context should preserve scroll position; a boss/difficulty/visit change should reset it and clear old content immediately.
4. Move slowly and rapidly across the header, blank space, rows, and scrollbar. The entire column highlight must remain steady until leaving its rectangle. Tooltips must use the correct original link and disappear on leave, scrolling, refresh/context loss, and closing.
5. Drag by the title; clicks/drags in the list must not move the window. Production Phase 5 clicks must not change loot specialization while selection is unavailable. Once Phase 6 supplies the confirmed setter, repeat header/background/row clicks and verify each changes the intended spec once; scrollbar gestures must only scroll.
6. Exercise delayed data, empty loot, unsupported difficulty, and a timeout. Confirm explicit readable messages, no stale rows/links, and no partial pool presented as complete. Repeat context switches, close/reopen, combat, and dungeon exit while loading.

Do not claim live visual/input acceptance until the above checks run in Retail. No live client was available during implementation.

## Follow-up live feedback

The larger initial layout uses at least 1080?720 UI units and 420-unit list viewports with 64-unit item rows. The window now uses FULLSCREEN_DIALOG strata at level 100, below native TOOLTIP strata for both primary and comparison tooltips. No shared tooltip frame strata/level is overridden. Tooltip behavior with the user's equipped-item comparison addon requires live revalidation. Completed loot columns now explicitly clear/hide their status text; the previous Lua `and/or` expression incorrectly fell back to loading text for ready results. New regression checks cover ready-message cleanup, larger window dimensions/strata, and native tooltip processing/visibility.

The readability/tooltip follow-up uses 56-pixel spec icons, 22-point spec names, 40-pixel loot icons, and 18-point loot names. Tests verify tooltip parent/alpha reset, comparison-enabled hyperlink processing, and preservation during equivalent result refreshes. The native tooltip processing follows [EncounterJournal_SetTooltipWithCompare](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua) and [TooltipDataHandler](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua); the original item link is retained. Live acceptance of the primary tooltip and installed comparison addon's display remains pending.

## Phase 5.5 shared-loot acceptance

`spec/UI/Loot/SharedRow.lua` adds 166 focused checks and reuses the real provider/window fixture. It exercises universal, pairwise, unique, duplicate, no-shared, all-shared, missing-spec, partial, failed, and delayed pools for two/three/four specs. It also checks source/cache preservation, stable ID ordering, horizontal range/scrolling, frame reuse, tooltip ownership/comparisons, absence of shared spec-click handlers, empty-column messages, and context/difficulty/combat/close cleanup. The combined existing and new suites contain 673 unique checks.

The shared strip uses the native ScrollFrame horizontal scroll setter with a horizontal Slider. Horizontal scroll range and child access are documented in [Blizzard's exported ScrollFrame API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua). Item-link comparison processing is the same verified native handler used by column rows above. The layout grows from 720 to 784 units while shared loot is visible and fits against actual UIParent dimensions. Column viewports remain 420 units tall.

Additional live acceptance (pending):

1. On a three-spec class, compare original Adventure Guide pools with the preview. Verify an item in all three appears once beneath **Shared:** and nowhere in the columns; an item in exactly two remains in both columns. Repeat on two- and four-spec classes. Debug counts must still describe full eligible pools.
2. Verify the icon-only row directly below both raid encounter/difficulty and dungeon Mythic+ headers. Inspect no-shared and all-shared pools: no blank strip space without shared loot, and readable **All eligible loot is shared above.** messages when every item moves above.
3. At multiple UI scales/display sizes, check header/strip/column/status spacing and icon clipping. Overflow must scroll horizontally by wheel and slider to expose the final icon, while every column still scrolls independently with a fixed header. Icons must not draw over the label or outside the viewport.
4. Hover shared icons with equipped comparisons enabled (and the user's comparison addon, if installed). Verify correct original links, native tooltip layering, leave/scroll cleanup, and no spec-column highlight or spec-selection action from clicks. Dragging overflow controls must not drag the window or select a spec.
5. Refresh the same context and confirm stable shared ordering, reusable icons, and retained horizontal offset. Switch boss/difficulty/dungeon visit, close/reopen, enter combat, or exit while data is delayed; no old shared icon or tooltip may remain. A failed/incomplete spec must prevent shared classification; late completion must move universal loot into the strip.

Both Original and Elles must style the shared label, icon textures, and overflow slider/track/thumb in Phase 9. `window.sharedLoot` exposes these elements and its pooled icons for the future skin module; neither skin exists in this phase. This dependency remains unchecked in PLAN.md.
