local WeaponConfig = {}

WeaponConfig.Order = {
    "Sword",
    "Pistol",
    "Shotgun",
    "M16",
    "RPG",
    "C4",
    "TNT",
}

-- Headshot multiplier (applied when hitting Head part)
WeaponConfig.HeadshotMultiplier = 2.0

-- Sword is baseline; guns do more damage per hit and at range.
WeaponConfig.Weapons = {
    Sword = {
        DisplayName = "Combat Knife",
        Mode = "melee",
        Damage = 42,
        Cooldown = 0.5,
        Range = 8,
        Color = Color3.fromRGB(60, 60, 65),
        Size = Vector3.new(0.2, 0.3, 1.0),
    },
    Pistol = {
        DisplayName = "9mm Pistol",
        Mode = "hitscan",
        Damage = 50,
        Cooldown = 0.24,
        Range = 160,
        Pellets = 1,
        Spread = 1.5,
        Color = Color3.fromRGB(45, 45, 50),
        Size = Vector3.new(0.4, 0.5, 1.4),
    },
    Shotgun = {
        DisplayName = "Pump Shotgun",
        Mode = "hitscan",
        Damage = 22,
        Cooldown = 1.0,
        Range = 50,
        Pellets = 10,
        Spread = 12,
        Color = Color3.fromRGB(55, 50, 45),
        Size = Vector3.new(0.5, 0.6, 1.8),
    },
    M16 = {
        DisplayName = "M16 Rifle",
        Mode = "hitscan",
        Damage = 46,
        Cooldown = 0.08,
        Range = 220,
        Pellets = 1,
        Spread = 1.8,
        Color = Color3.fromRGB(50, 55, 50),
        Size = Vector3.new(0.5, 0.7, 2.2),
    },
    TurretMG = {
        DisplayName = "Turret MG",
        Mode = "hitscan",
        Damage = 22,
        Cooldown = 0.06,
        Range = 260,
        Pellets = 1,
        Spread = 2.4,
        Color = Color3.fromRGB(65, 70, 72),
        Size = Vector3.new(0.6, 0.7, 2.6),
    },
    RPG = {
        DisplayName = "RPG-7",
        Mode = "explosive",
        Damage = 180,
        Cooldown = 2.6,
        Range = 200,
        Radius = 16,
        Color = Color3.fromRGB(55, 55, 50),
        Size = Vector3.new(0.6, 0.6, 2.4),
    },
    C4 = {
        DisplayName = "C4 Charge",
        Mode = "explosive",
        Damage = 240,
        Cooldown = 3.0,
        Range = 110,
        Radius = 18,
        Color = Color3.fromRGB(90, 95, 90),
        Size = Vector3.new(0.5, 0.4, 1.0),
    },
    TNT = {
        DisplayName = "TNT Bundle",
        Mode = "explosive",
        Damage = 300,
        Cooldown = 3.8,
        Range = 95,
        Radius = 22,
        Color = Color3.fromRGB(120, 50, 45),
        Size = Vector3.new(0.6, 0.5, 1.2),
    },
}

function WeaponConfig.getWeaponIndex(weaponId)
    for index, id in ipairs(WeaponConfig.Order) do
        if string.lower(id) == string.lower(weaponId) then
            return index
        end
    end
    return nil
end

function WeaponConfig.getWeaponIdByIndex(index)
    return WeaponConfig.Order[index]
end

-- Resolve weaponId from tool display name (for when attribute hasn't replicated yet)
function WeaponConfig.getWeaponIdFromDisplayName(displayName)
    if not displayName or type(displayName) ~= "string" then return nil end
    for id, cfg in pairs(WeaponConfig.Weapons or {}) do
        if cfg.DisplayName and string.lower(cfg.DisplayName) == string.lower(displayName) then
            return id
        end
    end
    return nil
end

return WeaponConfig
