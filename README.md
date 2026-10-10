# Spekifier

**Compare loot across your specializations and choose your loot spec before the fight.**

Spekifier is a World of Warcraft Retail addon that puts your class's loot options side by side. Target a supported raid boss or enter a supported Mythic dungeon to see what each spekialization can receive, then click a column to set your loot spekialization.

The aim is simple: make it easier to choose which spek to collect gear for before rewards are decided, with fewer trips through the Adventure Guide and loot specialization menu.

## Features

- **Loot at a glance:** one column per specialization, with item icons, names, and native item and equipped-item comparison tooltips.
- **Focus on the differences:** items available to every spec appear once in a shared row above the columns.
- **Click to choose:** select a loot specialization directly from its column, with confirmation from the game.
- **Timely reminders:** automatic previews for supported raid targets and Mythic dungeon entry, with separate controls for each content type.
- **Make it fit your UI:** two built-in skins, a movable and resizable window, and a draggable minimap launcher.

## How to use it

1. **Open a comparison.** Outside combat, target a supported living raid boss inside its raid, or enter a supported dungeon on Mythic difficulty. The window opens automatically with default settings. You can also left-click the minimap button or use `/spek toggle`.
2. **Compare your options.** Each column shows loot eligible for that specialization. Hover items for tooltips and scroll each column independently. Items eligible for every spec appear under **Shared:**; scroll that strip horizontally when needed.
3. **Choose your loot spec.** Click a specialization's header, column background, or item row. Once the game confirms the change, the window closes and chat reports `Spekifier has set your loot specialization to [SPEC].`

Hovering only highlights a column. Shared-item icons show tooltips without choosing a spec. The **Selected** marker reflects your current game-confirmed loot specialization; an explicit choice changes your loot spec, not your active combat spec.

Close the window with **Escape** or its close button. It also closes when combat starts, and cannot be opened during combat. A dismissed raid prompt stays dismissed while the same boss remains continuously targeted; clearing/changing your target or ending combat permits a fresh prompt. Dungeon prompts appear once per visit, with another opportunity after leaving and re-entering. You can manually reopen the preview outside combat.

Manual previews work with automatic opening disabled. Outside a supported encounter or dungeon, the window explains why loot comparison is unavailable and disables selection.

## Supported content

Raid discovery uses the live Encounter Journal, including raids absent from the supplemental NPC catalog. A living attackable target must uniquely match a localized Journal encounter or creature name, or have a verified NPC hint. Ambiguous matches and inconsistent Journal identities leave comparison unavailable. The entries below have supplemental NPC coverage; other Journal raids can resolve dynamically.

| Content | Preview |
| --- | --- |
| **The Venomous Abyss** | All eight encounters, including individual units in multi-boss fights, at the current raid difficulty (including LFR). |
| **The Tidebound Grotto** | Nymrissa Wavecaller at World, Normal, Heroic, or flexible Mythic difficulty. |
| **The Voidspire** | All six encounters, using the current raid difficulty. |
| **Nerub'ar Palace** | The Silken Court, using the current raid difficulty. |
| **Supported Mythic / Mythic+ dungeons** | Dungeon-wide Mythic+ end-of-run loot comparison, available before a key starts. |

Dungeon support follows the Retail client's challenge-map catalog and requires a matching Adventure Guide entry. Normal and Heroic dungeon entry does not trigger a preview. Unsupported raid targets, outdoor enemies, and raid trash do not trigger one either.

The dungeon preview is labeled **Mythic+**, including when entering an ordinary Mythic dungeon. It compares the combined Mythic boss loot pool by specialization; it does not predict an exact reward item level for your key.

## Settings and appearance

Open **Escape → Options → Addons → Spekifier**, click the window's **Options** gear, right-click the minimap button, or type `/spek options`.

- **Auto-show:** enable or disable automatic previews. Its six choices—**Mythic+**, **LFR**, **Normal Raid**, **Heroic Raid**, **Mythic Raid**, and **World Raid**—control prompts independently and default to on. Mythic+ includes ordinary Mythic entry before a key starts. World Raid controls World difficulty in supported lairs; flexible Mythic uses Mythic Raid. Turning off Auto-show preserves these choices and keeps manual previews available.
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

Spekifier discovers raid instances and encounters from the Journal first, then uses supplemental NPC hints when a unique Journal name match is unavailable. Dungeon resolution requires a unique challenge-map match and Journal instance. Unsupported, ambiguous, or unavailable identities leave comparison unavailable.

