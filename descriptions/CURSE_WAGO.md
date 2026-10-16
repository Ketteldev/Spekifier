# Spekifier

**Compare loot across your specializations. Choose your loot spec before the pull.**

Looking for a weapon for your off-spec or a trinket for your main? Spekifier puts your class's eligible loot side by side, so you can see the differences and choose which specialization to collect gear for.

Enter a supported raid and choose an encounter, or enter a supported Mythic dungeon outside combat, compare the loot, and click a specialization's column to set your loot spec.

## Features

- **Side-by-side comparison:** one loot column per specialization, with item icons, names, and independently scrolling lists.
- **Less clutter:** items eligible for every spec appear once in a shared row.
- **Choose with a click:** click a spec header, item row, or column background. The window closes after the game confirms your choice.
- **Item tooltips:** hover to inspect loot and compare it with equipped gear.
- **Reminders you control:** separate automatic-opening options for Mythic+, LFR, Normal, Heroic, Mythic, and World Raid content.
- **Fit your UI:** choose the Original or Elles skin, move and resize the window, and show or hide the draggable minimap button.

## Getting started

1. Outside combat, enter a supported raid and choose a boss from the Encounter dropdown beside Shared loot, or enter a supported dungeon on Mythic difficulty.
2. Compare each specialization's loot. Hover items for tooltips; shared items appear above the spec columns.
3. Click the column for the loot specialization you want. Spekifier confirms the change in chat.

Your choice sets your **loot specialization**; your active combat specialization stays the same.

Left-click the minimap button or use `/spek toggle` to reopen the preview. Right-click the button or use `/spek options` for settings. Manual previews remain available when automatic opening is disabled.

## Raids and Mythic+

**Raids:** choose an encounter from the dropdown on the right of the Shared row to preview its loot at your actual raid difficulty. Encounters come from the game's Adventure Guide without reading restricted target identity. The first listed encounter is selected initially; choose the boss you are about to fight.

**Dungeons:** entering a supported Mythic or Mythic+ dungeon previews the dungeon-wide Mythic+ loot comparison, even before a key starts. Dungeon support follows the client's challenge-map catalog and available Adventure Guide entries.

The dungeon preview combines Mythic boss loot by specialization. It shows eligible item identities rather than predicting reward item levels for a particular key.

The window closes when combat begins. The raid preview opens automatically once per visit, on entry. Boss kills, wipes and other fights do not reopen it; use the minimap button or /spek toggle to reopen it manually. Initial entry may be deferred until combat ends. The chosen encounter does not advance automatically. Dungeon reminders appear once per visit; leaving and re-entering permits another reminder. Normal and Heroic dungeon entry and outdoor areas do not trigger automatic previews. Raid target changes do not change your selected encounter or reopen a dismissed preview.

## Useful commands

- `/spek toggle` - open or close the preview outside combat.
- `/spek options` - open settings.
- `/spek minimap` - show or hide the minimap button.
- `/spek help` - show all commands.

You can also use `/spekifier` in place of `/spek`.

## Help and feedback

No automatic preview? Check Auto-show and its content options, make sure you are outside combat, or try `/spek toggle`. A dismissed prompt stays dismissed through raid target changes or for the current dungeon visit.

Loot still loading? Close the Adventure Guide and allow time for item data to arrive.

[Report a bug or request a feature](https://github.com/Ketteldev/Spekifier/issues). Include your WoW version/build, class, boss or dungeon, difficulty, steps to reproduce, and relevant `/spek debug` output.

[Source and full documentation](https://github.com/Ketteldev/Spekifier)
