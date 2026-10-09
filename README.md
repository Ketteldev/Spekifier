# Spekifier

**Compare loot across your specializations and choose your loot spec before the fight.**

Spekifier is a World of Warcraft Retail addon that puts your class's loot options side by side. Target a supported raid boss or enter a supported Mythic dungeon to see what each specialization can receive, then click a column to set your loot specialization.

The aim is simple: make it easier to choose which spec to collect gear for before rewards are decided, with fewer trips through the Adventure Guide and loot specialization menu.

## Features

- **Loot at a glance:** one column per specialization, with item icons, names, and native item and equipped-item comparison tooltips.
- **Focus on the differences:** items available to every spec appear once in a shared row above the columns.
- **Click to choose:** select a loot specialization directly from its column, with confirmation from the game.
- **Timely reminders:** automatic previews for supported raid targets and Mythic dungeon entry, with separate controls for each content type.
- **Make it fit your UI:** two built-in skins, a movable and resizable window, and a draggable minimap launcher.

## Installation

1. Place the `Spekifier` folder in your Retail installation's `Interface/AddOns` directory:

   ```text
   World of Warcraft/_retail_/Interface/AddOns/Spekifier/
   ```

2. Check that `Spekifier.toc` is directly inside that folder, rather than inside another nested folder.
3. Start or restart WoW and enable **Spekifier** in the character-selection AddOns list.

Spekifier is designed for **Retail WoW**. Neither ElvUI nor EllesmereUI is required.

## How to use it

1. **Open a comparison.** Outside combat, target a supported living raid boss inside its raid, or enter a supported dungeon on Mythic difficulty. The window opens automatically with default settings. You can also left-click the minimap button or use `/spek toggle`.
2. **Compare your options.** Each column shows loot eligible for that specialization. Hover items for tooltips and scroll each column independently. Items eligible for every spec appear under **Shared:**; scroll that strip horizontally when needed.
3. **Choose your loot spec.** Click a specialization's header, column background, or item row. Once the game confirms the change, the window closes and chat reports `Spekifier has set your loot specialization to [SPEC].`

Hovering only highlights a column. Shared-item icons show tooltips without choosing a spec. The **Selected** marker reflects your current game-confirmed loot specialization; an explicit choice changes your loot spec, not your active combat spec.

Close the window with **Escape** or its close button. It also closes when combat starts, and cannot be opened during combat. A dismissed raid prompt stays dismissed while the same boss remains continuously targeted; clearing/changing your target or ending combat permits a fresh prompt. Dungeon prompts appear once per visit, with another opportunity after leaving and re-entering. You can manually reopen the preview outside combat.

Manual previews work with automatic opening disabled. Outside a supported encounter or dungeon, the window explains why loot comparison is unavailable and disables selection.

## Supported content

| Content | Preview |
| --- | --- |
| **The Voidspire** | All six encounters, using the current raid difficulty. |
| **Nerub'ar Palace** | The Silken Court, using the current raid difficulty. |
| **Supported Mythic / Mythic+ dungeons** | Dungeon-wide Mythic+ end-of-run loot comparison, available before a key starts. |

Dungeon support follows the Retail client's challenge-map catalog and requires a matching Adventure Guide entry. Normal and Heroic dungeon entry does not trigger a preview. Unsupported raid targets, outdoor enemies, and raid trash do not trigger one either.

The dungeon preview is labeled **Mythic+**, including when entering an ordinary Mythic dungeon. It compares the combined Mythic boss loot pool by specialization; it does not predict an exact reward item level for your key.

## Settings and appearance

Open **Escape → Options → Addons → Spekifier**, click the window's **Options** gear, right-click the minimap button, or type `/spek options`.

- **Auto-show:** enable or disable automatic previews. Its five choices—**Mythic+**, **LFR**, **Normal Raid**, **Heroic Raid**, and **Mythic Raid**—control prompts independently and default to on. Mythic+ includes ordinary Mythic entry before a key starts. Turning off Auto-show preserves these choices and keeps manual previews available.
- **Hide minimap button:** hide or restore the launcher. Drag the button around the minimap to reposition it.
- **Window skin:** choose **Original** for Blizzard-style framing and gold accents, or **Elles** for dark panels, subtle borders, and cyan accents. Both skins are built in.

Without a saved skin choice, Spekifier defaults to Elles when EllesmereUI or ElvUI is loaded at startup, and Original otherwise. Disabled or unloaded addons do not affect the default. Your saved choice takes precedence on later logins.

Drag the title bar to move the window. Drag the **diagonal bottom-right resize grip** to change its width and height. Your chosen size survives closing, reopening, reloads, logins, and skin changes. Switching skins applies immediately and preserves the current loot, position, scroll offsets, and selection. Settings, including appearance and size, are saved account-wide.

