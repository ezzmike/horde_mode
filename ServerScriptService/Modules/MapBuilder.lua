local MapBuilder = {}

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

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

local function addLight(parent, pos, color, brightness, range)
    local p = Instance.new("Part")
    p.Name = "LightAnchor"
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = Vector3.new(0.1, 0.1, 0.1)
    p.Position = pos
    p.Parent = parent
    local l = Instance.new("PointLight")
    l.Color = color
    l.Brightness = brightness
    l.Range = range
    l.Parent = p
    return p
end

local function addParticles(parent, pos, size, color, rate, speed)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = size
    p.Position = pos
    p.Parent = parent
    local e = Instance.new("ParticleEmitter")
    e.Color = ColorSequence.new(color)
    e.Size = NumberSequence.new(1.2, 0)
    e.Transparency = NumberSequence.new(0.5, 1)
    e.Lifetime = NumberRange.new(2, 4)
    e.Rate = rate
    e.Speed = NumberRange.new(speed * 0.5, speed)
    e.SpreadAngle = Vector2.new(180, 180)
    e.LightEmission = 0.4
    e.Parent = p
    return p
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
        -- Re-apply lighting and fix floor colors when map already exists
        local arena = mapFolder:FindFirstChild("Arena")
        if arena then
            local floor = arena:FindFirstChild("ArenaFloor")
            if floor then floor.Color = Color3.fromRGB(165, 168, 172) end
            local trim = arena:FindFirstChild("ArenaTrim")
            if trim then trim.Color = Color3.fromRGB(145, 148, 152); trim.Material = Enum.Material.Metal end
            local center = arena:FindFirstChild("CenterPlatform")
            if center then center.Color = Color3.fromRGB(155, 158, 162) end
            local spawns = arena:FindFirstChild("ArenaSpawns")
            if spawns then
                for _, s in ipairs(spawns:GetChildren()) do
                    if s:IsA("SpawnLocation") then s.Color = Color3.fromRGB(175, 178, 182) end
                end
            end
            local walls = {"WallNorth", "WallSouth", "WallEast", "WallWest"}
            for _, name in ipairs(walls) do
                local w = arena:FindFirstChild(name)
                if w then w.Color = Color3.fromRGB(150, 153, 158) end
            end
        end
        local lobby = mapFolder:FindFirstChild("Lobby")
        if lobby then
            local spawn = lobby:FindFirstChild("LobbySpawn")
            if spawn and spawn:IsA("SpawnLocation") then spawn.Color = Color3.fromRGB(175, 185, 175) end
            local pad = lobby:FindFirstChild("ReadyPad")
            if pad then pad.Color = Color3.fromRGB(160, 185, 165); pad.Material = Enum.Material.SmoothPlastic end
        end
        MapBuilder.applyLightingAndEffects(mapFolder)
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

    -- Lobby: neutral, light tones
    createPart({
        Name = "LobbyFloor",
        Size = Vector3.new(60, 1, 60),
        Position = Vector3.new(-150, 0, 0),
        Color = Color3.fromRGB(175, 182, 188),
        Material = Enum.Material.Marble,
        Parent = lobby,
    })
    createPart({
        Name = "LobbyTrim",
        Size = Vector3.new(62, 0.3, 62),
        Position = Vector3.new(-150, 0.5, 0),
        Color = Color3.fromRGB(155, 162, 168),
        Material = Enum.Material.Metal,
        Parent = lobby,
    })
    for _, o in ipairs({{-165, -20}, {-165, 20}, {-135, -20}, {-135, 20}}) do
        createPart({
            Name = "Pillar",
            Size = Vector3.new(3, 12, 3),
            Position = Vector3.new(o[1], 6, o[2]),
            Color = Color3.fromRGB(160, 168, 175),
            Material = Enum.Material.Concrete,
            Parent = lobby,
        })
    end
    local signBack = createPart({
        Name = "SignBack",
        Size = Vector3.new(18, 5, 1),
        Position = Vector3.new(-150, 16, 22),
        Color = Color3.fromRGB(130, 138, 145),
        Material = Enum.Material.Metal,
        Parent = lobby,
    })
    createPart({
        Name = "SignFace",
        Size = Vector3.new(16, 3.5, 0.5),
        Position = Vector3.new(-150, 16, 22.8),
        Color = Color3.fromRGB(220, 195, 130),
        Material = Enum.Material.SmoothPlastic,
        Parent = lobby,
    })
    addLight(lobby, Vector3.new(-150, 20, 22), Color3.fromRGB(240, 235, 220), 0.5, 25)
    for _, z in ipairs({-12, 8}) do
        createPart({
            Name = "Bench",
            Size = Vector3.new(6, 0.5, 1.5),
            Position = Vector3.new(-150, 0.85, z),
            Color = Color3.fromRGB(145, 125, 105),
            Material = Enum.Material.Wood,
            Parent = lobby,
        })
    end

    -- Arena: neutral gray/beige floor
    createPart({
        Name = "ArenaFloor",
        Size = Vector3.new(120, 1, 120),
        Position = Vector3.new(0, 0, 0),
        Color = Color3.fromRGB(165, 168, 172),
        Material = Enum.Material.Concrete,
        Parent = arena,
    })
    createPart({
        Name = "ArenaTrim",
        Size = Vector3.new(122, 0.4, 122),
        Position = Vector3.new(0, 0.5, 0),
        Color = Color3.fromRGB(145, 148, 152),
        Material = Enum.Material.Metal,
        Parent = arena,
    })
    createPart({
        Name = "CenterPlatform",
        Size = Vector3.new(16, 0.8, 16),
        Position = Vector3.new(0, 0.4, 0),
        Color = Color3.fromRGB(155, 158, 162),
        Material = Enum.Material.Metal,
        Parent = arena,
    })
    addLight(arena, Vector3.new(0, 2, 0), Color3.fromRGB(220, 215, 205), 0.4, 20)

    local wallSize = Vector3.new(120, 24, 2)
    local wallColor = Color3.fromRGB(150, 153, 158)
    createPart({ Name = "WallNorth", Size = wallSize, Position = Vector3.new(0, 12, -60), Color = wallColor, Material = Enum.Material.Metal, Parent = arena })
    createPart({ Name = "WallSouth", Size = wallSize, Position = Vector3.new(0, 12, 60), Color = wallColor, Material = Enum.Material.Metal, Parent = arena })
    createPart({ Name = "WallEast", Size = Vector3.new(2, 24, 120), Position = Vector3.new(60, 12, 0), Color = wallColor, Material = Enum.Material.Metal, Parent = arena })
    createPart({ Name = "WallWest", Size = Vector3.new(2, 24, 120), Position = Vector3.new(-60, 12, 0), Color = wallColor, Material = Enum.Material.Metal, Parent = arena })

    createSpawnLocation({
        Name = "LobbySpawn",
        Size = Vector3.new(6, 1, 6),
        Position = Vector3.new(-150, 2, 0),
        Color = Color3.fromRGB(175, 185, 175),
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
            Color = Color3.fromRGB(175, 178, 182),
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
            Color = Color3.fromRGB(195, 150, 145),
            Material = Enum.Material.SmoothPlastic,
            Parent = enemySpawns,
        })
        addParticles(arena, pos + Vector3.new(0, 2, 0), Vector3.new(4, 2, 4), Color3.fromRGB(180, 140, 135), 4, 1.5)
    end

    -- Props: horde-mode themed (sandbag walls, ammo crates, concrete barriers,
    -- barrels, tire stacks, wooden pallets, metal shelters, razor wire posts)
    local props = Instance.new("Folder")
    props.Name = "Props"
    props.Parent = arena

    -- Sandbag walls: L-shaped or straight, provide chest-high cover
    local sandbagColor = Color3.fromRGB(135, 125, 105)
    local sandbagMat = Enum.Material.Slate
    local sandbagWalls = {
        -- North-west cluster (L-shape)
        { pos = Vector3.new(-30, 1.0, -28), size = Vector3.new(8, 2, 1.8) },
        { pos = Vector3.new(-34, 1.0, -24), size = Vector3.new(1.8, 2, 6) },
        -- North-east straight wall
        { pos = Vector3.new(28, 1.0, -30), size = Vector3.new(10, 2, 1.8) },
        -- South-west angled cover
        { pos = Vector3.new(-25, 1.0, 30), size = Vector3.new(8, 2, 1.8) },
        -- South-east L-shape
        { pos = Vector3.new(30, 1.0, 25), size = Vector3.new(1.8, 2, 8) },
        { pos = Vector3.new(34, 1.0, 29), size = Vector3.new(6, 2, 1.8) },
        -- Center flanking walls
        { pos = Vector3.new(12, 1.0, -8), size = Vector3.new(1.8, 2, 6) },
        { pos = Vector3.new(-12, 1.0, 8), size = Vector3.new(1.8, 2, 6) },
    }
    for i, data in ipairs(sandbagWalls) do
        createPart({
            Name = "Sandbag" .. i,
            Size = data.size,
            Position = data.pos,
            Color = sandbagColor,
            Material = sandbagMat,
            Parent = props,
        })
        -- Top row (slightly smaller, stacked look)
        createPart({
            Name = "SandbagTop" .. i,
            Size = Vector3.new(data.size.X * 0.9, 0.6, data.size.Z * 0.9),
            Position = data.pos + Vector3.new(0, 1.3, 0),
            Color = Color3.fromRGB(125, 118, 98),
            Material = sandbagMat,
            Parent = props,
        })
    end

    -- Ammo crates: olive drab with metal trim, scattered near cover
    local crateColor = Color3.fromRGB(75, 85, 65)
    local crateMat = Enum.Material.WoodPlanks
    local ammoPositions = {
        Vector3.new(-28, 0.9, -22), Vector3.new(30, 0.9, -26),
        Vector3.new(-22, 0.9, 32),  Vector3.new(32, 0.9, 22),
        Vector3.new(8, 0.9, -5),    Vector3.new(-8, 0.9, 5),
    }
    for i, pos in ipairs(ammoPositions) do
        createPart({
            Name = "AmmoCrate" .. i,
            Size = Vector3.new(2.5, 1.8, 1.5),
            Position = pos,
            Color = crateColor,
            Material = crateMat,
            Parent = props,
        })
        -- Lid/metal strip
        createPart({
            Name = "CrateLid" .. i,
            Size = Vector3.new(2.6, 0.15, 1.6),
            Position = pos + Vector3.new(0, 0.95, 0),
            Color = Color3.fromRGB(90, 88, 82),
            Material = Enum.Material.Metal,
            Parent = props,
        })
    end

    -- Concrete jersey barriers: heavy cover, angled around the arena mid-ring
    local barrierColor = Color3.fromRGB(155, 155, 150)
    local barrierMat = Enum.Material.Concrete
    local barriers = {
        { pos = Vector3.new(40, 1.2, 0), size = Vector3.new(2.5, 2.4, 6) },
        { pos = Vector3.new(-40, 1.2, 0), size = Vector3.new(2.5, 2.4, 6) },
        { pos = Vector3.new(0, 1.2, 40), size = Vector3.new(6, 2.4, 2.5) },
        { pos = Vector3.new(0, 1.2, -40), size = Vector3.new(6, 2.4, 2.5) },
        -- Diagonal barriers
        { pos = Vector3.new(35, 1.2, 35), size = Vector3.new(5, 2.4, 2) },
        { pos = Vector3.new(-35, 1.2, -35), size = Vector3.new(5, 2.4, 2) },
        { pos = Vector3.new(-35, 1.2, 35), size = Vector3.new(2, 2.4, 5) },
        { pos = Vector3.new(35, 1.2, -35), size = Vector3.new(2, 2.4, 5) },
    }
    for i, data in ipairs(barriers) do
        createPart({
            Name = "Barrier" .. i,
            Size = data.size,
            Position = data.pos,
            Color = barrierColor,
            Material = barrierMat,
            Parent = props,
        })
    end

    -- Raised machine gun nest (single-seat turret platform)
    local nest = Instance.new("Model")
    nest.Name = "MachineGunNest"
    nest.Parent = arena

    local nestBasePos = Vector3.new(0, 3.5, -32)
    local nestPlatformSize = Vector3.new(10, 1, 8)
    createPart({
        Name = "NestPlatform",
        Size = nestPlatformSize,
        Position = nestBasePos,
        Color = Color3.fromRGB(120, 125, 130),
        Material = Enum.Material.Metal,
        Parent = nest,
    })

    -- Support columns
    for _, offset in ipairs({
        Vector3.new(4, -2.5, 3),
        Vector3.new(-4, -2.5, 3),
        Vector3.new(4, -2.5, -3),
        Vector3.new(-4, -2.5, -3),
    }) do
        createPart({
            Name = "NestSupport",
            Size = Vector3.new(0.8, 5, 0.8),
            Position = nestBasePos + offset,
            Color = Color3.fromRGB(95, 100, 105),
            Material = Enum.Material.Metal,
            Parent = nest,
        })
    end

    -- Steps up to the platform
    for i = 1, 3 do
        createPart({
            Name = "NestStep" .. i,
            Size = Vector3.new(4, 0.6, 2),
            Position = Vector3.new(0, 1.2 + (i * 0.6), -27 + (i * -1.6)),
            Color = Color3.fromRGB(130, 135, 140),
            Material = Enum.Material.Metal,
            Parent = nest,
        })
    end

    -- Sandbag parapet
    for i = -2, 2 do
        createPart({
            Name = "NestSandbag" .. tostring(i),
            Size = Vector3.new(1.6, 1.2, 0.9),
            Position = nestBasePos + Vector3.new(i * 1.7, 1.1, -3.2),
            Color = sandbagColor,
            Material = sandbagMat,
            Parent = nest,
        })
    end

    local seat = Instance.new("Seat")
    seat.Name = "TurretSeat"
    seat.Size = Vector3.new(2, 1, 2)
    seat.Position = nestBasePos + Vector3.new(0, 1.6, 1.2)
    seat.Anchored = true
    seat.CanCollide = true
    seat.Color = Color3.fromRGB(90, 95, 100)
    seat.Material = Enum.Material.Metal
    seat.Parent = nest

    -- Simple turret stand
    createPart({
        Name = "NestTurretBase",
        Size = Vector3.new(1.2, 1.4, 1.2),
        Position = nestBasePos + Vector3.new(0, 1.2, -1.2),
        Color = Color3.fromRGB(80, 85, 88),
        Material = Enum.Material.Metal,
        Parent = nest,
    })
    createPart({
        Name = "NestTurretBarrel",
        Size = Vector3.new(0.4, 0.4, 2.2),
        Position = nestBasePos + Vector3.new(0, 1.8, -2.6),
        Color = Color3.fromRGB(60, 62, 64),
        Material = Enum.Material.Metal,
        Parent = nest,
    })

    -- Metal barrels: hazard/fuel, some upright, some tipped
    local barrelColor = Color3.fromRGB(110, 105, 95)
    local barrelPositions = {
        { pos = Vector3.new(42, 1.2, 12), tipped = false },
        { pos = Vector3.new(-42, 1.2, -12), tipped = false },
        { pos = Vector3.new(38, 0.9, -18), tipped = true },
        { pos = Vector3.new(-38, 0.9, 20), tipped = true },
        { pos = Vector3.new(15, 1.2, 38), tipped = false },
        { pos = Vector3.new(-15, 1.2, -38), tipped = false },
    }
    for i, data in ipairs(barrelPositions) do
        local b = Instance.new("Part")
        b.Name = "Barrel" .. i
        b.Shape = Enum.PartType.Cylinder
        b.Anchored = true
        b.Material = Enum.Material.Metal
        b.Color = barrelColor
        if data.tipped then
            b.Size = Vector3.new(1.2, 1.6, 1.6)
            b.Orientation = Vector3.new(0, 0, 90)
        else
            b.Size = Vector3.new(2.4, 1.6, 1.6)
            b.Orientation = Vector3.new(0, 0, 0)
        end
        b.Position = data.pos
        b.Parent = props
    end
    -- A few red hazard barrels (explosive feel)
    for i, pos in ipairs({
        Vector3.new(45, 1.2, -8), Vector3.new(-45, 1.2, 8),
    }) do
        local b = Instance.new("Part")
        b.Name = "HazardBarrel" .. i
        b.Shape = Enum.PartType.Cylinder
        b.Size = Vector3.new(2.4, 1.6, 1.6)
        b.Position = pos
        b.Anchored = true
        b.Color = Color3.fromRGB(140, 55, 45)
        b.Material = Enum.Material.Metal
        b.Parent = props
    end

    -- Tire stacks: waist-high obstacles
    local tireColor = Color3.fromRGB(50, 48, 45)
    for i, pos in ipairs({
        Vector3.new(18, 1.0, 30), Vector3.new(-18, 1.0, -30),
        Vector3.new(25, 1.0, -15), Vector3.new(-25, 1.0, 15),
    }) do
        local t = Instance.new("Part")
        t.Name = "TireStack" .. i
        t.Shape = Enum.PartType.Cylinder
        t.Size = Vector3.new(2.0, 2.2, 2.2)
        t.Position = pos
        t.Anchored = true
        t.Color = tireColor
        t.Material = Enum.Material.Plastic
        t.Parent = props
    end

    -- Wooden pallets: low obstacles, break up sightlines near cover
    local palletColor = Color3.fromRGB(145, 120, 85)
    for i, pos in ipairs({
        Vector3.new(22, 0.6, 10), Vector3.new(-22, 0.6, -10),
        Vector3.new(5, 0.6, 25), Vector3.new(-5, 0.6, -25),
    }) do
        createPart({
            Name = "Pallet" .. i,
            Size = Vector3.new(3.5, 0.4, 3.5),
            Position = pos,
            Color = palletColor,
            Material = Enum.Material.WoodPlanks,
            Parent = props,
        })
    end

    -- Metal lean-to shelters: two angled plates, gives overhead + side cover
    local shelterColor = Color3.fromRGB(120, 118, 115)
    for i, data in ipairs({
        { pos = Vector3.new(22, 2.2, -35), size = Vector3.new(6, 0.3, 5), rot = Vector3.new(15, 0, 0) },
        { pos = Vector3.new(-22, 2.2, 35), size = Vector3.new(6, 0.3, 5), rot = Vector3.new(-15, 0, 0) },
    }) do
        local s = Instance.new("Part")
        s.Name = "Shelter" .. i
        s.Size = data.size
        s.Position = data.pos
        s.Orientation = data.rot
        s.Anchored = true
        s.Color = shelterColor
        s.Material = Enum.Material.CorrodedMetal
        s.Parent = props
        -- Support post
        createPart({
            Name = "ShelterPost" .. i,
            Size = Vector3.new(0.4, 3.5, 0.4),
            Position = data.pos + Vector3.new(2.5, -1.2, 0),
            Color = Color3.fromRGB(100, 98, 95),
            Material = Enum.Material.Metal,
            Parent = props,
        })
    end

    -- Razor wire posts: decorative, mark lane edges
    local wirePostColor = Color3.fromRGB(100, 100, 98)
    for i, pos in ipairs({
        Vector3.new(48, 2.5, 25), Vector3.new(48, 2.5, -25),
        Vector3.new(-48, 2.5, 25), Vector3.new(-48, 2.5, -25),
        Vector3.new(25, 2.5, 48), Vector3.new(-25, 2.5, 48),
        Vector3.new(25, 2.5, -48), Vector3.new(-25, 2.5, -48),
    }) do
        createPart({
            Name = "WirePost" .. i,
            Size = Vector3.new(0.3, 5, 0.3),
            Position = pos,
            Color = wirePostColor,
            Material = Enum.Material.Metal,
            Parent = props,
        })
        -- Thin wire between adjacent posts (horizontal bar at top)
        createPart({
            Name = "WireBar" .. i,
            Size = Vector3.new(0.08, 0.08, 3),
            Position = pos + Vector3.new(0, 2.2, 1.5),
            Color = Color3.fromRGB(85, 85, 82),
            Material = Enum.Material.Metal,
            Parent = props,
        })
    end

    local readyPad = createPart({
        Name = "ReadyPad",
        Size = Vector3.new(10, 1, 10),
        Position = Vector3.new(-150, 1.1, 18),
        Color = Color3.fromRGB(160, 185, 165),
        Material = Enum.Material.SmoothPlastic,
        Parent = lobby,
    })
    addLight(lobby, Vector3.new(-150, 3, 18), Color3.fromRGB(200, 230, 210), 0.4, 15)
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

    local function createUpgradeStation(name, pos, upgradeType, baseCost, increment, amount, stationColor)
        local station = createPart({
            Name = name,
            Size = Vector3.new(6, 2.5, 6),
            Position = pos,
            Color = stationColor or Color3.fromRGB(160, 175, 185),
            Material = Enum.Material.SmoothPlastic,
            Parent = upgrades,
        })
        station:SetAttribute("UpgradeType", upgradeType)
        station:SetAttribute("BaseCost", baseCost)
        station:SetAttribute("CostIncrement", increment)
        station:SetAttribute("UpgradeAmount", amount)
        addLight(upgrades, pos + Vector3.new(0, 2, 0), stationColor or Color3.fromRGB(200, 215, 230), 0.5, 14)
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Upgrade"
        prompt.ObjectText = upgradeType
        prompt.MaxActivationDistance = 10
        prompt.RequiresLineOfSight = false
        prompt.Parent = station
    end
    createUpgradeStation("SpeedStation", Vector3.new(12, 1.25, 0), "Speed", 15, 10, 2, Color3.fromRGB(165, 195, 175))
    createUpgradeStation("HealthStation", Vector3.new(-12, 1.25, 0), "Health", 20, 12, 20, Color3.fromRGB(200, 165, 165))
    createUpgradeStation("DamageStation", Vector3.new(0, 1.25, 12), "Damage", 18, 11, 2, Color3.fromRGB(205, 190, 165))

    MapBuilder.applyLightingAndEffects(mapFolder)
    return mapFolder
