local EnemyConfig = {}

-- Realistic zombie types: varied speed, health, and threat
EnemyConfig.Types = {
    -- Slow, weak, classic shambler
    Shambler = {
        Health = 60,
        WalkSpeed = 8,
        Damage = 8,
        Reward = 6,
        AttackRange = 4.5,
        AttackCooldown = 1.6,
        Color = Color3.fromRGB(85, 95, 75),
        Scale = 1,
    },
    -- Standard infected, human-like
    Infected = {
        Health = 85,
        WalkSpeed = 14,
        Damage = 12,
        Reward = 10,
        AttackRange = 5,
        AttackCooldown = 1.2,
        Color = Color3.fromRGB(70, 85, 65),
        Scale = 1,
    },
    -- Fast, low health
    Runner = {
        Health = 45,
        WalkSpeed = 22,
        Damage = 6,
        Reward = 8,
        AttackRange = 4,
        AttackCooldown = 0.9,
        Color = Color3.fromRGB(95, 110, 80),
        Scale = 0.95,
    },
    -- Tank: slow but heavy hit
    Brute = {
        Health = 180,
        WalkSpeed = 7,
        Damage = 22,
        Reward = 18,
        AttackRange = 5.5,
        AttackCooldown = 1.8,
        Color = Color3.fromRGB(55, 65, 50),
        Scale = 1.25,
    },
    -- Legacy name for compatibility
    Walker = {
        Health = 60,
        WalkSpeed = 8,
        Damage = 8,
        Reward = 6,
        AttackRange = 4.5,
        AttackCooldown = 1.6,
        Color = Color3.fromRGB(85, 95, 75),
        Scale = 1,
    },
}

return EnemyConfig