## Commands

All commands also work with `/spekifier` in place of `/spek`.

| Command | Action |
| --- | --- |
| `/spek` or `/spek help` | Show command help. |
| `/spek toggle` or `/spek t` | Open or close the manual preview outside combat. |
| `/spek options` or `/spek o` | Open addon settings. |
| `/spek minimap` or `/spek mm` | Show or hide the minimap button. |
| `/spek debug` | Print current context, loot data, and loot specialization diagnostics. |
| `/spek debugmode` or `/spek dm` | Toggle persistent diagnostic logging. |

## Troubleshooting

**The window did not open automatically.** Check Auto-show and the relevant content option, ensure you are outside combat, and check the supported content above. A dismissed raid target or an already-shown dungeon visit will not keep prompting. Use `/spek toggle` to reopen it manually.

**Loot is loading or unavailable.** Close the Adventure Guide to let pending queries proceed, then allow time for the game to deliver item data. The window displays loading and failure messages instead of presenting partial loot lists as complete. `/spek debug` reports the current context and per-spec data state, even with the preview closed.

**The minimap button is missing.** Use `/spek minimap` or clear **Hide minimap button** in settings.

When reporting a problem, include your WoW version/build, encounter or dungeon, difficulty, character class, steps to reproduce, and relevant `/spek debug` output. Enable `/spek debugmode` for additional event logging; run it again to turn logging off.

## Technical details

### Data and lifecycle

Spekifier resolves supported raid targets through NPC and Journal identities. Dungeon resolution requires a unique challenge-map match and Journal instance. Unsupported, ambiguous, or unavailable identities leave comparison unavailable.

Raid queries use the resolved encounter and actual raid difficulty. Dungeon queries combine the full dungeon's boss loot at Journal Mythic difficulty 23, excluding per-player bonus drops and deduplicating items. Queries preserve observable Adventure Guide selections and filters, defer while the Guide is open, cancel stale requests, and cache completed pools in memory. The shared row is derived only after every specialization's pool is complete; it does not alter provider data or diagnostic counts.

Loot selection rechecks context and combat state at click time. The game-confirmed loot specialization drives the selected marker, including external changes through Blizzard's menu. Spekifier does not save or restore a loot specialization. Preferences are stored in `SpekifierDB`; window visibility is reevaluated on login/reload.

### Source layout

| Path | Responsibility |
| --- | --- |
| `Core/` | Initialization, saved settings, diagnostics, and event handling. |
| `Modules/` | Encounter resolution, loot queries, confirmed selection, automatic opening, and commands. |
| `UI/` | Window, specialization columns, skins, settings, and minimap launcher. |
| `Spekifier.toc` | Addon metadata and runtime dependency order. |
| `Spekifier.lua` | Final entry point. |
| `Tests/` | Mocked Lua suites, API evidence, and live acceptance procedures. |

To register another built-in skin, call `Spekifier:RegisterWindowSkin("stable-id", "Display label", palette)` from a runtime file loaded after `UI/Skins.lua` and before `PLAYER_LOGIN`. Supply `bg`, `border`, `accent`, `selected`, `disabled`, and `text` as RGBA arrays, plus a client-compatible `font` path. Use the existing palettes as examples and register the new file in the manifest. The dropdown discovers registered skins automatically; saved preferences use their stable IDs. Unknown saved skin IDs fall back to Original.

### Validation and packaging

From the repository root, with Python and `lupa` installed:

```sh
python Tests/run_tests.py
```

The runner executes all ten mocked Lua 5.1 suites, compiles Lua sources, and validates the manifest's runtime files and load order. To validate and build a clean-install candidate:

```sh
python Tests/run_tests.py --package Spekifier-candidate.zip
```

The archive contains a single `Spekifier` folder with runtime files and documentation, excluding development scripts and saved variables.

Implementation is complete through Phase 9. Recorded live acceptance covers Phases 1–6.5; final integration, Phase 8/9 live checks, and release metadata finalization remain tracked in [PLAN.md](PLAN.md#manual-acceptance). Automated checks and the manifest's interface declaration do not establish live client compatibility.

Detailed evidence and procedures: [encounter support](Tests/EncounterSources.md), [loot data](Tests/LootSources.md), [window and shared loot](Tests/WindowSources.md), [selection](Tests/SelectionSources.md), [options and minimap](Tests/OptionsSources.md), [automatic-opening preferences](Tests/AutoShowPreferencesSources.md), [skins and resizing](Tests/SkinsSources.md), and [integration and release acceptance](Tests/IntegrationSources.md).
