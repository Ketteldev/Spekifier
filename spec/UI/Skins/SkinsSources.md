# Phase 9 appearance specification


Current runner (2026-10-10): use `lua spec/run_tests.lua` with Lua 5.1 and LuaFileSystem; package with `lua scripts/package.lua <output.zip>`. Historical Python/Lupa commands below preserve earlier validation evidence. See [current validation instructions](../../../README.md#validation-and-packaging).
Design recorded before implementation (2026-10-09). References: https://ellesmereui.com/presets and https://github.com/EllesmereGaming/EllesmereUI/blob/main/EllesmereUI.lua and https://github.com/tukui-org/ElvUI . Built-in treatment; no external media dependency.

Original retains Blizzard template chrome, Friz Quadrata typography, gold hover/scroll accents and green confirmation. Elles uses opaque charcoal (#11151c), slate one-unit borders (#394354), pale text (#e0e6ef), cyan accents (#45bfd9), and teal confirmation (#184a43). Disabled columns have muted backgrounds and explicit labels. Quality colors remain untouched. Preserve 20-unit margins, 8-unit gutters, 64-unit rows, 56-unit spec icons and 40-unit loot icons. Names remain outside scrolling content. Grip has its own 24-unit corner. Client fonts retain localized glyph support.

## Manual procedure (pending)

Record date, build, spec count, UI scale, UI addons and results here. Geometry tests are not screenshots or live evidence.

1. Login with neither UI addon, each alone, both, installed but disabled addons, and an addon loaded after Spekifier. Test fresh/upgrade settings, defaults and saved choices after addon changes and reload/login.
2. Reach options through every entry point. Disable Auto-show; switch both skins with open/hidden previews and during combat. Confirm immediate updates, no hidden popup/dismissal reset, and working Phase 8 controls.
3. Capture WoW comparison screenshots: raid/dungeon, shared overflow, loading, empty, unsupported, failed, hover, disabled and selected. Review every surface for readability and leftovers after repeated switching.
4. Test 2/3/4 specs, long localized names and 60+ rows at multiple scales/resolutions. Resize to minimum/maximum; check bounds, margins, final row, fixed headers, overflow, tooltips, dragging and click surfaces. Reload/login and reopen; confirm size persistence and switching preserves position, loot, scroll and selection.

## Evidence

Live checks and comparison screenshots pending; this environment cannot run WoW.

## API evidence and automated validation

Verified against Blizzard exports on 2026-10-09: [frame resizing](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua) supplies SetResizable, SetResizeBounds and StartSizing; [addon loading](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua) returns loadedOrLoading and loaded separately (the implementation requires loaded); [dropdown implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua) supplies registry-populated radio choices. Default resolution happens on PLAYER_LOGIN rather than Spekifier ADDON_LOADED to allow later startup addons to finish. Load-on-demand addons first loaded after login do not rewrite the now-persisted choice.

`spec/UI/Skins/Presentation.lua` passes 355 focused checks. The complete runner passes 1,522 unique checks across ten Lua 5.1 suites, syntax checks and the 15-file manifest. Run with `.test-venv/Scripts/python.exe spec/run_tests.py` (Lupa 2.8). Existing fixture suites repeat lifecycle checks; repeated checks are excluded from this total. Geometry tests exercise 2/3/4 specs, three screen sizes, both palettes and long lists; mocks cannot measure actual font glyph widths, texture appearance, cursor resizing or frame propagation in WoW.

Window sizes are normalized at creation and saved account-wide. Resizing updates row widths, column heights, viewport/ranges, shared width/overflow and clamps offsets. Skin application does not render data or resize: it only reuses presentation objects and invalidates column appearance caches. Original restores Blizzard regions; Elles hides outer/inset chrome and uses owned backgrounds/edges. Late spec catalogs retain saved dimensions while enforcing the new minimum layout.

Implementation acceptance is recorded in PLAN.md Phase 9. The consolidated Manual Acceptance section is authoritative for live status; screenshot and live interaction checks remain unchecked.


Title-area correction (2026-10-12): Original restores the Blizzard TitleBg fill inside the retained outline; Elles hides it. The centered template title and decorative streaks stay hidden. Repeated switching is covered by the 435 focused skin checks; all eleven native Lua 5.1 suites, syntax/manifest validation and Luacheck 1.2.0 passed (zero warnings/errors). Verify the fill and unchanged Elles appearance through the manual procedure above; live verification remains pending in PLAN.md.

Resize triangle correction (2026-10-12): Both skins use only native grey Blizzard resize art and the existing grip interaction; the accent overlays are no longer created. Repeated switching verifies native art visibility; 455 focused skin checks, all eleven native Lua 5.1 suites, syntax/manifest validation and Luacheck 1.2.0 passed with zero warnings/errors. Live appearance and resizing verification remain pending in PLAN.md.
