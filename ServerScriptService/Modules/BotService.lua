local Workspace = game:GetService("Workspace")

local BotService = {}

local botsFolder
local arenaSpawns
local enemyFolder
local botConfig
local remotesRef
local botCounter = 0

local function ensureBotsFolder()
    if botsFolder then
        return botsFolder
    end
    botsFolder = Workspace:FindFirstChild("AlliedBots")
    if not botsFolder then
        botsFolder = Instance.new("Folder")
        botsFolder.Name = "AlliedBots"
        botsFolder.Parent = Workspace
    end
    return botsFolder
end

local function getStats()
    local defaults = {
        Health = 120,
        WalkSpeed = 15,
        Damage = 10,
        AttackRange = 5,
        AttackCooldown = 1.0,
    }
    if botConfig and botConfig.Stats then
        for key, value in pairs(botConfig.Stats) do
            defaults[key] = value
        end
    end
    return defaults
end

local function findNearestEnemy(position)
    if not enemyFolder then
        return nil, math.huge
    end

    local nearest = nil
    local shortest = math.huge

    for _, model in ipairs(enemyFolder:GetChildren()) do
        if model:IsA("Model") and model:GetAttribute("IsEnemy") then
            local root = model:FindFirstChild("HumanoidRootPart")
            local humanoid = model:FindFirstChild("Humanoid")
            if root and humanoid and humanoid.Health > 0 then
                local dist = (root.Position - position).Magnitude
                if dist < shortest then
                    shortest = dist
                    nearest = model
                end
            end
        end
    end

    return nearest, shortest
end

