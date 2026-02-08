--[[
    SoundConfig - Background music and SFX.
    Use asset IDs that work with the legacy Sound object (Toolbox > Creator Store > Audio;
    insert as Sound in Studio to verify). If you get "Asset type does not match", the ID
    may be for the new Audio system - pick a different track from Creator Store Audio.
]]

local SoundConfig = {}

-- Music (looped). ID from official Roblox "Add 2D audio" tutorial (upbeat track).
SoundConfig.Music = {
    Lobby = "1841461968",
    Arena = "1841461968",
}
SoundConfig.MusicFallbacks = {
    Lobby = { "9113723699", "3422389728" },
    Arena = { "9113723699", "3422389728" },
}

-- Use IDs that work with legacy Sound (Creator Store > Audio, insert as Sound to verify).
-- If you get "Asset type does not match", the ID may be for the new Audio system; client will try AudioPlayer for those.
SoundConfig.Sfx = {
    Hit = "12222216",
    WeaponMelee = "12222216",
    WeaponShoot = "12222216",
    WeaponExplosion = "12222216",
    WeaponPistol = "12222216",
    WeaponShotgun = "12222216",
    WeaponM16 = "12222216",
    WeaponTurretMG = "12222216",
    WeaponRPG = "12222216",
    WeaponC4 = "12222216",
    WeaponTNT = "12222216",
    WaveStart = "12222216",
    WaveComplete = "12222216",
    GameOver = "815520830",
    Upgrade = "12222216",
}
SoundConfig.SfxFallbacks = {
    WeaponShoot = "12222216",
    WeaponPistol = "12222216",
    WeaponShotgun = "12222216",
    WeaponM16 = "12222216",
    WeaponTurretMG = "12222216",
    WaveStart = "12222216",
    Upgrade = "12222216",
}

SoundConfig.DefaultMusicVolume = 0.55
SoundConfig.DefaultSfxVolume = 0.7

local function toAssetId(id)
    if type(id) ~= "string" or id == "" then return nil end
    return id:match("^rbxassetid://") and id or ("rbxassetid://" .. id)
end

function SoundConfig.getMusicId(key)
    return toAssetId(SoundConfig.Music and SoundConfig.Music[key])
end

function SoundConfig.getMusicFallbacks(key)
    local list = SoundConfig.MusicFallbacks and SoundConfig.MusicFallbacks[key]
    if type(list) ~= "table" then return {} end
    local out = {}
    for _, id in ipairs(list) do
        local aid = toAssetId(id)
        if aid then table.insert(out, aid) end
    end
    return out
end

function SoundConfig.getSfxId(key)
    return toAssetId(SoundConfig.Sfx and SoundConfig.Sfx[key])
end

-- Key for weapon attack sound: WeaponPistol, WeaponShotgun, WeaponMelee, etc.
function SoundConfig.getSfxForWeapon(weaponId, mode)
    if mode == "melee" then
        return "WeaponMelee"
    end
    local key = weaponId and ("Weapon" .. weaponId) or "WeaponShoot"
    if SoundConfig.Sfx and SoundConfig.Sfx[key] then
        return key
    end
    return (mode == "explosive") and "WeaponExplosion" or "WeaponShoot"
end

function SoundConfig.getSfxFallbackId(key)
    return toAssetId(SoundConfig.SfxFallbacks and SoundConfig.SfxFallbacks[key])
end

return SoundConfig
