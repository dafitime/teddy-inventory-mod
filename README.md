# CraftingContents

A [Teddy's Haven](https://store.steampowered.com/) mod that shows the item + amount currently placed in a crafting/converter station (furnace, brewer, jammer, etc.) and what it'll turn into when you hover it. No more guessing what's cooking.

Built with [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS), an open-source Unreal Engine 4/5 modding framework. This repo bundles UE4SS itself, so no separate download is needed — clone or download this repo and you have everything required.

## Install

1. Close the game if it's running.
2. Copy `dwmapi.dll` and the `ue4ss/` folder from this repo directly into:
   ```
   <your game folder>\TeddysHaven\Binaries\Win64\
   ```
   When asked to merge/overwrite folders, say yes.
3. Launch the game normally. Hover any crafting/converter station — the tooltip will now show what's placed and what it'll turn into.

## Uninstall

Delete `dwmapi.dll` and the `ue4ss` folder from `TeddysHaven\Binaries\Win64\` to remove everything (UE4SS included), or just delete `ue4ss\Mods\CraftingContents\` to remove only this mod and keep UE4SS.

## Notes

- Fan-made, not affiliated with Teddy Bear Games.
- Reads the game's own Blueprint data at runtime — no game files are modified on disk.
- One known quirk: the BuzzBrew (honey) station's tooltip is intentionally left untouched by this mod and behaves exactly as vanilla, since it has unusual popup behavior that couldn't be safely worked around.
- Item display names are learned by browsing Storage/placing items in-game, so freshly-placed items may show their internal name (e.g. "Silver") until their name has been "seen" once via Storage.

## How it works (for other modders)

See [`ue4ss/Mods/CraftingContents/Scripts/main.lua`](ue4ss/Mods/CraftingContents/Scripts/main.lua) — the file header documents the approach: hooking each converter's `HandlePlaceItem`/`HandleReloadSave` to capture the placed item's internal tag, resolving its real display name by passively observing Storage UI rows, and reading each converter's `PlacedItemDataTableEntry_Transitions` map to predict the output.
