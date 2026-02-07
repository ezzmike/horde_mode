local MapBuilder = {}

local Workspace = game:GetService("Workspace")

local function createPart(props)
    local part = Instance.new("Part")
    part.Anchored = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    for key, value in pairs(props) do
        part[key] = value
    end
    part.Parent = props.Parent
    return part
end

local function createSpawnLocation(props)
    local spawn = Instance.new("SpawnLocation")
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.TopSurface = Enum.SurfaceType.Smooth
    spawn.BottomSurface = Enum.SurfaceType.Smooth
    for key, value in pairs(props) do
        spawn[key] = value
    end
    spawn.Parent = props.Parent
    return spawn
end

function MapBuilder.build()
    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if not enemiesFolder then
        enemiesFolder = Instance.new("Folder")
        enemiesFolder.Name = "Enemies"
        enemiesFolder.Parent = Workspace
    end

    local mapFolder = Workspace:FindFirstChild("Map")
    if mapFolder then
        return mapFolder
    end

    mapFolder = Instance.new("Folder")
    mapFolder.Name = "Map"
    mapFolder.Parent = Workspace

    local lobby = Instance.new("Folder")
    lobby.Name = "Lobby"
    lobby.Parent = mapFolder

    local arena = Instance.new("Folder")
    arena.Name = "Arena"
    arena.Parent = mapFolder

    createPart({
        Name = "LobbyFloor",
        Size = Vector3.new(60, 1, 60),
        Position = Vector3.new(-150, 0, 0),
        Color = Color3.fromRGB(80, 120, 140),
        Material = Enum.Material.Slate,
        Parent = lobby,
    })

    createPart({
        Name = "ArenaFloor",
        Size = Vector3.new(120, 1, 120),
        Position = Vector3.new(0, 0, 0),
        Color = Color3.fromRGB(90, 90, 90),
        Material = Enum.Material.Concrete,
        Parent = arena,
    })

    local wallSize = Vector3.new(120, 24, 2)
    createPart({
        Name = "WallNorth",
        Size = wallSize,
        Position = Vector3.new(0, 12, -60),
        Color = Color3.fromRGB(60, 60, 60),
        Material = Enum.Material.Metal,
        Parent = arena,
    })

    createPart({
        Name = "WallSouth",
        Size = wallSize,
        Position = Vector3.new(0, 12, 60),
        Color = Color3.fromRGB(60, 60, 60),
        Material = Enum.Material.Metal,
        Parent = arena,
    })

    createPart({
        Name = "WallEast",
        Size = Vector3.new(2, 24, 120),
        Position = Vector3.new(60, 12, 0),
        Color = Color3.fromRGB(60, 60, 60),
        Material = Enum.Material.Metal,
        Parent = arena,
    })

    createPart({
        Name = "WallWest",
        Size = Vector3.new(2, 24, 120),
        Position = Vector3.new(-60, 12, 0),
        Color = Color3.fromRGB(60, 60, 60),
        Material = Enum.Material.Metal,
        Parent = arena,
    })

    createSpawnLocation({
        Name = "LobbySpawn",
        Size = Vector3.new(6, 1, 6),
        Position = Vector3.new(-150, 2, 0),
        Color = Color3.fromRGB(120, 200, 120),
        Parent = lobby,
    })

    local arenaSpawns = Instance.new("Folder")
    arenaSpawns.Name = "ArenaSpawns"
    arenaSpawns.Parent = arena

    local spawnPositions = {
        Vector3.new(20, 2, 20),
        Vector3.new(-20, 2, 20),
        Vector3.new(20, 2, -20),
        Vector3.new(-20, 2, -20),
    }

    for index, pos in ipairs(spawnPositions) do
        createSpawnLocation({
            Name = "ArenaSpawn" .. index,
            Size = Vector3.new(6, 1, 6),
            Position = pos,
            Color = Color3.fromRGB(120, 180, 220),
            Parent = arenaSpawns,
        })
    end

    local enemySpawns = Instance.new("Folder")
    enemySpawns.Name = "EnemySpawns"
    enemySpawns.Parent = arena

    local enemyPositions = {
        Vector3.new(50, 2, 0),
        Vector3.new(-50, 2, 0),
        Vector3.new(0, 2, 50),
        Vector3.new(0, 2, -50),
    }

    for index, pos in ipairs(enemyPositions) do
        createPart({
            Name = "EnemySpawn" .. index,
            Size = Vector3.new(3, 1, 3),
            Position = pos,
            Color = Color3.fromRGB(160, 80, 80),
            Material = Enum.Material.Neon,
            Parent = enemySpawns,
        })
    end

    local readyPad = createPart({
        Name = "ReadyPad",
        Size = Vector3.new(10, 1, 10),
        Position = Vector3.new(-150, 1.1, 18),
        Color = Color3.fromRGB(100, 200, 120),
        Material = Enum.Material.Neon,
        Parent = lobby,
    })

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "ReadyPrompt"
    prompt.ActionText = "Ready Up"
    prompt.ObjectText = "Arena"
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = readyPad

    local upgrades = Instance.new("Folder")
    upgrades.Name = "UpgradeStations"
    upgrades.Parent = arena

    local function createUpgradeStation(name, pos, upgradeType, baseCost, increment, amount)
        local station = createPart({
            Name = name,
            Size = Vector3.new(6, 2, 6),
            Position = pos,
            Color = Color3.fromRGB(80, 160, 200),
            Material = Enum.Material.Neon,
            Parent = upgrades,
        })

        station:SetAttribute("UpgradeType", upgradeType)
        station:SetAttribute("BaseCost", baseCost)
        station:SetAttribute("CostIncrement", increment)
        station:SetAttribute("UpgradeAmount", amount)

        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Upgrade"
        prompt.ObjectText = upgradeType
        prompt.MaxActivationDistance = 10
        prompt.RequiresLineOfSight = false
        prompt.Parent = station
    end

    createUpgradeStation("SpeedStation", Vector3.new(12, 1, 0), "Speed", 15, 10, 2)
    createUpgradeStation("HealthStation", Vector3.new(-12, 1, 0), "Health", 20, 12, 20)
    createUpgradeStation("DamageStation", Vector3.new(0, 1, 12), "Damage", 18, 11, 2)

    return mapFolder
end

return MapBuilder