Raid queries use the resolved encounter and actual raid difficulty. Dungeon queries combine the full dungeon's boss loot at Journal Mythic difficulty 23, excluding per-player bonus drops and deduplicating items. Queries preserve observable Adventure Guide selections and filters, defer while the Guide is open, cancel stale requests, and cache completed pools in memory. The shared row is derived only after every specialization's pool is complete; it does not alter provider data or diagnostic counts.

Loot selection rechecks context and combat state at click time. The game-confirmed loot specialization drives the selected marker, including external changes through Blizzard's menu. Spekifier does not save or restore a loot specialization. Preferences are stored in `SpekifierDB`; window visibility is reevaluated on login/reload.

### Source layout and ownership

The installable addon lives in `src/`; manifest entries remain relative to that folder. Tests and their API/acceptance records live in `spec/`, grouped by the source modules they cover. Shared fixtures remain in their existing suites; cross-module tests stay at the spec root.

WoW loads Lua files in the order listed in `src/Spekifier.toc`. Each file receives the addon name and the same private namespace through `...`; `src/Core/Init.lua` creates the shared `Spekifier` object. Files attach methods and private helpers during loading. `src/Core/Events.lua` initializes saved preferences on `ADDON_LOADED`, then creates the UI and starts context tracking on `PLAYER_LOGIN`. There is no separate entry-point script, runtime `require`, or third-party framework.

| Path | Responsibility |
| --- | --- |
| `src/Core/` | Addon object, saved preferences and migration, logging, and startup events. |
| `src/Modules/Context/RaidCatalog.lua` | Supported raid NPC-to-Journal identities, separated from lookup logic. |
| `src/Modules/Context/Resolver.lua` | Validated raid and dungeon identities; unsupported or ambiguous matches fail closed. |
| `src/Modules/Context/AutoShow.lua` | Raid targeting, dungeon visits, combat, preferences, and prompt eligibility. |
| `src/Modules/Loot/Model.lua` | Request validation, cache keys, defensive copies, and item metadata hydration. |
| `src/Modules/Loot/Provider.lua` | Request tokens, cache ownership, result publication, and bounded retries. |
| `src/Modules/Loot/Journal.lua` | Journal selection tracking and query transactions, including restoration after failures. |
| `src/Modules/Loot/Events.lua` | Item/Journal event coalescing and recovery after delayed data arrives. |
| `src/Modules/Loot/Selection.lua` | Click-time validation, game-confirmed loot specialization, and selection feedback. |
| `src/Modules/Loot/RequestIdentity.lua`, `Diagnostics.lua` | Shared request identity and diagnostic queries while the window is dismissed. |
| `src/Modules/Commands.lua` | Slash commands and diagnostic output. |
| `src/UI/Window/` | Frame construction and visibility (`Lifecycle`), provider subscription (`LootBinding`), saved dimensions and geometry (`Layout`), and screen fitting (`Fit`). |
| `src/UI/Loot/` | Spec columns, pooled item rows, shared-item strip, native tooltips, display-list derivation, and result rendering in separate files. |
| `src/UI/Skins/` | Skin registration and defaults (`Registry`), built-in colors (`Palettes`), and idempotent control styling (`Presentation`). |
| `src/UI/Options/` | Shared settings page and skin dropdown. |
| `src/UI/Minimap.lua` | Minimap launcher, positioning, and visibility. |
| `spec/` | Mirrors source ownership under `Modules/` and `UI/`, with integration/manifest suites at its root. Lua fixtures and regression suites, manifest startup integration, API evidence, and live acceptance procedures. |
| `src/Spekifier.toc` | Metadata and the explicit dependency order for all 31 runtime files. |

Dependencies flow from context resolution to loot requests to presentation. The provider owns request/cache state; the window owns its subscription token and rejects obsolete deliveries. Visibility and dismissal remain session-only state. Display-list derivation reads complete provider pools without mutating them. Skins only style controls; resizing belongs to window layout. Shared helpers live in the addon-private namespace (`Loot`, `LootUI`, and `PlayerLootRequest`) rather than adding global functions. The existing global `Spekifier` object remains available for diagnostics.

Keep single-file helpers local. When a helper must cross files, expose it through the private namespace and load its defining file before consumers. Method bodies may call methods defined later in the manifest because startup runs after all files load. Use Lua 5.1-compatible syntax and the WoW API environment; these files are not standalone Lua programs. Register every new runtime file in the manifest and update the runner's load-order contract.

