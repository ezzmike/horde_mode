local EnemyConfig = {}

EnemyConfig.Types = {
    Grunt = {
        Health = 60,
        WalkSpeed = 14,
        Damage = 8,
        Reward = 5,
        AttackRange = 4,
        AttackCooldown = 1.2,
        Color = Color3.fromRGB(180, 60, 60),
    },
    Brute = {
        Health = 140,
        WalkSpeed = 10,
        Damage = 16,
        Reward = 12,
        AttackRange = 5,
        AttackCooldown = 1.6,
        Color = Color3.fromRGB(120, 40, 40),
    },
    Runner = {
        Health = 45,
        WalkSpeed = 20,
        Damage = 6,
        Reward = 7,
        AttackRange = 4,
        AttackCooldown = 1.0,
        Color = Color3.fromRGB(200, 120, 60),
    },
}

return EnemyConfig
