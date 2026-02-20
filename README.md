# GONE Fishing Mods

A collection of mods for GONE Fishing. These mods are designed to prove quality of life and little visual enhancements like a custom game cursor.

> [!WARNING]
> **Software is provided "as is", without warranty of any kind.** Use these mods at your own risk. The author is not responsible for any save file corruption, multiplayer bans (the devs ban using ue4ss as of right now), or technical issues resulting from their use.

## 🛠 Installation

These mods require **UE4SS (Unreal Engine 4 Scripting System)** to function.

1.  Download the latest experimental version of [UE4SS from GitHub](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest).
2.  Install **UE4SS** into your game binaries folder (both the `ue4ss` folder and the `.dll` from the zip).
3.  Place the `GonFishMods` folder from this repository into the following directory:
    `GONEfishing.exe/GONEfishing/Binaries/Win64/ue4ss/Mods/`
4.  Configure your mods (enable/disable or tweak settings) by editing `GonFishMods/settings.lua`.

---

## 📦 Mod List

All features below are managed via the central `settings.lua` file. Including enabling and disabling mods.

### 🖱️ CustomFishingCursor
Provide a new game cursor in a form of a fishing rod to replace the default Windows cursor.

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

### 🎰 CrazierGambles
High-stakes gambling, makes the gambling outcomes take the extreme parts of the range more often.
*   **Increased volatility**: Increases the potential for massive wins and devastating losses (does not exceed the base game limits).
*   **Balanced odds**: While the results are more dramatic, the overall win-loss average remains the same as the base game.
