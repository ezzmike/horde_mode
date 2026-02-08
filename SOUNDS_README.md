# Adding Music and Sounds (Free & Open Source)

The game is set up to play **music** (lobby, arena) and **sound effects** (hit, weapons, wave start/complete, game over, upgrade). To enable them, add Roblox asset IDs in **`ReplicatedStorage/Modules/SoundConfig.lua`**.

## How Roblox audio works

- Sounds must be **uploaded to Roblox** (Create → Audio in the [Creator Dashboard](https://create.roblox.com)) or use existing catalog assets.
- You get an **asset ID** (e.g. `123456789`). In code we use `rbxassetid://123456789` or paste the number (SoundConfig will add the prefix).
- Limits: ID-verified creators get more free uploads per month; see [Roblox audio docs](https://create.roblox.com/docs/sound/assets).

## Free / open source sources

Use these to download **free, legal** music and SFX, then upload to Roblox and paste the new IDs into `SoundConfig.lua`.

| Source | License | Best for |
|--------|--------|----------|
| **[Kenney.nl](https://kenney.nl/assets)** | CC0 (public domain) | Game packs: "Game Sounds", "Impact Sounds", "Music Jingle" |
| **[itch.io game assets](https://itch.io/game-assets/free/tag-sound)** | Filter by CC0 / CC-BY | SFX and short music |
| **[Freesound.org](https://freesound.org)** | Per-clip (CC0, CC-BY, etc.) | Single effects; check each license |
| **[OpenGameArt.org](https://opengameart.org)** | Various CC | Music and SFX |
| **[Pixabay](https://pixabay.com/sound-effects/)** | Free for commercial use | Music and SFX |
| **Roblox Toolbox** | Varies | In Studio: View → Toolbox → Audio |

## What to fill in (SoundConfig.lua)

- **Music.Lobby** – Chill / menu track (looped in lobby).
- **Music.Arena** – Action / tension track (looped during waves).
- **Sfx.Hit** – When a weapon hits an enemy.
- **Sfx.WeaponMelee** – Melee swing (e.g. knife).
- **Sfx.WeaponShoot** – Gunshot / rifle.
- **Sfx.WeaponExplosion** – RPG / C4 / TNT.
- **Sfx.WaveStart** – New wave starting.
- **Sfx.WaveComplete** – Wave cleared.
- **Sfx.GameOver** – Match ended.
- **Sfx.Upgrade** – Upgrade purchased.

Leave any value as `""` to leave that sound silent. The game runs fine with no IDs set.

## Example (after uploading to Roblox)

```lua
SoundConfig.Music = {
    Lobby = "rbxassetid://123456789",
    Arena = "rbxassetid://987654321",
}
SoundConfig.Sfx = {
    Hit = "rbxassetid://111222333",
    -- ...
}
```

Use either the full `rbxassetid://...` string or just the number (e.g. `123456789`).
