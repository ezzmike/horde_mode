local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Modules.EnemyConfig)

local EnemyService = {}

EnemyService.EnemyKilled = Instance.new("BindableEvent")

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

local function createEnemyModel(stats)
    local model = Instance.new("Model")
    model.Name = "Enemy"

    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(3, 3, 3)
    root.Color = stats.Color
    root.Material = Enum.Material.Metal
    root.Anchored = false
    root.CanCollide = true
    root.Parent = model

    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(4, 4, 2)
    body.Color = stats.Color
    body.Material = Enum.Material.Metal
    body.Anchored = false
    body.CanCollide = true
    body.Parent = model

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = body
    weld.Parent = root

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = stats.Health
    humanoid.Health = stats.Health
    humanoid.WalkSpeed = stats.WalkSpeed
    humanoid.Parent = model

    model.PrimaryPart = root

    return model, humanoid
end

function EnemyService.spawnEnemy(stats, position, parent)
    local model, humanoid = createEnemyModel(stats)
    model:SetAttribute("Damage", stats.Damage)
    model:SetAttribute("Reward", stats.Reward)
    model:SetAttribute("AttackRange", stats.AttackRange)
    model:SetAttribute("AttackCooldown", stats.AttackCooldown)
    model:SetAttribute("IsEnemy", true)

    model.Parent = parent
    model:SetPrimaryPartCFrame(CFrame.new(position + Vector3.new(0, 3, 0)))

    local lastAttack = 0

    humanoid.Died:Connect(function()
        EnemyService.EnemyKilled:Fire(stats.Reward)
        task.delay(0.2, function()
            model:Destroy()
        end)
    end)

    task.spawn(function()
        while humanoid.Health > 0 do
            local targetPlayer, distance = findNearestPlayer(model.PrimaryPart.Position)
            if targetPlayer and targetPlayer.Character then
                humanoid:MoveTo(targetPlayer.Character.HumanoidRootPart.Position)

                if distance <= stats.AttackRange then
                    local now = os.clock()
                    if now - lastAttack >= stats.AttackCooldown then
                        lastAttack = now
                        local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
                        if targetHumanoid then
                            targetHumanoid:TakeDamage(stats.Damage)
                        end
                    end
                end
            end
            task.wait(0.3)
        end
    end)

    return model
end

return EnemyService