-- Tactical allied bot: helmet, vest, visor glow, military look
local function createBotModel(stats)
    local model = Instance.new("Model")
    model.Name = "AlliedBot"
    model:SetAttribute("IsBot", true)

    local vestColor = Color3.fromRGB(45, 75, 55)   -- tactical green
    local armorColor = Color3.fromRGB(55, 60, 65)  -- dark gray plates
    local limbColor = Color3.fromRGB(50, 55, 60)   -- under-suit
    local helmetColor = Color3.fromRGB(48, 72, 52)
    local visorColor = Color3.fromRGB(80, 180, 255)

    local function weldParts(part0, part1)
        local w = Instance.new("WeldConstraint")
        w.Part0 = part0
        w.Part1 = part1
        w.Parent = part0
    end

    -- HumanoidRootPart (pelvis)
    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(1, 0.5, 0.5)
    root.Color = limbColor
    root.Material = Enum.Material.SmoothPlastic
    root.Anchored = false
    root.CanCollide = true
    root.Parent = model

    -- Torso (base)
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(1.2, 1.4, 0.6)
    torso.Color = vestColor
    torso.Material = Enum.Material.SmoothPlastic
    torso.CFrame = root.CFrame * CFrame.new(0, 0.95, 0)
    torso.Parent = model
    weldParts(root, torso)

    -- Tactical vest (chest plate)
    local vest = Instance.new("Part")
    vest.Name = "Vest"
    vest.Size = Vector3.new(1.12, 0.95, 0.52)
    vest.Color = armorColor
    vest.Material = Enum.Material.Metal
    vest.CFrame = torso.CFrame * CFrame.new(0, 0.08, 0)
    vest.CanCollide = false
    vest.Parent = model
    weldParts(torso, vest)
    -- Vest pouches
    local pouchL = Instance.new("Part")
    pouchL.Name = "PouchL"
    pouchL.Size = Vector3.new(0.25, 0.2, 0.15)
    pouchL.Color = Color3.fromRGB(42, 58, 48)
    pouchL.Material = Enum.Material.Fabric
    pouchL.CFrame = vest.CFrame * CFrame.new(-0.35, 0.1, 0.15)
    pouchL.CanCollide = false
    pouchL.Parent = model
    weldParts(vest, pouchL)
    local pouchR = Instance.new("Part")
    pouchR.Name = "PouchR"
    pouchR.Size = Vector3.new(0.25, 0.2, 0.15)
    pouchR.Color = Color3.fromRGB(42, 58, 48)
    pouchR.Material = Enum.Material.Fabric
    pouchR.CFrame = vest.CFrame * CFrame.new(0.35, 0.1, 0.15)
    pouchR.CanCollide = false
    pouchR.Parent = model
    weldParts(vest, pouchR)

    -- Neck
    local neck = Instance.new("Part")
    neck.Name = "Neck"
    neck.Shape = Enum.PartType.Cylinder
    neck.Size = Vector3.new(0.18, 0.22, 0.22)
    neck.Orientation = Vector3.new(0, 0, 90)
    neck.Color = limbColor
    neck.Material = Enum.Material.SmoothPlastic
    neck.CFrame = torso.CFrame * CFrame.new(0, 0.85, 0)
    neck.CanCollide = false
    neck.Parent = model
    weldParts(torso, neck)

    -- Head (under helmet)
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.0, 1.0, 1.0)
    head.Color = Color3.fromRGB(95, 80, 75)
    head.Material = Enum.Material.SmoothPlastic
    head.CFrame = neck.CFrame * CFrame.new(0, 0.28, 0)
    head.Parent = model
    weldParts(neck, head)

    -- Helmet (rounded cap over head)
    local helmet = Instance.new("Part")
    helmet.Name = "Helmet"
    helmet.Shape = Enum.PartType.Ball
    helmet.Size = Vector3.new(1.08, 1.08, 1.08)
    helmet.Color = helmetColor
    helmet.Material = Enum.Material.SmoothPlastic
    helmet.CFrame = head.CFrame
    helmet.CanCollide = false
    helmet.Parent = model
    weldParts(head, helmet)

    -- Visor (glow strip)
    local visor = Instance.new("Part")
    visor.Name = "Visor"
    visor.Size = Vector3.new(0.6, 0.08, 1.02)
    visor.Color = visorColor
    visor.Material = Enum.Material.Neon
    visor.CFrame = helmet.CFrame * CFrame.new(0, 0.15, 0)
    visor.CanCollide = false
    visor.Parent = model
    weldParts(helmet, visor)
    local faceLight = Instance.new("PointLight")
    faceLight.Name = "VisorLight"
    faceLight.Color = visorColor
    faceLight.Brightness = 0.35
    faceLight.Range = 2.5
    faceLight.Parent = helmet
    -- Earpiece
    local earpiece = Instance.new("Part")
    earpiece.Name = "Earpiece"
    earpiece.Size = Vector3.new(0.15, 0.12, 0.2)
    earpiece.Color = Color3.fromRGB(45, 48, 52)
    earpiece.Material = Enum.Material.SmoothPlastic
    earpiece.CFrame = helmet.CFrame * CFrame.new(-0.52, 0.05, 0)
    earpiece.CanCollide = false
    earpiece.Parent = model
    weldParts(helmet, earpiece)

    -- Arms with shoulder pads
    local leftArm = Instance.new("Part")
    leftArm.Name = "Left Arm"
    leftArm.Size = Vector3.new(0.38, 1.05, 0.38)
    leftArm.Color = limbColor
    leftArm.Material = Enum.Material.SmoothPlastic
    leftArm.CFrame = torso.CFrame * CFrame.new(-0.72, 0.08, 0.14)
    leftArm.Parent = model
    weldParts(torso, leftArm)
    local leftPad = Instance.new("Part")
    leftPad.Name = "LeftPad"
    leftPad.Size = Vector3.new(0.5, 0.22, 0.35)
    leftPad.Color = armorColor
    leftPad.Material = Enum.Material.Metal
    leftPad.CFrame = leftArm.CFrame * CFrame.new(0, 0.55, 0)
    leftPad.CanCollide = false
    leftPad.Parent = model
    weldParts(leftArm, leftPad)

    local rightArm = Instance.new("Part")
    rightArm.Name = "Right Arm"
    rightArm.Size = Vector3.new(0.38, 1.05, 0.38)
    rightArm.Color = limbColor
    rightArm.Material = Enum.Material.SmoothPlastic
    rightArm.CFrame = torso.CFrame * CFrame.new(0.72, 0.08, 0.14)
    rightArm.Parent = model
    weldParts(torso, rightArm)
    local rightPad = Instance.new("Part")
    rightPad.Name = "RightPad"
    rightPad.Size = Vector3.new(0.5, 0.22, 0.35)
    rightPad.Color = armorColor
    rightPad.Material = Enum.Material.Metal
    rightPad.CFrame = rightArm.CFrame * CFrame.new(0, 0.55, 0)
    rightPad.CanCollide = false
    rightPad.Parent = model
    weldParts(rightArm, rightPad)

    -- Belt
    local belt = Instance.new("Part")
    belt.Name = "Belt"
    belt.Size = Vector3.new(1.0, 0.12, 0.5)
    belt.Color = Color3.fromRGB(40, 42, 45)
    belt.Material = Enum.Material.SmoothPlastic
    belt.CFrame = torso.CFrame * CFrame.new(0, -0.55, 0)
    belt.CanCollide = false
    belt.Parent = model
    weldParts(torso, belt)

    -- Legs (tactical boots + kneepads)
    local leftLeg = Instance.new("Part")
    leftLeg.Name = "Left Leg"
    leftLeg.Size = Vector3.new(0.42, 1.15, 0.42)
    leftLeg.Color = limbColor
    leftLeg.Material = Enum.Material.SmoothPlastic
    leftLeg.CFrame = root.CFrame * CFrame.new(-0.24, -0.82, 0)
    leftLeg.Parent = model
    weldParts(root, leftLeg)
    local leftKnee = Instance.new("Part")
    leftKnee.Name = "LeftKnee"
    leftKnee.Size = Vector3.new(0.4, 0.2, 0.38)
    leftKnee.Color = armorColor
    leftKnee.Material = Enum.Material.Metal
    leftKnee.CFrame = leftLeg.CFrame * CFrame.new(0, 0.35, 0.02)
    leftKnee.CanCollide = false
    leftKnee.Parent = model
    weldParts(leftLeg, leftKnee)
    local leftBoot = Instance.new("Part")
    leftBoot.Name = "LeftBoot"
    leftBoot.Size = Vector3.new(0.44, 0.2, 0.5)
    leftBoot.Color = Color3.fromRGB(35, 38, 40)
    leftBoot.Material = Enum.Material.SmoothPlastic
    leftBoot.CFrame = leftLeg.CFrame * CFrame.new(0, -0.6, 0.03)
    leftBoot.CanCollide = false
    leftBoot.Parent = model
    weldParts(leftLeg, leftBoot)

    local rightLeg = Instance.new("Part")
    rightLeg.Name = "Right Leg"
    rightLeg.Size = Vector3.new(0.42, 1.15, 0.42)
    rightLeg.Color = limbColor
    rightLeg.Material = Enum.Material.SmoothPlastic
    rightLeg.CFrame = root.CFrame * CFrame.new(0.24, -0.82, 0)
    rightLeg.Parent = model
    weldParts(root, rightLeg)
    local rightKnee = Instance.new("Part")
    rightKnee.Name = "RightKnee"
    rightKnee.Size = Vector3.new(0.4, 0.2, 0.38)
    rightKnee.Color = armorColor
    rightKnee.Material = Enum.Material.Metal
    rightKnee.CFrame = rightLeg.CFrame * CFrame.new(0, 0.35, 0.02)
    rightKnee.CanCollide = false
    rightKnee.Parent = model
    weldParts(rightLeg, rightKnee)
    local rightBoot = Instance.new("Part")
    rightBoot.Name = "RightBoot"
    rightBoot.Size = Vector3.new(0.44, 0.2, 0.5)
    rightBoot.Color = Color3.fromRGB(35, 38, 40)
    rightBoot.Material = Enum.Material.SmoothPlastic
    rightBoot.CFrame = rightLeg.CFrame * CFrame.new(0, -0.6, 0.03)
    rightBoot.CanCollide = false
    rightBoot.Parent = model
    weldParts(rightLeg, rightBoot)

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = stats.Health
    humanoid.Health = stats.Health
    humanoid.WalkSpeed = stats.WalkSpeed
    humanoid.HipHeight = 0.5
    humanoid.Parent = model

    model.PrimaryPart = root

    return model, humanoid
