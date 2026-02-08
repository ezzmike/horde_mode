local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Modules.EnemyConfig)

local EnemyService = {}

EnemyService.EnemyKilled = Instance.new("BindableEvent")

local STAGGER_DURATION = 0.35

local function findNearestPlayer(position)
    local nearest
    local shortest = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChild("Humanoid")
        if humanoidRoot and humanoid and humanoid.Health > 0 then
            local dist = (humanoidRoot.Position - position).Magnitude
            if dist < shortest then
                shortest = dist
                nearest = player
            end
        end
    end

    return nearest, shortest
end

-- Helper: weld two parts (Part0 at its position, Part1 at offset from Part0)
local function weldParts(part0, part1)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = part0
    weld.Part1 = part1
    weld.Parent = part0
end

local function darker(c, d)
    d = d or 15
    return Color3.fromRGB(
        math.max(0, c.R * 255 - d) / 255,
        math.max(0, c.G * 255 - d) / 255,
        math.max(0, c.B * 255 - d) / 255
    )
end
local function lighter(c, d)
    d = d or 15
    return Color3.fromRGB(
        math.min(255, c.R * 255 + d) / 255,
        math.min(255, c.G * 255 + d) / 255,
        math.min(255, c.B * 255 + d) / 255
    )
end

-- Zombie by type: Shambler = decayed, Runner = lean, Brute = bulky, Infected = standard with torn look
local function createZombieModel(stats)
    local scale = stats.Scale or 1
    local typeName = stats.TypeName or "Shambler"
    local model = Instance.new("Model")
    model.Name = typeName

    -- Type-based proportions and materials
    local torsoW, torsoH, torsoD = 1.2 * scale, 1.4 * scale, 0.6 * scale
    local armW, armL = 0.4 * scale, 1.1 * scale
    local legW, legL = 0.45 * scale, 1.2 * scale
    local headSize = 1.1 * scale
    local skinMat = Enum.Material.SmoothPlastic
    local skinTint = stats.Color
    if typeName == "Brute" then
        torsoW, torsoH, torsoD = 1.5 * scale, 1.5 * scale, 0.75 * scale
        armW, armL = 0.55 * scale, 1.2 * scale
        legW, legL = 0.55 * scale, 1.15 * scale
        headSize = 1.2 * scale
        skinTint = darker(skinTint, 5)
    elseif typeName == "Runner" then
        torsoW, torsoH, torsoD = 1.0 * scale, 1.35 * scale, 0.5 * scale
        armW, armL = 0.35 * scale, 1.05 * scale
        legW, legL = 0.4 * scale, 1.25 * scale
        headSize = 1.0 * scale
    elseif typeName == "Shambler" then
        skinMat = Enum.Material.Plastic
        skinTint = darker(skinTint, 10)
    end

    -- HumanoidRootPart (pelvis)
    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(1 * scale, 0.5 * scale, 0.5 * scale)
    root.Color = darker(skinTint, 12)
    root.Material = skinMat
    root.Anchored = false
    root.CanCollide = true
    root.Parent = model

    -- Torso
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(torsoW, torsoH, torsoD)
    torso.Color = darker(skinTint, 8)
    torso.Material = skinMat
    torso.CFrame = root.CFrame * CFrame.new(0, 0.95 * scale, 0)
    torso.Parent = model
    weldParts(root, torso)

    -- Optional torn shirt/vest (Infected, Shambler)
    if typeName == "Infected" or typeName == "Shambler" then
        local shirt = Instance.new("Part")
        shirt.Name = "Shirt"
        shirt.Size = Vector3.new(torsoW * 1.05, torsoH * 0.5, torsoD * 1.05)
        shirt.Color = typeName == "Shambler" and Color3.fromRGB(50, 55, 48) or Color3.fromRGB(55, 60, 52)
        shirt.Material = Enum.Material.Fabric
        shirt.CFrame = torso.CFrame * CFrame.new(0, 0.15 * scale, 0)
        shirt.CanCollide = false
        shirt.Parent = model
        weldParts(torso, shirt)
    end
    -- Brute: shoulder/chest bulk
    if typeName == "Brute" then
        local bulk = Instance.new("Part")
        bulk.Name = "Bulk"
        bulk.Size = Vector3.new(torsoW * 0.9, torsoH * 0.4, torsoD * 1.1)
        bulk.Color = darker(skinTint, 15)
        bulk.Material = Enum.Material.Plastic
        bulk.CFrame = torso.CFrame * CFrame.new(0, 0.2 * scale, 0)
        bulk.CanCollide = false
        bulk.Parent = model
        weldParts(torso, bulk)
    end

    -- Neck (short cylinder)
    local neck = Instance.new("Part")
    neck.Name = "Neck"
    neck.Shape = Enum.PartType.Cylinder
    neck.Size = Vector3.new(0.2 * scale, 0.25 * scale, 0.25 * scale)
    neck.Orientation = Vector3.new(0, 0, 90)
    neck.Color = darker(skinTint, 5)
    neck.Material = skinMat
    neck.CFrame = torso.CFrame * CFrame.new(0, torsoH/2 + 0.15 * scale, 0)
    neck.CanCollide = false
    neck.Parent = model
    weldParts(torso, neck)

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(headSize, headSize, headSize)
    head.Color = lighter(skinTint, 12)
    head.Material = skinMat
    head.CFrame = neck.CFrame * CFrame.new(0, 0.28 * scale, 0)
    head.Parent = model
    weldParts(neck, head)
    local eyeLight = Instance.new("PointLight")
    eyeLight.Name = "EyeGlow"
    eyeLight.Color = Color3.fromRGB(180, 40, 30)
    eyeLight.Brightness = typeName == "Brute" and 0.6 or 0.4
    eyeLight.Range = 1.5
    eyeLight.Parent = head
    -- Jaw / mouth (all types)
    local jaw = Instance.new("Part")
    jaw.Name = "Jaw"
    jaw.Size = Vector3.new(headSize * 0.5, headSize * 0.25, headSize * 0.4)
    jaw.Color = darker(skinTint, 5)
    jaw.Material = skinMat
    jaw.CFrame = head.CFrame * CFrame.new(0, -0.2 * scale, 0.25 * scale)
    jaw.CanCollide = false
    jaw.Parent = model
    weldParts(head, jaw)

    -- Arms with shoulder cap
    local leftArm = Instance.new("Part")
    leftArm.Name = "LeftArm"
    leftArm.Size = Vector3.new(armW, armL, armW)
    leftArm.Color = torso.Color
    leftArm.Material = skinMat
    leftArm.CFrame = torso.CFrame * CFrame.new(-(torsoW/2 + armW/2) * 0.9, 0.1 * scale, 0.15 * scale)
    leftArm.Parent = model
    weldParts(torso, leftArm)
    local leftShoulder = Instance.new("Part")
    leftShoulder.Name = "LeftShoulder"
    leftShoulder.Size = Vector3.new(armW * 1.4, armW * 0.6, armW * 1.2)
    leftShoulder.Color = darker(torso.Color, 8)
    leftShoulder.Material = skinMat
    leftShoulder.CFrame = leftArm.CFrame * CFrame.new(0, armL/2, 0)
    leftShoulder.CanCollide = false
    leftShoulder.Parent = model
    weldParts(leftArm, leftShoulder)

    local rightArm = Instance.new("Part")
    rightArm.Name = "RightArm"
    rightArm.Size = Vector3.new(armW, armL, armW)
    rightArm.Color = torso.Color
    rightArm.Material = skinMat
    rightArm.CFrame = torso.CFrame * CFrame.new((torsoW/2 + armW/2) * 0.9, 0.1 * scale, 0.15 * scale)
    rightArm.Parent = model
    weldParts(torso, rightArm)
    local rightShoulder = Instance.new("Part")
    rightShoulder.Name = "RightShoulder"
    rightShoulder.Size = Vector3.new(armW * 1.4, armW * 0.6, armW * 1.2)
    rightShoulder.Color = darker(torso.Color, 8)
    rightShoulder.Material = skinMat
    rightShoulder.CFrame = rightArm.CFrame * CFrame.new(0, armL/2, 0)
    rightShoulder.CanCollide = false
    rightShoulder.Parent = model
    weldParts(rightArm, rightShoulder)

    -- Legs with feet
    local legColor = darker(skinTint, 12)
    local leftLeg = Instance.new("Part")
    leftLeg.Name = "Left Leg"
    leftLeg.Size = Vector3.new(legW, legL, legW)
    leftLeg.Color = legColor
    leftLeg.Material = skinMat
    leftLeg.CFrame = root.CFrame * CFrame.new(-0.25 * scale, -0.85 * scale, 0)
    leftLeg.Parent = model
    weldParts(root, leftLeg)
    local leftFoot = Instance.new("Part")
    leftFoot.Name = "LeftFoot"
    leftFoot.Size = Vector3.new(legW * 1.2, legW * 0.4, legW * 1.4)
    leftFoot.Color = darker(legColor, 5)
    leftFoot.Material = skinMat
    leftFoot.CFrame = leftLeg.CFrame * CFrame.new(0, -legL/2 - 0.1 * scale, 0.05 * scale)
    leftFoot.CanCollide = false
    leftFoot.Parent = model
    weldParts(leftLeg, leftFoot)

    local rightLeg = Instance.new("Part")
    rightLeg.Name = "Right Leg"
    rightLeg.Size = Vector3.new(legW, legL, legW)
    rightLeg.Color = legColor
    rightLeg.Material = skinMat
    rightLeg.CFrame = root.CFrame * CFrame.new(0.25 * scale, -0.85 * scale, 0)
    rightLeg.Parent = model
    weldParts(root, rightLeg)
    local rightFoot = Instance.new("Part")
    rightFoot.Name = "RightFoot"
    rightFoot.Size = Vector3.new(legW * 1.2, legW * 0.4, legW * 1.4)
    rightFoot.Color = darker(legColor, 5)
    rightFoot.Material = skinMat
    rightFoot.CFrame = rightLeg.CFrame * CFrame.new(0, -legL/2 - 0.1 * scale, 0.05 * scale)
    rightFoot.CanCollide = false
    rightFoot.Parent = model
    weldParts(rightLeg, rightFoot)
    -- Wound / blood patch (Shambler, Infected)
    if typeName == "Shambler" or typeName == "Infected" then
        local wound = Instance.new("Part")
        wound.Name = "Wound"
        wound.Size = Vector3.new(torsoW * 0.35, torsoH * 0.2, torsoD * 0.6)
        wound.Color = Color3.fromRGB(55, 35, 35)
        wound.Material = Enum.Material.SmoothPlastic
        wound.CFrame = torso.CFrame * CFrame.new(0.2 * scale, -0.1 * scale, 0)
        wound.CanCollide = false
        wound.Parent = model
        weldParts(torso, wound)
    end

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = stats.Health
    humanoid.Health = stats.Health
    humanoid.WalkSpeed = stats.WalkSpeed
    humanoid.HipHeight = 0.5 * scale
    humanoid.Parent = model

    model.PrimaryPart = root
    return model, humanoid