To register another built-in skin, call `Spekifier:RegisterWindowSkin("stable-id", "Display label", palette)` from a runtime file loaded after `src/UI/Skins/Palettes.lua` and before `PLAYER_LOGIN`. Supply `bg`, `border`, `accent`, `selected`, `disabled`, and `text` as RGBA arrays, plus a client-compatible `font` path. Use `Palettes.lua` as the example and add the file to the manifest. The dropdown discovers registered skins automatically; saved preferences use their stable IDs. Unknown saved IDs fall back to Original.

The [Phase 10 refactor record](spec/StructureSources.md) maps previous filenames to their new owners; earlier phase records retain historical paths.

### Validation and packaging

The root `.luarc.json` configures Lua Language Server for Lua 5.1, matching the addon and test runtime. Reload the language server after changing its configuration.

From the repository root, install Lua 5.1, LuaFileSystem and Luacheck:

```sh
luarocks --lua-version=5.1 install luafilesystem
luarocks --lua-version=5.1 install luacheck 1.2.0-1
lua spec/run_tests.lua
luacheck src --config .luacheckrc
```

Use `lua5.1` instead of `lua` if your system names the Lua 5.1 executable that way. The runner requires Lua 5.1, executes all eleven mocked suites with isolated globals and library tables, compiles all addon/test/packaging Lua sources, and validates the manifest's exact runtime files and load order. Python and Lupa are no longer required. LuaFileSystem supplies directory discovery; assertions in the existing Lua suites perform the tests.

To validate and build a clean-install candidate, run the tests first, then the existing packager:

```sh
lua spec/run_tests.lua
lua scripts/package.lua dist/Spekifier-candidate.zip
```

For packaging alone, PowerShell 5.1 or later can build the ZIP without Python or Lupa, from any working directory:

```powershell
./scripts/package.ps1
./scripts/package.ps1 -OutputPath ./dist/Spekifier-custom.zip
```

On Windows hosts that disable script execution, invoke `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/package.ps1` to allow this invocation without changing the saved execution policy.

Linux developers can use the shell packager with standard coreutils and the `zip` and `unzip` commands installed:

```sh
sh scripts/package.sh
sh scripts/package.sh ./dist/Spekifier-custom.zip
```

Lua developers can use Lua 5.1 or later:

```sh
lua scripts/package.lua
lua scripts/package.lua ./dist/Spekifier-custom.zip
```

Lua's standard library has no ZIP API. This entry point delegates compression to `package.ps1` on Windows (PowerShell 5.1+) or `package.sh` on Linux (`sh`, coreutils, `zip`, and `unzip`). No additional Lua modules or Python are required. Keep the platform scripts alongside the Lua script. Invoke the scripts by path; they locate `src/` relative to themselves, including when launched from another directory.

The default output is `dist/Spekifier.zip` under the repository; explicit relative output paths are relative to the caller's working directory. Existing output files are replaced. Run the test runner before publishing.

All packaging routes put only the contents of `src/` inside a single `Spekifier/` folder, with `Spekifier.toc` directly inside it. Documentation, tests, and development tooling stay in the repository. New runtime assets should live in `src/` to be included automatically. The supplied PNG logos in `assets/` are development sources; their uncompressed 32-bit TGA copies in `src/Media/` preserve color and transparency for the game. After editing the PNGs, run `./scripts/convert-logos.ps1` before Linux packaging or committing the runtime textures; the PowerShell packager refreshes them automatically. The minimap uses the 32x32 source in a 24x24 inset within its 32x32 bordered button; the loot window displays the 64x64 logo at native size beside a left-aligned Spekifier title and encounter heading, with a 12-pixel gap above the loot controls. This draggable header replaces the centered template title bar in both skins. Addon metadata uses the same logo asset. The 128x128 source is reserved for larger artwork. The manifest suite loads every runtime file in release order and exercises startup, loot delivery, skin switching, hidden diagnostics, reopening, and selection.