end

local function spawnBot()
    local spawns = arenaSpawns and arenaSpawns:GetChildren() or {}
    if #spawns == 0 then
        return nil
    end

    local stats = getStats()
    local model, humanoid = createBotModel(stats)
    botCounter += 1
    model.Name = "AlliedBot_" .. tostring(botCounter)

    local spawn = spawns[math.random(1, #spawns)]
    model.Parent = ensureBotsFolder()
    model:SetPrimaryPartCFrame(spawn.CFrame + Vector3.new(0, 1.2, 0))

    task.spawn(function()
        local lastAttack = 0
        while humanoid.Health > 0 do
            local rootPart = model:FindFirstChild("HumanoidRootPart")
            if rootPart then
            local target, distance = findNearestEnemy(rootPart.Position)
            local targetRoot = target and target.PrimaryPart
            if target and targetRoot then
                local targetPos = targetRoot.Position
                humanoid:MoveTo(targetPos)
                if distance <= stats.AttackRange then
                    local now = os.clock()
                    if now - lastAttack >= stats.AttackCooldown then
                        lastAttack = now
                        local targetHumanoid = target:FindFirstChild("Humanoid")
                        local hrp = target.PrimaryPart
                        if targetHumanoid and hrp then
                            target:SetAttribute("LastHitByName", "AlliedBot")
                            targetHumanoid:TakeDamage(stats.Damage)
                            -- Slash effect + sound for all clients
                            if remotesRef then
                                local rootPart = model:FindFirstChild("HumanoidRootPart")
                                if rootPart then
                                    local look = (hrp.Position - rootPart.Position).Unit
                                    local origin = rootPart.Position + look * 2
                                    if remotesRef.WeaponEffect then
                                        remotesRef.WeaponEffect:FireAllClients(origin, look, "Sword", { hrp.Position }, true)
                                    end
                                    if remotesRef.PlaySound then
                                        remotesRef.PlaySound:FireAllClients("WeaponMelee")
                                    end
                                end
                            end
                        end
                    end
                end
            end
            end
            task.wait(0.3)
        end
        if model.Parent then
            model:Destroy()
        end
    end)

    return model
end

function BotService.init(spawns, enemyFolderRef, config, remotes)
    arenaSpawns = spawns
    enemyFolder = enemyFolderRef
    botConfig = config
    remotesRef = remotes
    ensureBotsFolder()
end

function BotService.getAliveBots()
    local bots = {}
    if not botsFolder then
        return bots
    end

    for _, bot in ipairs(botsFolder:GetChildren()) do
        local humanoid = bot:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            table.insert(bots, bot)
        end
    end
    return bots
end

function BotService.clearBots()
    if not botsFolder then
        return
    end
    for _, bot in ipairs(botsFolder:GetChildren()) do
        bot:Destroy()
    end
end

function BotService.syncBotsForPlayerCount(playerCount)
    local scale = botConfig and botConfig.Scale or 0
    local minBots = botConfig and botConfig.Min or 0
    local maxBots = botConfig and botConfig.Max or 0
    local singlePlayerTeammates = botConfig and botConfig.SinglePlayerTeammates or 0

    local desired = math.floor(playerCount * scale)
    -- Single player: ensure at least SinglePlayerTeammates AI teammates to assist
    if playerCount == 1 and singlePlayerTeammates > 0 then
        desired = math.max(desired, singlePlayerTeammates)
    end
    desired = math.clamp(desired, minBots, maxBots)

    local current = botsFolder and #botsFolder:GetChildren() or 0

    if current < desired then
        for _ = 1, (desired - current) do
            spawnBot()
        end
    elseif current > desired then
        local bots = botsFolder:GetChildren()
        for i = 1, (current - desired) do
            local bot = bots[i]
            if bot then
                bot:Destroy()
            end
        end
    end
end

return BotService