end

local function createDeathParticles(position)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(1, 1, 1)
    part.Position = position
    part.Parent = workspace

    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.fromRGB(90, 80, 70))
    particles.Size = NumberSequence.new(0.25, 0)
    particles.Transparency = NumberSequence.new(0.2, 1)
    particles.Lifetime = NumberRange.new(0.3, 0.5)
    particles.Rate = 40
    particles.Speed = NumberRange.new(3, 7)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Parent = part
    particles:Emit(20)
    task.delay(1.2, function()
        part:Destroy()
    end)
end

function EnemyService.spawnEnemy(stats, position, parent)
    local model, humanoid = createZombieModel(stats)
    model:SetAttribute("Damage", stats.Damage)
    model:SetAttribute("Reward", stats.Reward)
    model:SetAttribute("AttackRange", stats.AttackRange)
    model:SetAttribute("AttackCooldown", stats.AttackCooldown)
    model:SetAttribute("IsEnemy", true)

    model.Parent = parent
    -- Place root (pelvis) so feet sit on the ground
    model:SetPrimaryPartCFrame(CFrame.new(position + Vector3.new(0, 1.2 * (stats.Scale or 1), 0)))

    local lastAttack = 0

    humanoid.Died:Connect(function()
        local root = model.PrimaryPart
        if root then
            createDeathParticles(root.Position)
        end
        EnemyService.EnemyKilled:Fire(stats.Reward)
        task.delay(0.25, function()
            if model.Parent then
                model:Destroy()
            end
        end)
    end)

    -- Stagger when hit: brief pause so shots feel impactful
    humanoid.HealthChanged:Connect(function()
        if humanoid.Health > 0 then
            model:SetAttribute("StaggerUntil", os.clock() + STAGGER_DURATION)
        end
    end)

    task.spawn(function()
        while humanoid.Health > 0 do
            local root = model.PrimaryPart
            if not root or not model.Parent then
                break
            end
            local staggerUntil = model:GetAttribute("StaggerUntil") or 0
            local now = os.clock()
            local targetPlayer, distance = findNearestPlayer(root.Position)

            if targetPlayer and targetPlayer.Character and now >= staggerUntil then
                humanoid:MoveTo(targetPlayer.Character.HumanoidRootPart.Position)

                if distance <= stats.AttackRange then
                    if now - lastAttack >= stats.AttackCooldown then
                        lastAttack = now
                        local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
                        if targetHumanoid then
                            targetHumanoid:TakeDamage(stats.Damage)
                        end
                    end
                end
            end

            task.wait(0.25)
        end
    end)

    return model
end

function EnemyService.killAllEnemies(enemyFolder)
    if not enemyFolder then
        return
    end
    for _, model in ipairs(enemyFolder:GetChildren()) do
        if model:IsA("Model") then
            local humanoid = model:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end
    end
end

return EnemyService
