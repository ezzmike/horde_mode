local EnemyConfig = require(game:GetService("ReplicatedStorage").Modules.EnemyConfig)

local WaveConfig = {}

function WaveConfig.getWaveData(waveNumber)
    local baseCount = 5 + (waveNumber * 2)
    local mix = {}

    if waveNumber < 3 then
        mix = {"Grunt"}
    elseif waveNumber < 6 then
        mix = {"Grunt", "Runner"}
    else
        mix = {"Grunt", "Runner", "Brute"}
    end

    local reward = 10 + (waveNumber * 2)

    return {
        Count = baseCount,
        Types = mix,
        Reward = reward,
        SpawnDelay = math.max(0.4, 1.0 - (waveNumber * 0.05)),
        EnemyScale = 1 + (waveNumber * 0.08),
    }
end

function WaveConfig.scaleEnemyStats(typeName, scale)
    local base = EnemyConfig.Types[typeName]
    if not base then
        return nil
    end

    return {
        Health = math.floor(base.Health * scale),
        WalkSpeed = base.WalkSpeed,
        Damage = math.floor(base.Damage * (1 + (scale - 1) * 0.8)),
        Reward = math.floor(base.Reward * scale),
        AttackRange = base.AttackRange,
        AttackCooldown = base.AttackCooldown,
        Color = base.Color,
    }
end

return WaveConfig
