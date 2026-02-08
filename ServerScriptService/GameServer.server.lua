local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Modules.Constants)
local MapBuilder = require(script.Parent.Modules.MapBuilder)
local PlayerService = require(script.Parent.Modules.PlayerService)
local EnemyService = require(script.Parent.Modules.EnemyService)
local WaveManager = require(script.Parent.Modules.WaveManager)
local WeaponService = require(ReplicatedStorage.Modules.WeaponService)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)
local BotService = require(script.Parent.Modules.BotService)

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
    HitEffect = ensureRemote(Constants.Remotes.HitEffect),
    WeaponShootRequest = ensureRemote(Constants.Remotes.WeaponShootRequest),
    WeaponEffect = ensureRemote(Constants.Remotes.WeaponEffect),
    PlaySound = ensureRemote(Constants.Remotes.PlaySound),
    AdminGodMode = ensureRemote(Constants.Remotes.AdminGodMode),
    AdminGiveWeapon = ensureRemote(Constants.Remotes.AdminGiveWeapon),
    AdminNukeAll = ensureRemote(Constants.Remotes.AdminNukeAll),
    AdminPanelVisible = ensureRemote(Constants.Remotes.AdminPanelVisible),
}

local map = MapBuilder.build()
local lobbySpawn = map.Lobby:WaitForChild("LobbySpawn")
local arenaSpawns = map.Arena:WaitForChild("ArenaSpawns")
local enemySpawns = map.Arena:WaitForChild("EnemySpawns")
local enemyFolder = workspace:WaitForChild("Enemies")
local turretSeat = map.Arena:FindFirstChild("TurretSeat", true)

-- Ensure lobby is the only active spawn until match starts
if lobbySpawn:IsA("SpawnLocation") then lobbySpawn.Enabled = true end
for _, s in ipairs(arenaSpawns:GetChildren()) do
    if s:IsA("SpawnLocation") then s.Enabled = false end
end

PlayerService.init(remotes)
local botConfig = Constants.Game.BotsEnabled and {
    Scale = Constants.Game.BotsScale or 0.5,
    Min = Constants.Game.BotsMin or 0,
    Max = Constants.Game.BotsMax or 4,
    SinglePlayerTeammates = Constants.Game.SinglePlayerTeammates or 0,
} or nil
BotService.init(arenaSpawns, enemyFolder, botConfig, remotes)
WaveManager.init(remotes, EnemyService, PlayerService, WeaponService, arenaSpawns, enemySpawns, enemyFolder, Constants.Game.IntermissionTime)
local ok, err = pcall(function()
    WeaponService.init(remotes)
end)
if not ok then
    warn("[GameServer] WeaponService.init failed:", err)
end

local function stripWeaponById(player, weaponId)
    if not player or not weaponId then
        return
    end
    local config = WeaponConfig.Weapons[weaponId]
    local toolName = (config and config.DisplayName) or weaponId
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild(toolName)
        if tool then
            tool:Destroy()
        end
    end
    local character = player.Character
    if character then
        local tool = character:FindFirstChild(toolName)
        if tool then
            tool:Destroy()
        end
    end
end

if turretSeat and turretSeat:IsA("Seat") then
    local currentTurretPlayer = nil
    turretSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
        local humanoid = turretSeat.Occupant
        local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)

        if player == currentTurretPlayer then
            return
        end

        if currentTurretPlayer then
            stripWeaponById(currentTurretPlayer, "TurretMG")
            if currentTurretPlayer.Parent then
                WeaponService.giveWeapon(currentTurretPlayer, PlayerService.getCurrentWeaponId(currentTurretPlayer))
            end
            currentTurretPlayer = nil
        end

        if player then
            currentTurretPlayer = player
            WeaponService.giveWeapon(player, "TurretMG")
        end
    end)
end

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

WaveManager.setAllPlayersReadyCheck(function()
    local players = PlayerService.getAllPlayers()
    if #players == 0 then return false end
    return getReadyCount() >= #players
end)

