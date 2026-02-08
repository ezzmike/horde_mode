local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveConfig = require(ReplicatedStorage.Modules.WaveConfig)

local WaveManager = {}

WaveManager.allPlayersReadyCheck = nil

function WaveManager.setAllPlayersReadyCheck(fn)
    WaveManager.allPlayersReadyCheck = fn
end

function WaveManager.init(remotes, enemyService, playerService, weaponService, arenaSpawns, enemySpawns, enemyFolder, intermissionTime)
    WaveManager.remotes = remotes
    WaveManager.enemyService = enemyService
    WaveManager.playerService = playerService
    WaveManager.weaponService = weaponService
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
        warn("[WaveManager] No arena spawns found!")
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
        warn("[WaveManager] No enemy spawn points found!")
        return 0
    end

    local spawned = 0
    for i = 1, waveData.Count do
        local typeName = waveData.Types[((i - 1) % #waveData.Types) + 1]
        local stats = WaveConfig.scaleEnemyStats(typeName, waveData.EnemyScale)
        local spawn = spawnPoints[((i - 1) % #spawnPoints) + 1]
        local ok, err = pcall(function()
            WaveManager.enemyService.spawnEnemy(stats, spawn.Position, WaveManager.enemyFolder)
        end)
        if ok then
            spawned += 1
        else
            warn("[WaveManager] Failed to spawn enemy:", err)
        end
        task.wait(waveData.SpawnDelay)
    end

    return spawned
end

function WaveManager.anyPlayersAlive()
    return #WaveManager.playerService.getAlivePlayers() > 0
end

-- Respawn-tolerant check: returns false only when ALL players have been dead
-- for longer than the grace period (covers the Roblox respawn window).
local RESPAWN_GRACE_SECONDS = 8
local allDeadSince = nil

local function allPlayersTrulyDead()
    if WaveManager.anyPlayersAlive() then
        allDeadSince = nil
        return false
    end
    -- No players in server at all -> end match
    if #WaveManager.playerService.getAllPlayers() == 0 then
        return true
    end
    if allDeadSince == nil then
        allDeadSince = os.clock()
    end
    return (os.clock() - allDeadSince) >= RESPAWN_GRACE_SECONDS
end

-- Count how many enemies in the folder are still alive (Humanoid with Health > 0).
-- This is the source of truth instead of a counter that can drift.
local function countAliveEnemies()
    local count = 0
    for _, child in ipairs(WaveManager.enemyFolder:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("IsEnemy") then
            local humanoid = child:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                count += 1
            end
        end
    end
    return count
end

local OUT_OF_BOUNDS_Y = -60
local STUCK_WAVE_TIMEOUT = 45
local WAVE_MAX_DURATION = 180

local function pruneInvalidEnemies()
    for _, child in ipairs(WaveManager.enemyFolder:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("IsEnemy") then
            local humanoid = child:FindFirstChild("Humanoid")
            local hrp = child:FindFirstChild("HumanoidRootPart")
            if not humanoid or not hrp then
                child:Destroy()
            elseif humanoid.Health > 0 and hrp.Position.Y < OUT_OF_BOUNDS_Y then
                humanoid.Health = 0
            end
        end
    end
end

-- Wait for at least one player to have a valid character and Health > 0.
local WAIT_FOR_ALIVE_TIMEOUT = 10
local WAIT_FOR_ALIVE_INTERVAL = 0.25

local function waitForAnyPlayerAlive()
    local elapsed = 0
    while elapsed < WAIT_FOR_ALIVE_TIMEOUT do
        if WaveManager.anyPlayersAlive() then
            return true
        end
        task.wait(WAIT_FOR_ALIVE_INTERVAL)
        elapsed += WAIT_FOR_ALIVE_INTERVAL
    end
    warn("[WaveManager] Timed out waiting for alive players after", WAIT_FOR_ALIVE_TIMEOUT, "seconds")
    -- Log all player states for debugging
    for _, player in ipairs(WaveManager.playerService.getAllPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        local health = humanoid and humanoid.Health or "nil"
        warn("  Player:", player.Name, "Character:", tostring(character), "Health:", tostring(health))
    end
    return false
end

function WaveManager.runWaves()
    local waveNumber = 1
    local enemyFolder = WaveManager.enemyFolder

    -- Short fixed delay so character/alive state is valid after arena teleport (no immediate check).
    task.wait(2)

    -- Wait until at least one player is alive (character + Humanoid.Health > 0).
    if not waitForAnyPlayerAlive() then
        return 0
    end

    -- Give currency to all players when an enemy is killed
    local connection = WaveManager.enemyService.EnemyKilled.Event:Connect(function(reward)
        for _, player in ipairs(WaveManager.playerService.getAllPlayers()) do
            WaveManager.playerService.addCurrency(player, reward)
        end
    end)

    allDeadSince = nil  -- reset grace timer at wave-loop start

    while not allPlayersTrulyDead() do
        WaveManager.remotes.Wave:FireAllClients("Wave", waveNumber)
        WaveManager.remotes.PlaySound:FireAllClients("SfxWaveStart")

        local waveStartTime = os.clock()

        -- Spawn the wave (enemies may die during spawn due to task.wait between spawns)
        WaveManager.spawnWave(waveNumber)

        -- Wait until all enemies are dead OR all players are dead.
        -- Use actual folder count instead of a decrement counter to avoid drift.
        local lastCount = countAliveEnemies()
        local lastChangeTime = os.clock()
        while countAliveEnemies() > 0 and not allPlayersTrulyDead() do
            pruneInvalidEnemies()
            if (os.clock() - waveStartTime) > WAVE_MAX_DURATION then
                warn("[WaveManager] Wave timeout; forcing completion.")
                if WaveManager.enemyService and WaveManager.enemyService.killAllEnemies then
                    WaveManager.enemyService.killAllEnemies(WaveManager.enemyFolder)
                end
                break
            end
            local currentCount = countAliveEnemies()
            if currentCount ~= lastCount then
                lastCount = currentCount
                lastChangeTime = os.clock()
            elseif (os.clock() - lastChangeTime) > STUCK_WAVE_TIMEOUT then
                warn("[WaveManager] Wave stalled; clearing remaining enemies.")
                if WaveManager.enemyService and WaveManager.enemyService.killAllEnemies then
                    WaveManager.enemyService.killAllEnemies(WaveManager.enemyFolder)
                else
                    for _, model in ipairs(WaveManager.enemyFolder:GetChildren()) do
                        if model:IsA("Model") then
                            local humanoid = model:FindFirstChild("Humanoid")
                            if humanoid then
                                humanoid.Health = 0
                            end
                        end
                    end
                end
            end
            task.wait(0.5)
        end

        if allPlayersTrulyDead() then
            break
        end

        -- Wave cleared — reward players
        local waveReward = WaveConfig.getWaveData(waveNumber).Reward
        for _, player in ipairs(WaveManager.playerService.getAllPlayers()) do
            WaveManager.playerService.addCurrency(player, waveReward)
        end

        WaveManager.remotes.Message:FireAllClients("WaveComplete", "Wave " .. waveNumber .. " complete!", 3)
        WaveManager.remotes.PlaySound:FireAllClients("SfxWaveComplete")

        for _, player in ipairs(WaveManager.playerService.getAllPlayers()) do
            local weaponId = WaveManager.playerService.advanceWeapon(player)
            WaveManager.weaponService.giveWeapon(player, weaponId)
        end
        WaveManager.remotes.Message:FireAllClients("Info", "Weapons upgraded!", 2)

        waveNumber += 1
        for t = 1, WaveManager.intermissionTime do
            WaveManager.remotes.Wave:FireAllClients("Intermission", WaveManager.intermissionTime - t)
            if WaveManager.allPlayersReadyCheck and WaveManager.allPlayersReadyCheck() then
                break
            end
            task.wait(1)
        end
    end

    connection:Disconnect()

    -- Clean up remaining enemies
    for _, enemy in ipairs(enemyFolder:GetChildren()) do
        if enemy:IsA("Model") then
            enemy:Destroy()
        end
    end

    return waveNumber - 1
end

return WaveManager