end

function MapBuilder.applyLightingAndEffects(mapFolder)
    if mapFolder:FindFirstChild("Effects") then
        return
    end

    -- Neutral, well-lit atmosphere
    Lighting.FogEnd = 250
    Lighting.FogStart = 80
    Lighting.FogColor = Color3.fromRGB(180, 185, 195)
    Lighting.Ambient = Color3.fromRGB(145, 150, 160)
    Lighting.OutdoorAmbient = Color3.fromRGB(165, 170, 180)
    Lighting.Brightness = 1.5
    Lighting.GlobalShadows = true
    Lighting.ClockTime = 14
    Lighting.GeographicLatitude = 35

    -- Arena: corner lights and rim glow
    local effectsFolder = Instance.new("Folder")
    effectsFolder.Name = "Effects"
    effectsFolder.Parent = mapFolder

    local arenaLights = Instance.new("Folder")
    arenaLights.Name = "ArenaLights"
    arenaLights.Parent = effectsFolder

    local cornerPositions = {
        Vector3.new(55, 14, -55),
        Vector3.new(-55, 14, -55),
        Vector3.new(55, 14, 55),
        Vector3.new(-55, 14, 55),
    }
    for i, pos in ipairs(cornerPositions) do
        local part = Instance.new("Part")
        part.Name = "LightAnchor" .. i
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.Size = Vector3.new(0.1, 0.1, 0.1)
        part.Position = pos
        part.Parent = arenaLights
        local light = Instance.new("PointLight")
        light.Name = "ArenaLight" .. i
        light.Color = Color3.fromRGB(235, 230, 220)
        light.Brightness = 1.0
        light.Range = 40
        light.Parent = part
    end

    -- Arena center: subtle floating particles (dust/embers)
    local arenaParticles = Instance.new("Part")
    arenaParticles.Name = "ArenaAmbientParticles"
    arenaParticles.Anchored = true
    arenaParticles.CanCollide = false
    arenaParticles.Transparency = 1
    arenaParticles.Size = Vector3.new(100, 20, 100)
    arenaParticles.Position = Vector3.new(0, 8, 0)
    arenaParticles.Parent = effectsFolder

    local dust = Instance.new("ParticleEmitter")
    dust.Name = "Dust"
    dust.Color = ColorSequence.new(Color3.fromRGB(180, 170, 150))
    dust.Size = NumberSequence.new(1.5, 0)
    dust.Transparency = NumberSequence.new(0.6, 1)
    dust.Lifetime = NumberRange.new(4, 6)
    dust.Rate = 12
    dust.Speed = NumberRange.new(0.5, 1.5)
    dust.SpreadAngle = Vector2.new(180, 180)
    dust.LightEmission = 0.4
    dust.Parent = arenaParticles
    local embers = Instance.new("ParticleEmitter")
    embers.Name = "Embers"
    embers.Color = ColorSequence.new(Color3.fromRGB(255, 140, 60))
    embers.Size = NumberSequence.new(0.4, 0)
    embers.Transparency = NumberSequence.new(0.3, 1)
    embers.Lifetime = NumberRange.new(2, 4)
    embers.Rate = 3
    embers.Speed = NumberRange.new(0.3, 0.8)
    embers.SpreadAngle = Vector2.new(180, 180)
    embers.LightEmission = 0.8
    embers.Parent = arenaParticles

    -- Lobby: soft light
    local lobbyLightPart = Instance.new("Part")
    lobbyLightPart.Name = "LobbyLightAnchor"
    lobbyLightPart.Anchored = true
    lobbyLightPart.CanCollide = false
    lobbyLightPart.Transparency = 1
    lobbyLightPart.Size = Vector3.new(0.1, 0.1, 0.1)
    lobbyLightPart.Position = Vector3.new(-150, 10, 0)
    lobbyLightPart.Parent = effectsFolder
    local lobbyLight = Instance.new("PointLight")
    lobbyLight.Color = Color3.fromRGB(235, 238, 245)
    lobbyLight.Brightness = 0.8
    lobbyLight.Range = 50
    lobbyLight.Parent = lobbyLightPart

    -- Wall rim strips (neon accent on arena walls)
    local wallStrips = Instance.new("Folder")
    wallStrips.Name = "WallStrips"
    wallStrips.Parent = effectsFolder
    local wallStripPositions = {
        { pos = Vector3.new(0, 23, -59), size = Vector3.new(118, 0.4, 0.4) },
        { pos = Vector3.new(0, 23, 59), size = Vector3.new(118, 0.4, 0.4) },
        { pos = Vector3.new(59, 23, 0), size = Vector3.new(0.4, 0.4, 118) },
        { pos = Vector3.new(-59, 23, 0), size = Vector3.new(0.4, 0.4, 118) },
    }
    for _, data in ipairs(wallStripPositions) do
        local strip = Instance.new("Part")
        strip.Size = data.size
        strip.Position = data.pos
        strip.Anchored = true
        strip.CanCollide = false
        strip.Material = Enum.Material.Neon
        strip.Color = Color3.fromRGB(200, 195, 185)
        strip.Material = Enum.Material.SmoothPlastic
        strip.Parent = wallStrips
    end
end

return MapBuilder
