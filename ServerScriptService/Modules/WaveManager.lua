local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveConfig = require(ReplicatedStorage.Modules.WaveConfig)

local WaveManager = {}

function WaveManager.init(remotes, enemyService, playerService, arenaSpawns, enemySpawns, enemyFolder, intermissionTime)
    WaveManager.remotes = remotes
    WaveManager.enemyService = enemyService
    WaveManager.playerService = playerService
    WaveManager.arenaSpawns = arenaSpawns
    WaveManager.enemySpawns = enemySpawns
    WaveManager.enemyFolder = enemyFolder
    WaveManager.intermissionTime = intermissionTime or 20
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

function WaveManager.teleportPlayersToArena()
    local spawns = WaveManager.arenaSpawns:GetChildren()
    if #spawns == 0 then
        return
    end

    shuffle(spawns)
    for index, player in ipairs(WaveManager.playerService.getAllPlayers()) do
        local spawn = spawns[((index - 1) % #spawns) + 1]
        local character = player.Character
        if character and character.PrimaryPart then
            character:SetPrimaryPartCFrame(spawn.CFrame + Vector3.new(0, 3, 0))
        end
    end
end

function WaveManager.spawnWave(waveNumber)
    local waveData = WaveConfig.getWaveData(waveNumber)
    local spawnPoints = WaveManager.enemySpawns:GetChildren()

    if #spawnPoints == 0 then
        return 0
    end

    local spawned = 0
    for i = 1, waveData.Count do
        local typeName = waveData.Types[((i - 1) % #waveData.Types) + 1]
        local stats = WaveConfig.scaleEnemyStats(typeName, waveData.EnemyScale)
        local spawn = spawnPoints[((i - 1) % #spawnPoints) + 1]
        WaveManager.enemyService.spawnEnemy(stats, spawn.Position, WaveManager.enemyFolder)
        spawned += 1
        task.wait(waveData.SpawnDelay)
    end

    return spawned
end

function WaveManager.anyPlayersAlive()
    return #WaveManager.playerService.getAlivePlayers() > 0
end

function WaveManager.runWaves()
    local waveNumber = 1
    local enemyFolder = WaveManager.enemyFolder

    local enemyAlive = 0
    local connection = WaveManager.enemyService.EnemyKilled.Event:Connect(function(reward)
        enemyAlive -= 1
        for _, player in ipairs(WaveManager.playerService.getAllPlayers()) do
            WaveManager.playerService.addCurrency(player, reward)
        end
    end)

    while WaveManager.anyPlayersAlive() do
        WaveManager.remotes.Wave:FireAllClients("Wave", waveNumber)

        enemyAlive = WaveManager.spawnWave(waveNumber)

        while enemyAlive > 0 and WaveManager.anyPlayersAlive() do
            task.wait(0.5)
        end

        if not WaveManager.anyPlayersAlive() then
            break
        end

        local waveReward = WaveConfig.getWaveData(waveNumber).Reward
        for _, player in ipairs(WaveManager.playerService.getAllPlayers()) do
            WaveManager.playerService.addCurrency(player, waveReward)
        end

        WaveManager.remotes.Message:FireAllClients("WaveComplete", "Wave " .. waveNumber .. " complete!", 3)

        waveNumber += 1
        for t = 1, WaveManager.intermissionTime do
            WaveManager.remotes.Wave:FireAllClients("Intermission", WaveManager.intermissionTime - t)
            task.wait(1)
        end
    end

    connection:Disconnect()

    for _, enemy in ipairs(enemyFolder:GetChildren()) do
        if enemy:IsA("Model") then
            enemy:Destroy()
        end
    end

    return waveNumber - 1
end

return WaveManager
