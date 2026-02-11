# GONE Fishing Mods

A collection of mods for GONE Fishing. These mods are designed to adjust gameplay pacing and provide additional utility during fishing sessions.

> [!WARNING]
> **Software is provided "as is", without warranty of any kind.** Use these mods at your own risk. The author is not responsible for any save file corruption, multiplayer bans, or technical issues resulting from their use.

## 🛠 Installation

These mods require **UE4SS (Unreal Engine 4 Scripting System)** to function.

1.  Download the latest version of [UE4SS from GitHub](https://github.com).
2.  Install **UE4SS** into your game binaries folder.
3.  Place the individual mod folders from this repository into the following directory:
    `GONEfishing.exe/GONEfishing/Binaries/Win64/ue4ss/Mods/`

---

## 📦 Mod List

### 🍺 FasterBeerDrinking
Decreases the time required to finish the drinking animation, allowing for faster consumption.

### ⚡ ForceEnablePerks
Forces specific perks to remain active during multiplayer sessions:
*   **Sticky Hook**: Always active.
*   **Fish Whisperer**: Always active.

### 🎣 LuckierFishBite
Adds a notification system for active bites and adjusts catch RNG.
*   **Reporting**: Displays the species of the fish currently on the hook.
*   **Luck Logic**: Automatically rerolls the fish encounter **N** times and selects the best result.
*   **Configuration**: Edit `settings.lua` within the mod folder. Set `LuckFactor` to `0` to disable the reroll mechanic while keeping the fish reporting active.
