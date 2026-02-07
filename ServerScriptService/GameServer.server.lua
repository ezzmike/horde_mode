local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)
local MapBuilder = require(script.Parent.Modules.MapBuilder)
local PlayerService = require(script.Parent.Modules.PlayerService)
local EnemyService = require(script.Parent.Modules.EnemyService)
local WaveManager = require(script.Parent.Modules.WaveManager)

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name)
    local remote = remotesFolder:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = remotesFolder
    end
    return remote
end

local remotes = {
    Ready = ensureRemote(Constants.Remotes.Ready),
    Currency = ensureRemote(Constants.Remotes.Currency),
    Wave = ensureRemote(Constants.Remotes.Wave),
    Message = ensureRemote(Constants.Remotes.Message),
    Upgrade = ensureRemote(Constants.Remotes.Upgrade),
}

local map = MapBuilder.build()
local lobbySpawn = map.Lobby:WaitForChild("LobbySpawn")
local arenaSpawns = map.Arena:WaitForChild("ArenaSpawns")
local enemySpawns = map.Arena:WaitForChild("EnemySpawns")
local enemyFolder = workspace:WaitForChild("Enemies")

PlayerService.init(remotes)
WaveManager.init(remotes, EnemyService, PlayerService, arenaSpawns, enemySpawns, enemyFolder, Constants.Game.IntermissionTime)

local readyPlayers = {}
local isRunning = false

local function setPlayerReady(player, ready)
    readyPlayers[player] = ready and true or nil
end

local function getReadyCount()
    local count = 0
    for _ in pairs(readyPlayers) do
        count += 1
    end
    return count
end

local function teleportToLobby(player)
    local character = player.Character
    if character and character.PrimaryPart then
        character:SetPrimaryPartCFrame(lobbySpawn.CFrame + Vector3.new(0, 3, 0))
    end
end

local function resetLobby()
    for _, player in ipairs(PlayerService.getAllPlayers()) do
        setPlayerReady(player, false)
        teleportToLobby(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    PlayerService.setupPlayer(player)

    player.CharacterAdded:Connect(function(character)
        PlayerService.applyCharacter(player, character)
        task.wait(0.1)
        teleportToLobby(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    readyPlayers[player] = nil
end)

remotes.Ready.OnServerEvent:Connect(function(player)
    setPlayerReady(player, true)
    remotes.Message:FireClient(player, "Info", "Ready confirmed!", 2)
end)

remotes.Upgrade.OnServerEvent:Connect(function(player, upgradeType, baseCost, increment, amount)
    if isRunning == false then
        return
    end

    local cost = PlayerService.getUpgradeCost(player, upgradeType, baseCost, increment)
    local currency = player:GetAttribute("Currency") or 0

    if currency < cost then
        remotes.Message:FireClient(player, "Info", "Not enough currency.", 2)
        return
    end

    PlayerService.addCurrency(player, -cost)
    PlayerService.applyUpgrade(player, upgradeType, amount)
    remotes.Message:FireClient(player, "Info", upgradeType .. " upgraded!", 2)
end)

local function runLobbyCountdown(timeSeconds)
    for t = timeSeconds, 1, -1 do
        remotes.Wave:FireAllClients("Lobby", t)
        task.wait(1)
        if getReadyCount() >= Constants.Game.MinReadyPlayers then
            return true
        end
    end
    return #PlayerService.getAllPlayers() > 0
end

local function startMatch()
    isRunning = true
    remotes.Message:FireAllClients("Info", "Entering arena!", 2)

    WaveManager.teleportPlayersToArena()
    local wavesSurvived = WaveManager.runWaves()

    isRunning = false
    remotes.Message:FireAllClients("GameOver", "Game over! Waves survived: " .. wavesSurvived, 4)

    for _, player in ipairs(PlayerService.getAllPlayers()) do
        PlayerService.resetRunStats(player)
    end

    task.wait(4)
    resetLobby()
end

local function lobbyLoop()
    while true do
        if not isRunning and #PlayerService.getAllPlayers() > 0 then
            remotes.Message:FireAllClients("Info", "Waiting for players to ready up...", 2)

            local countdown = Constants.Game.LobbyCountdown
            local gotReady = runLobbyCountdown(countdown)

            if gotReady then
                remotes.Message:FireAllClients("Info", "Match starting!", 2)
                task.wait(2)
                startMatch()
            else
                task.wait(1)
            end
        end
        task.wait(1)
    end
end

task.spawn(lobbyLoop)