Implementation is complete through Phase 14. Recorded live acceptance covers Phases 1–6.5; final integration, Phase 8/9/10/11 live checks, and release metadata finalization remain tracked in [PLAN.md](PLAN.md#manual-acceptance). Automated checks and the manifest's interface declaration do not establish live client compatibility.

Detailed evidence and procedures: [encounter support](spec/Modules/Context/EncounterSources.md), [loot data](spec/Modules/Loot/LootSources.md), [window and shared loot](spec/UI/Window/WindowSources.md), [selection](spec/Modules/Loot/SelectionSources.md), [options and minimap](spec/UI/Options/OptionsSources.md), [automatic-opening preferences](spec/Modules/Context/AutoShowPreferencesSources.md), [skins and resizing](spec/UI/Skins/SkinsSources.md), and [integration and release acceptance](spec/IntegrationSources.md).

## GitHub automation

[CI](.github/workflows/cicd.yml) runs on pushes to `main`, pushes of any tag, and opened/updated/reopened PRs against `main`.

The Testing job installs Lua 5.1, LuaFileSystem and Luacheck 1.2.0. It runs Luacheck against `src/` with the repository-owned [.luacheckrc](.luacheckrc), then runs `lua5.1 spec/run_tests.lua`. Both must pass before packaging or deployment. The lint configuration uses [Luacheck's standard Lua 5.1 globals](https://luacheck.readthedocs.io/en/stable/cli.html), explicitly lists the WoW APIs and addon globals used here, and retains default warning checks and the 120-character line limit. Colon-method receivers may be unused (`self = false`); other unused locals/arguments remain checked. Test mocks are checked through compilation and execution rather than addon-global lint rules. DBM code, configurations, annotations and actions are not fetched; LuaLS remains an optional local editor tool configured by `.luarc.json`.

After checks pass, PRs create ZIPs using BigWigs' packager with uploads disabled (`-d`). ZIP artifacts remain downloadable for 14 days. PRs originating in this repository receive a comment linking the artifact, updated on subsequent runs; fork PRs do not receive the comment. Deployment never runs for PR events.

After checks pass on a push to `main` or a tag, the Deployment job runs the packager with publishing credentials. Untagged builds can upload alpha packages to CurseForge/Wago; GitHub Releases and WoWInterface uploads require a tag. The workflow does not create tags or enforce semantic versions: create and push release tags yourself (for example, `v12.0.0`). The addon Version remains `12.0.0`; keep release metadata accurate. [.pkgmeta](.pkgmeta) moves `src/` contents into a single installable `Spekifier/` folder and excludes repository tooling. The packager also generates a changelog.

### Deployment setup

Create the Spekifier project/listing on each distribution service first. In GitHub, open **Settings ? Secrets and variables ? Actions ? New repository secret** and add:

| Destination | Repository secret | Where to obtain it |
| --- | --- | --- |
| CurseForge | `CF_API_TOKEN` | [CurseForge author API tokens](https://authors.curseforge.com/#/settings/api-tokens), using an account authorized to upload to the project. This is an author upload token, not a general CurseForge Core API key. |
| WoWInterface | `WOWI_API_TOKEN` | [WoWInterface API tokens](https://www.wowinterface.com/downloads/filecpl.php?action=apitokens), using the listing owner's account. |
| Wago | `WAGO_API_TOKEN` | [Wago Addons API keys](https://addons.wago.io/account/apikeys), using an account authorized for the project. |
| GitHub | None to add | GitHub automatically supplies `GITHUB_TOKEN`; the deployment job grants `contents: write` and passes it as `GITHUB_API_TOKEN`. No personal access token is required. |

The example's `CF_API_KEY` and `GITHUB_OAUTH` environment names are deprecated aliases; this workflow uses the packager's current names. See [packager source](https://github.com/BigWigsMods/packager/blob/master/release.sh) and [GitHub token permissions](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token).

Credentials alone are insufficient: add the actual project IDs to `src/Spekifier.toc` after registering the listings:

```toc
## X-Curse-Project-ID: <numeric CurseForge project ID>
## X-WoWI-ID: <numeric WoWInterface listing ID>
## X-Wago-ID: <Wago project ID>
```

These IDs are public metadata, not secrets. CurseForge's ID is on the project page, WoWInterface's is the number in its `info<ID>` listing URL, and Wago's is in its developer dashboard. Do not paste the placeholder lines into the manifest. Missing credentials or IDs cause destinations to be skipped. [Packager setup and credential documentation](https://github.com/BigWigsMods/packager)

All jobs use standard Ubuntu runners. This workflow uses Actions artifact storage. Standard runners are free for public repositories; private repositories consume included minutes, and storage/cache allowances still matter. Configure account-level Actions budgets to stop paid usage if needed; workflow YAML cannot enforce the owner's allowance. See [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

Local Lua tests, lint and YAML/package configuration checks do not prove GitHub execution or publication succeeded. Run the pending GitHub checks and complete live WoW acceptance/metadata finalization in [PLAN.md](PLAN.md#manual-acceptance) before publishing a release.
