local EnemyConfig = require(game:GetService("ReplicatedStorage").Modules.EnemyConfig)

local WaveConfig = {}

function WaveConfig.getWaveData(waveNumber)
    -- Realistic horde ramp: starts small, builds over time
    local baseCount = 4 + math.floor(waveNumber * 2.5)
    local mix

    if waveNumber <= 2 then
        mix = {"Shambler"}
    elseif waveNumber <= 4 then
        mix = {"Shambler", "Infected"}
    elseif waveNumber <= 7 then
        mix = {"Shambler", "Infected", "Runner"}
    else
        mix = {"Shambler", "Infected", "Runner", "Brute"}
    end

    local reward = 8 + (waveNumber * 3)
    -- Spawn delay: horde feels like a steady stream, not instant
    local spawnDelay = math.max(0.25, 0.9 - (waveNumber * 0.04))

    return {
        Count = baseCount,
        Types = mix,
        Reward = reward,
        SpawnDelay = spawnDelay,
        EnemyScale = 1 + (waveNumber * 0.06),
    }
end

function WaveConfig.scaleEnemyStats(typeName, scale)
    local base = EnemyConfig.Types[typeName] or EnemyConfig.Types.Shambler
    return {
        TypeName = typeName,
        Health = math.floor(base.Health * scale),
        WalkSpeed = base.WalkSpeed,
        Damage = math.floor(base.Damage * (1 + (scale - 1) * 0.5)),
        Reward = math.floor(base.Reward * scale),
        AttackRange = base.AttackRange,
        AttackCooldown = base.AttackCooldown,
        Color = base.Color,
        Scale = base.Scale and base.Scale * scale or scale,
    }
end

return WaveConfig
