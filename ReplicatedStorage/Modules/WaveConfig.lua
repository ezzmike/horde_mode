local EnemyConfig = require(game:GetService("ReplicatedStorage").Modules.EnemyConfig)

local WaveConfig = {}

WaveConfig.EliteModifiers = {
    Fast = {
        Label = "Fast",
        WalkSpeed = 1.35,
        Damage = 1.1,
        Health = 0.9,
        Reward = 1.2,
        Tint = { R = 0.15, G = 0.05, B = 0.05 },
    },
    Tanky = {
        Label = "Tanky",
        WalkSpeed = 0.85,
        Damage = 1.1,
        Health = 1.6,
        Reward = 1.35,
        Tint = { R = 0.05, G = 0.15, B = 0.05 },
    },
    Enraged = {
        Label = "Enraged",
        WalkSpeed = 1.2,
        Damage = 1.45,
        Health = 1.1,
        Reward = 1.4,
        Tint = { R = 0.2, G = 0.02, B = 0.02 },
    },
}

WaveConfig.Mutators = {
    "Fog",
    "DoubleRunners",
    "LowGravity",
}

WaveConfig.MutatorLabels = {
    Fog = "Fog",
    DoubleRunners = "Double Runners",
    LowGravity = "Low Gravity",
}

local function shuffledCopy(list)
    local out = {}
    for i, v in ipairs(list) do
        out[i] = v
    end
    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

local function pickMutators(waveNumber, isBossWave)
    if waveNumber < 3 then
        return {}
    end

    local chance = math.min(0.4, 0.08 + (waveNumber * 0.012))
    if isBossWave then
        chance = math.max(chance, 0.35)
    end

    if math.random() > chance then
        return {}
    end

    local pool = shuffledCopy(WaveConfig.Mutators)
    local count = 1
    if waveNumber >= 10 and isBossWave and math.random() < 0.35 then
        count = 2
    end

    local selected = {}
    for i = 1, math.min(count, #pool) do
        table.insert(selected, pool[i])
    end
    return selected
end

function WaveConfig.getWaveData(waveNumber, playerCount)
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

    local playerFactor = math.max(1, playerCount or 1)
    local countMultiplier = 1 + math.max(0, playerFactor - 1) * 0.35
    local rewardMultiplier = 1 + math.max(0, playerFactor - 1) * 0.15

    local reward = math.floor((8 + (waveNumber * 3)) * rewardMultiplier)
    -- Spawn delay: horde feels like a steady stream, not instant
    local spawnDelay = math.max(0.25, 0.9 - (waveNumber * 0.04))
    local enemyScale = 1 + (waveNumber * 0.06)
    local count = math.max(1, math.floor(baseCount * countMultiplier))

    local isBossWave = (waveNumber % 5 == 0)
    local bossBonusReward = 0
    if isBossWave then
        if not table.find(mix, "Brute") then
            table.insert(mix, "Brute")
        end
        enemyScale = enemyScale + 0.15
        count += math.max(1, math.floor(baseCount * 0.15))
        bossBonusReward = 10 + (waveNumber * 2)
    end

    local eliteChance = math.min(0.25, 0.06 + (waveNumber * 0.008))
    if isBossWave then
        eliteChance = math.min(0.35, eliteChance + 0.08)
    end

    local burstSize = math.clamp(3 + math.floor(waveNumber / 3), 3, 8)
    local lullDuration = math.max(0.35, 1.15 - (waveNumber * 0.03))
    local burstDelay = math.max(0.12, spawnDelay * 0.7)

    return {
        Count = count,
        Types = mix,
        Reward = reward,
        BossBonusReward = bossBonusReward,
        SpawnDelay = spawnDelay,
        EnemyScale = enemyScale,
        IsBossWave = isBossWave,
        EliteChance = eliteChance,
        EliteModifiers = WaveConfig.EliteModifiers,
        Mutators = pickMutators(waveNumber, isBossWave),
        BurstSize = burstSize,
        BurstDelay = burstDelay,
        LullDuration = lullDuration,
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