local function teleportToLobby(player)
    local character = player.Character
    if character and character.PrimaryPart then
        character:SetPrimaryPartCFrame(lobbySpawn.CFrame + Vector3.new(0, 3, 0))
    end
    remotes.PlaySound:FireClient(player, "MusicLobby")
end

local function resetLobby()
    for _, player in ipairs(PlayerService.getAllPlayers()) do
        setPlayerReady(player, false)
        teleportToLobby(player)
    end
end

local function isAdmin(player)
    return Constants.AdminUserIds and Constants.AdminUserIds[player.UserId] == true
end

local function teleportToArena(player)
    local character = player.Character
    if not character or not character.PrimaryPart then return end
    local spawns = arenaSpawns:GetChildren()
    if #spawns == 0 then return end
    local spawn = spawns[math.random(1, #spawns)]
    character:SetPrimaryPartCFrame(spawn.CFrame + Vector3.new(0, 3, 0))
end

local function onCharacterAdded(player, character)
    PlayerService.applyCharacter(player, character)
    if player:GetAttribute("GodMode") then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.MaxHealth = math.huge
            humanoid.Health = math.huge
            humanoid.HealthChanged:Connect(function()
                if player:GetAttribute("GodMode") then
                    humanoid.Health = math.huge
                end
            end)
        end
    end
    task.spawn(function()
        task.wait(0.3)
        local ok, err = pcall(function()
            WeaponService.giveWeapon(player, PlayerService.getCurrentWeaponId(player))
        end)
        if not ok then
            warn("[GameServer] giveWeapon failed for", player.Name, ":", err)
        end
    end)
    task.wait(0.1)
    -- Only send to lobby when match isn't running; during match respawn in arena
    if isRunning then
        teleportToArena(player)
    else
        teleportToLobby(player)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    PlayerService.setupPlayer(player)
    if isAdmin(player) then
        remotes.AdminPanelVisible:FireClient(player, true)
    end
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

Players.PlayerAdded:Connect(function(player)
    PlayerService.setupPlayer(player)
    if isAdmin(player) then
        remotes.AdminPanelVisible:FireClient(player, true)
    end
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)
end)

-- Admin: God Mode toggle
remotes.AdminGodMode.OnServerEvent:Connect(function(player)
    if not isAdmin(player) then return end
    local current = player:GetAttribute("GodMode")
    player:SetAttribute("GodMode", not current)
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            if not current then
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
            else
                humanoid.MaxHealth = player:GetAttribute("MaxHealth") or 100
                humanoid.Health = humanoid.MaxHealth
            end
        end
    end
    remotes.Message:FireClient(player, "Info", "God mode: " .. (not current and "ON" or "OFF"), 2)
end)

-- Admin: Give special weapon by name
remotes.AdminGiveWeapon.OnServerEvent:Connect(function(player, weaponId)
    if not isAdmin(player) then return end
    if type(weaponId) ~= "string" or weaponId == "" then return end
    WeaponService.giveWeapon(player, weaponId)
    remotes.Message:FireClient(player, "Info", "Given weapon: " .. tostring(weaponId), 2)
end)

-- Admin: Nuke all enemies
remotes.AdminNukeAll.OnServerEvent:Connect(function(player)
    if not isAdmin(player) then return end
    EnemyService.killAllEnemies(enemyFolder)
    remotes.Message:FireClient(player, "Info", "Nuked all enemies!", 2)
end)

-- Client sends camera origin + direction so hitscan/explosive shots go where player aims
local function toVector3(v)
    if typeof(v) == "Vector3" then
        return v
    end
    if type(v) == "table" and v.X and v.Y and v.Z then
        return Vector3.new(v.X, v.Y, v.Z)
    end
    return nil
end
remotes.WeaponShootRequest.OnServerEvent:Connect(function(player, origin, direction, weaponIdFromClient)
    local o = toVector3(origin)
    local d = toVector3(direction)
    if not o or not d then return end
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local dist = (o - root.Position).Magnitude
    if dist > 150 then return end
    if d.Magnitude < 0.01 then return end
    d = d.Unit
    WeaponService.processShootFromCamera(player, o, d, weaponIdFromClient)
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

local function setSpawnLocationsForMatch(useArena)
    if lobbySpawn and lobbySpawn:IsA("SpawnLocation") then
        lobbySpawn.Enabled = not useArena
    end
    for _, spawn in ipairs(arenaSpawns:GetChildren()) do
        if spawn:IsA("SpawnLocation") then
            spawn.Enabled = useArena
            spawn.Neutral = true
        end
    end
end

local function startMatch()
    isRunning = true
    -- So Roblox uses arena spawns for respawns during match (not lobby)
    setSpawnLocationsForMatch(true)

    remotes.Message:FireAllClients("Info", "Entering arena!", 2)
    remotes.PlaySound:FireAllClients("MusicArena")

    -- Teleport all players to arena (twice with delay so it sticks)
    WaveManager.teleportPlayersToArena()
    task.wait(0.5)
    WaveManager.teleportPlayersToArena()
    -- Re-give weapon to everyone so it shows after teleport (covers late join or lobby timing)
    task.wait(0.5)
    for _, p in ipairs(PlayerService.getAllPlayers()) do
        if p.Character then
            pcall(function()
                WeaponService.giveWeapon(p, PlayerService.getCurrentWeaponId(p))
            end)
        end
    end
    -- Let character state and physics settle before wave loop checks alive
    task.wait(1.5)

    -- Spawn bots in a separate pcall so bot errors never prevent waves from running
    if botConfig then
        local botOk, botErr = pcall(function()
            local playerCount = #PlayerService.getAllPlayers()
            BotService.syncBotsForPlayerCount(playerCount)
            if playerCount == 1 and (botConfig.SinglePlayerTeammates or 0) > 0 then
                remotes.Message:FireAllClients("Info", "AI teammates have joined to assist you!", 3)
            end
        end)
        if not botOk then
            warn("[GameServer] BotService error (non-fatal, match continues):", botErr)
        end
    end

    -- Run waves in its own pcall — this is the critical match path
    local wavesSurvived = 0
    local ok, err = pcall(function()
        wavesSurvived = WaveManager.runWaves()
    end)
    if not ok then
        warn("[GameServer] WaveManager.runWaves error:", err)
    end

    isRunning = false
    setSpawnLocationsForMatch(false)

    remotes.Message:FireAllClients("GameOver", "Game over! Waves survived: " .. wavesSurvived, 4)
    remotes.PlaySound:FireAllClients("SfxGameOver")
    remotes.PlaySound:FireAllClients("MusicLobby")
    BotService.clearBots()

    for _, player in ipairs(PlayerService.getAllPlayers()) do
        PlayerService.resetRunStats(player)
    end

    task.wait(4)
    resetLobby()
end

local function lobbyLoop()
    while true do
        local ok, err = pcall(function()
            if not isRunning and #PlayerService.getAllPlayers() > 0 then
                local autoStart = Constants.Game.AutoStart
                if autoStart then
                    remotes.Message:FireAllClients("Info", "Match starting in " .. (Constants.Game.AutoStartDelay or 4) .. " seconds...", 2)
                    local countdown = Constants.Game.AutoStartDelay or 4
                    for t = countdown, 1, -1 do
                        remotes.Wave:FireAllClients("Lobby", t)
                        task.wait(1)
                    end
                    remotes.Message:FireAllClients("Info", "Match starting!", 2)
                    task.wait(2)
                    startMatch()
                else
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
            else
                task.wait(1)
            end
        end)
        if not ok then
            warn("[GameServer] lobbyLoop error:", err)
        end
        task.wait(1)
    end
end

task.spawn(lobbyLoop)
