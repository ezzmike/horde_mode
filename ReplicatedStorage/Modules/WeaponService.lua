local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Modules.Constants)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local WeaponService = {}
local lastAttackByPlayer = {}
local lastCameraShotByPlayer = {}
local pendingGunFallbackByPlayer = {}
local remotesRef
local toolCache = {}

local function normalizeWeaponId(id)
    if type(id) ~= "string" then
        return nil
    end
    if WeaponConfig.Weapons[id] then
        return id
    end
    for _, candidate in ipairs(WeaponConfig.Order or {}) do
        if string.lower(candidate) == string.lower(id) then
            return candidate
        end
    end
    local byDisplay = WeaponConfig.getWeaponIdFromDisplayName and WeaponConfig.getWeaponIdFromDisplayName(id)
    if byDisplay and WeaponConfig.Weapons[byDisplay] then
        return byDisplay
    end
    return nil
end

-- Returns model, humanoid, hitPart (the part that was hit, for headshot detection)
local function getEnemyModelFromPart(part)
    local current = part
    for _ = 1, 10 do
        if not current then
            return nil, nil, nil
        end
        if current:IsA("Model") and current:GetAttribute("IsEnemy") then
            local humanoid = current:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                return current, humanoid, part
            end
            return nil, nil, nil
        end
        current = current.Parent
    end
    return nil, nil, nil
end

-- Offset so barrel/forward points away from player (Roblox tool grip has +Z behind). flipY true = knife (blade along Y).
local function forwardOffset(x, y, z, flipY)
    if flipY then
        return Vector3.new(x, -y, z)
    end
    return Vector3.new(-x, y, -z)
end

local function weldPart(handle, part, offset)
    part.CFrame = handle.CFrame * CFrame.new(offset)
    part.Parent = handle.Parent
    local w = Instance.new("WeldConstraint")
    w.Part0 = handle
    w.Part1 = part
    w.Parent = handle
end

-- Weld with full CFrame (position + rotation). Use flipY=true for knife so blade points forward.
local function weldPartCFrame(handle, part, relativeCFrame, flipY)
    if flipY then
        relativeCFrame = relativeCFrame * CFrame.Angles(0, 0, math.rad(180))
    else
        relativeCFrame = relativeCFrame * CFrame.Angles(0, math.rad(180), 0)
    end
    part.CFrame = handle.CFrame * relativeCFrame
    part.Parent = handle.Parent
    local w = Instance.new("WeldConstraint")
    w.Part0 = handle
    w.Part1 = part
    w.Parent = handle
end

local function createPartInTool(parent, name, size, color, material, offset)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = false
    p.CanCollide = false
    p.Parent = parent
    return p
end

local function createToolForWeapon(weaponId)
    local config = WeaponConfig.Weapons[weaponId]
    if not config then
        config = WeaponConfig.Weapons.Sword
        weaponId = "Sword"
    end

    local tool = Instance.new("Tool")
    tool.Name = config.DisplayName or weaponId
    tool.CanBeDropped = false
    tool.RequiresHandle = true
    tool:SetAttribute("WeaponId", weaponId)

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = config.Size or Vector3.new(0.5, 1.4, 0.3)
    handle.Color = config.Color or Color3.fromRGB(90, 60, 40)
    handle.Material = Enum.Material.SmoothPlastic
    handle.Anchored = false
    handle.CanCollide = false
    handle.Parent = tool

    if weaponId == "Sword" then
        -- Combat knife (flipY so blade points forward)
        local pommel = createPartInTool(tool, "Pommel", Vector3.new(0.28, 0.2, 0.28), Color3.fromRGB(82, 78, 74), Enum.Material.Metal)
        weldPart(handle, pommel, forwardOffset(0, -0.58, 0, true))
        local grip = createPartInTool(tool, "Grip", Vector3.new(0.3, 0.8, 0.3), Color3.fromRGB(48, 44, 40), Enum.Material.SmoothPlastic)
        weldPart(handle, grip, forwardOffset(0, -0.4, 0, true))
        local groove1 = createPartInTool(tool, "Groove1", Vector3.new(0.26, 0.1, 0.26), Color3.fromRGB(40, 36, 33), Enum.Material.SmoothPlastic)
        weldPart(handle, groove1, forwardOffset(0, -0.54, 0, true))
        local groove2 = createPartInTool(tool, "Groove2", Vector3.new(0.26, 0.1, 0.26), Color3.fromRGB(40, 36, 33), Enum.Material.SmoothPlastic)
        weldPart(handle, groove2, forwardOffset(0, -0.32, 0, true))
        local guard = createPartInTool(tool, "Guard", Vector3.new(0.46, 0.05, 0.13), Color3.fromRGB(86, 84, 80), Enum.Material.Metal)
        weldPart(handle, guard, forwardOffset(0, 0.16, 0, true))
        local choil = createPartInTool(tool, "Choil", Vector3.new(0.08, 0.08, 0.12), Color3.fromRGB(170, 174, 178), Enum.Material.Metal)
        weldPart(handle, choil, forwardOffset(0, 0.42, 0, true))
        local ricasso = createPartInTool(tool, "Ricasso", Vector3.new(0.09, 0.26, 0.3), Color3.fromRGB(182, 186, 190), Enum.Material.Metal)
        weldPart(handle, ricasso, forwardOffset(0, 0.54, 0, true))
        local fuller = createPartInTool(tool, "Fuller", Vector3.new(0.02, 0.9, 0.12), Color3.fromRGB(140, 144, 148), Enum.Material.Metal)
        weldPart(handle, fuller, forwardOffset(0, 1.0, 0, true))
        local blade = createPartInTool(tool, "Blade", Vector3.new(0.05, 1.1, 0.3), Color3.fromRGB(195, 200, 204), Enum.Material.Metal)
        weldPart(handle, blade, forwardOffset(0, 1.04, 0, true))
        local spine = createPartInTool(tool, "Spine", Vector3.new(0.03, 1.06, 0.26), Color3.fromRGB(172, 176, 180), Enum.Material.Metal)
        weldPart(handle, spine, forwardOffset(0, 1.04, 0, true))
        local edge = createPartInTool(tool, "Edge", Vector3.new(0.015, 1.04, 0.28), Color3.fromRGB(115, 118, 122), Enum.Material.Metal)
        weldPart(handle, edge, forwardOffset(0, 1.04, -0.12, true))
        local tip = createPartInTool(tool, "Tip", Vector3.new(0.04, 0.18, 0.26), Color3.fromRGB(188, 192, 196), Enum.Material.Metal)
        weldPart(handle, tip, forwardOffset(0, 1.58, 0, true))
    elseif weaponId == "Pistol" then
        -- Compact pistol: receiver + slide + barrel + grip + magazine
        local receiver = createPartInTool(tool, "Receiver", Vector3.new(0.3, 0.22, 0.7), Color3.fromRGB(60, 58, 56), Enum.Material.Metal)
        weldPart(handle, receiver, forwardOffset(0, 0.08, 0.32))
        local slide = createPartInTool(tool, "Slide", Vector3.new(0.28, 0.16, 0.78), Color3.fromRGB(52, 50, 48), Enum.Material.Metal)
        weldPart(handle, slide, forwardOffset(0, 0.18, 0.34))
        local barrel = createPartInTool(tool, "Barrel", Vector3.new(0.12, 0.12, 0.55), Color3.fromRGB(45, 43, 41), Enum.Material.Metal)
        weldPart(handle, barrel, forwardOffset(0, 0.14, 0.78))
        local muzzle = createPartInTool(tool, "Muzzle", Vector3.new(0.14, 0.14, 0.08), Color3.fromRGB(40, 38, 36), Enum.Material.Metal)
        weldPart(handle, muzzle, forwardOffset(0, 0.14, 1.08))
        local grip = createPartInTool(tool, "Grip", Vector3.new(0.3, 0.55, 0.32), Color3.fromRGB(38, 36, 34), Enum.Material.SmoothPlastic)
        weldPart(handle, grip, forwardOffset(0, -0.3, 0.02))
        local triggerGuard = createPartInTool(tool, "TriggerGuard", Vector3.new(0.2, 0.07, 0.28), Color3.fromRGB(55, 53, 51), Enum.Material.Metal)
        weldPart(handle, triggerGuard, forwardOffset(0, -0.04, 0.2))
        local trigger = createPartInTool(tool, "Trigger", Vector3.new(0.06, 0.1, 0.16), Color3.fromRGB(45, 43, 41), Enum.Material.Metal)
        weldPart(handle, trigger, forwardOffset(0, -0.02, 0.2))
        local magazine = createPartInTool(tool, "Magazine", Vector3.new(0.18, 0.32, 0.22), Color3.fromRGB(52, 50, 48), Enum.Material.Metal)
        weldPart(handle, magazine, forwardOffset(0, -0.42, 0.02))
        local frontSight = createPartInTool(tool, "FrontSight", Vector3.new(0.05, 0.06, 0.04), Color3.fromRGB(70, 68, 66), Enum.Material.Metal)
        weldPart(handle, frontSight, forwardOffset(0, 0.24, 1.06))
        local rearSight = createPartInTool(tool, "RearSight", Vector3.new(0.1, 0.05, 0.06), Color3.fromRGB(70, 68, 66), Enum.Material.Metal)
        weldPart(handle, rearSight, forwardOffset(0, 0.24, 0.18))
    elseif weaponId == "Shotgun" then
        -- Pump shotgun: barrel forward
        local stock = createPartInTool(tool, "Stock", Vector3.new(0.38, 0.48, 0.88), Color3.fromRGB(78, 52, 38), Enum.Material.Wood)
        weldPart(handle, stock, forwardOffset(0, 0, -0.58))
        local stockPad = createPartInTool(tool, "StockPad", Vector3.new(0.36, 0.1, 0.2), Color3.fromRGB(45, 42, 40), Enum.Material.SmoothPlastic)
        weldPart(handle, stockPad, forwardOffset(0, 0, -0.92))
        local receiver = createPartInTool(tool, "Receiver", Vector3.new(0.33, 0.42, 0.48), Color3.fromRGB(68, 66, 63), Enum.Material.Metal)
        weldPart(handle, receiver, forwardOffset(0, 0, 0))
        local barrel = createPartInTool(tool, "Barrel", Vector3.new(0.18, 0.18, 1.38), Color3.fromRGB(62, 60, 58), Enum.Material.Metal)
        weldPart(handle, barrel, forwardOffset(0, 0, 0.82))
        local ventRib = createPartInTool(tool, "VentRib", Vector3.new(0.08, 0.06, 1.35), Color3.fromRGB(60, 58, 56), Enum.Material.Metal)
        weldPart(handle, ventRib, forwardOffset(0, 0.14, 0.82))
        local beadSight = createPartInTool(tool, "BeadSight", Vector3.new(0.06, 0.06, 0.06), Color3.fromRGB(200, 198, 195), Enum.Material.Metal)
        weldPart(handle, beadSight, forwardOffset(0, 0.16, 2.12))
        local ring = createPartInTool(tool, "BarrelRing", Vector3.new(0.2, 0.2, 0.1), Color3.fromRGB(68, 66, 63), Enum.Material.Metal)
        ring.Shape = Enum.PartType.Cylinder
        ring.Orientation = Vector3.new(90, 0, 0)
        weldPart(handle, ring, forwardOffset(0, 0, 1.48))
        local pump = createPartInTool(tool, "Pump", Vector3.new(0.24, 0.32, 0.38), Color3.fromRGB(72, 70, 68), Enum.Material.Metal)
        weldPart(handle, pump, forwardOffset(0, -0.08, 0.28))
        local pumpGroove1 = createPartInTool(tool, "PumpGroove1", Vector3.new(0.2, 0.08, 0.35), Color3.fromRGB(58, 56, 54), Enum.Material.Metal)
        weldPart(handle, pumpGroove1, forwardOffset(0, -0.14, 0.28))
        local pumpGroove2 = createPartInTool(tool, "PumpGroove2", Vector3.new(0.2, 0.08, 0.35), Color3.fromRGB(58, 56, 54), Enum.Material.Metal)
        weldPart(handle, pumpGroove2, forwardOffset(0, -0.02, 0.28))
        local pumpGroove3 = createPartInTool(tool, "PumpGroove3", Vector3.new(0.2, 0.08, 0.35), Color3.fromRGB(58, 56, 54), Enum.Material.Metal)
        weldPart(handle, pumpGroove3, forwardOffset(0, 0.06, 0.28))
        local triggerGuard = createPartInTool(tool, "TriggerGuard", Vector3.new(0.2, 0.06, 0.3), Color3.fromRGB(65, 63, 60), Enum.Material.Metal)
        weldPart(handle, triggerGuard, forwardOffset(0, -0.16, 0.08))
        local trigger = createPartInTool(tool, "Trigger", Vector3.new(0.08, 0.1, 0.14), Color3.fromRGB(62, 60, 58), Enum.Material.Metal)
        weldPart(handle, trigger, forwardOffset(0, -0.12, 0.12))
    elseif weaponId == "M16" then
        -- M16-style rifle: barrel forward
        local stock = createPartInTool(tool, "Stock", Vector3.new(0.32, 0.38, 0.48), Color3.fromRGB(58, 56, 53), Enum.Material.SmoothPlastic)
        weldPart(handle, stock, forwardOffset(0, 0, -0.48))
        local stockPad = createPartInTool(tool, "StockPad", Vector3.new(0.3, 0.08, 0.12), Color3.fromRGB(48, 46, 44), Enum.Material.SmoothPlastic)
        weldPart(handle, stockPad, forwardOffset(0, 0, -0.68))
        local receiver = createPartInTool(tool, "Receiver", Vector3.new(0.28, 0.32, 0.58), Color3.fromRGB(52, 55, 50), Enum.Material.Metal)
        weldPart(handle, receiver, forwardOffset(0, 0, 0))
        local barrel = createPartInTool(tool, "Barrel", Vector3.new(0.1, 0.1, 1.15), Color3.fromRGB(48, 50, 46), Enum.Material.Metal)
        weldPart(handle, barrel, forwardOffset(0, 0, 0.72))
        local flashHider = createPartInTool(tool, "FlashHider", Vector3.new(0.14, 0.14, 0.2), Color3.fromRGB(45, 47, 43), Enum.Material.Metal)
        flashHider.Shape = Enum.PartType.Cylinder
        flashHider.Orientation = Vector3.new(90, 0, 0)
        weldPart(handle, flashHider, forwardOffset(0, 0, 1.38))
        local mag = createPartInTool(tool, "Magazine", Vector3.new(0.14, 0.38, 0.18), Color3.fromRGB(58, 56, 53), Enum.Material.Metal)
        weldPart(handle, mag, forwardOffset(0, -0.34, 0.08))
        local magFloor = createPartInTool(tool, "MagFloor", Vector3.new(0.16, 0.04, 0.2), Color3.fromRGB(52, 50, 48), Enum.Material.Metal)
        weldPart(handle, magFloor, forwardOffset(0, -0.52, 0.08))
        local handguard = createPartInTool(tool, "Handguard", Vector3.new(0.18, 0.18, 0.68), Color3.fromRGB(55, 57, 52), Enum.Material.SmoothPlastic)
        weldPart(handle, handguard, forwardOffset(0, 0, 0.48))
        for i = 1, 4 do
            local vent = createPartInTool(tool, "Vent" .. i, Vector3.new(0.02, 0.14, 0.08), Color3.fromRGB(42, 44, 40), Enum.Material.Metal)
            weldPart(handle, vent, forwardOffset(0, 0, 0.52 + (i - 1) * 0.18))
        end
        local carryHandle = createPartInTool(tool, "CarryHandle", Vector3.new(0.12, 0.16, 0.3), Color3.fromRGB(50, 53, 48), Enum.Material.Metal)
        weldPart(handle, carryHandle, forwardOffset(0, 0.24, 0.16))
        local chargingHandle = createPartInTool(tool, "ChargingHandle", Vector3.new(0.08, 0.06, 0.2), Color3.fromRGB(50, 53, 48), Enum.Material.Metal)
        weldPart(handle, chargingHandle, forwardOffset(0, 0.28, 0.08))
        local rearSight = createPartInTool(tool, "RearSight", Vector3.new(0.08, 0.05, 0.1), Color3.fromRGB(50, 53, 48), Enum.Material.Metal)
        weldPart(handle, rearSight, forwardOffset(0, 0.3, 0.16))
        local frontSightPost = createPartInTool(tool, "FrontSightPost", Vector3.new(0.04, 0.12, 0.06), Color3.fromRGB(48, 50, 46), Enum.Material.Metal)
        weldPart(handle, frontSightPost, forwardOffset(0, 0.08, 1.1))
        local triggerGuard = createPartInTool(tool, "TriggerGuard", Vector3.new(0.1, 0.05, 0.2), Color3.fromRGB(50, 53, 48), Enum.Material.Metal)
        weldPart(handle, triggerGuard, forwardOffset(0, -0.12, 0.04))
    elseif weaponId == "TurretMG" then
        -- Turret-mounted machine gun: heavier barrel and box mag
        local receiver = createPartInTool(tool, "Receiver", Vector3.new(0.36, 0.3, 0.7), Color3.fromRGB(60, 62, 64), Enum.Material.Metal)
        weldPart(handle, receiver, forwardOffset(0, 0.02, 0.05))
        local barrel = createPartInTool(tool, "Barrel", Vector3.new(0.14, 0.14, 1.7), Color3.fromRGB(45, 46, 48), Enum.Material.Metal)
        weldPart(handle, barrel, forwardOffset(0, 0.1, 1.1))
        local muzzle = createPartInTool(tool, "Muzzle", Vector3.new(0.18, 0.18, 0.12), Color3.fromRGB(42, 44, 46), Enum.Material.Metal)
        weldPart(handle, muzzle, forwardOffset(0, 0.1, 1.95))
        local grip = createPartInTool(tool, "Grip", Vector3.new(0.2, 0.3, 0.2), Color3.fromRGB(48, 50, 52), Enum.Material.Metal)
        weldPart(handle, grip, forwardOffset(0, -0.2, -0.15))
        local boxMag = createPartInTool(tool, "BoxMag", Vector3.new(0.28, 0.36, 0.28), Color3.fromRGB(52, 54, 56), Enum.Material.Metal)
        weldPart(handle, boxMag, forwardOffset(0.32, -0.12, 0.1))
        local topCover = createPartInTool(tool, "TopCover", Vector3.new(0.34, 0.12, 0.5), Color3.fromRGB(58, 60, 62), Enum.Material.Metal)
        weldPart(handle, topCover, forwardOffset(0, 0.2, 0.05))
    elseif weaponId == "RPG" then
        -- RPG-7: tube/rocket forward
        local tube = createPartInTool(tool, "Tube", Vector3.new(0.32, 0.32, 1.75), Color3.fromRGB(52, 55, 50), Enum.Material.Metal)
        weldPart(handle, tube, forwardOffset(0, 0, 0.58))
        local tubeEnd = createPartInTool(tool, "TubeEnd", Vector3.new(0.34, 0.34, 0.12), Color3.fromRGB(48, 50, 46), Enum.Material.Metal)
        tubeEnd.Shape = Enum.PartType.Cylinder
        tubeEnd.Orientation = Vector3.new(90, 0, 0)
        weldPart(handle, tubeEnd, forwardOffset(0, 0, 1.48))
        local warhead = createPartInTool(tool, "Warhead", Vector3.new(0.28, 0.28, 0.5), Color3.fromRGB(58, 60, 55), Enum.Material.Metal)
        warhead.Shape = Enum.PartType.Ball
        weldPart(handle, warhead, forwardOffset(0, 0, 1.68))
        local noseCone = createPartInTool(tool, "NoseCone", Vector3.new(0.2, 0.2, 0.25), Color3.fromRGB(55, 57, 52), Enum.Material.Metal)
        weldPart(handle, noseCone, forwardOffset(0, 0, 1.88))
        for i = 1, 4 do
            local fin = createPartInTool(tool, "Fin" .. i, Vector3.new(0.06, 0.2, 0.25), Color3.fromRGB(50, 52, 48), Enum.Material.Metal)
            weldPartCFrame(handle, fin, CFrame.new(0, 0, 1.58) * CFrame.Angles(0, math.rad((i - 1) * 90), 0))
        end
        local grip = createPartInTool(tool, "Grip", Vector3.new(0.14, 0.38, 0.18), Color3.fromRGB(48, 46, 43), Enum.Material.SmoothPlastic)
        weldPart(handle, grip, forwardOffset(0, -0.34, 0.18))
        local shoulderRest = createPartInTool(tool, "ShoulderRest", Vector3.new(0.2, 0.08, 0.35), Color3.fromRGB(48, 46, 43), Enum.Material.SmoothPlastic)
        weldPart(handle, shoulderRest, forwardOffset(0, -0.1, -0.15))
        local sight = createPartInTool(tool, "Sight", Vector3.new(0.08, 0.12, 0.18), Color3.fromRGB(58, 56, 53), Enum.Material.Metal)
        weldPart(handle, sight, forwardOffset(0, 0.24, 0.28))
        local sightPost = createPartInTool(tool, "SightPost", Vector3.new(0.04, 0.08, 0.06), Color3.fromRGB(55, 53, 50), Enum.Material.Metal)
        weldPart(handle, sightPost, forwardOffset(0, 0.28, 0.34))
    elseif weaponId == "C4" then
        -- C4: main block (military tan), blasting cap well, wires, detonator/trigger
        local block = createPartInTool(tool, "Block", Vector3.new(0.48, 0.22, 0.32), Color3.fromRGB(82, 86, 84), Enum.Material.SmoothPlastic)
        weldPart(handle, block, forwardOffset(0, 0, 0))
        local blockStripe = createPartInTool(tool, "BlockStripe", Vector3.new(0.46, 0.04, 0.3), Color3.fromRGB(72, 76, 74), Enum.Material.SmoothPlastic)
        weldPart(handle, blockStripe, forwardOffset(0, 0.12, 0))
        local capWell = createPartInTool(tool, "CapWell", Vector3.new(0.12, 0.08, 0.1), Color3.fromRGB(45, 48, 46), Enum.Material.Metal)
        weldPart(handle, capWell, forwardOffset(0.12, 0.14, 0.18))
        local wire1 = createPartInTool(tool, "Wire1", Vector3.new(0.03, 0.03, 0.28), Color3.fromRGB(28, 28, 28), Enum.Material.SmoothPlastic)
        weldPart(handle, wire1, forwardOffset(0.14, 0.08, 0.22))
        local wire2 = createPartInTool(tool, "Wire2", Vector3.new(0.03, 0.03, 0.22), Color3.fromRGB(22, 22, 22), Enum.Material.SmoothPlastic)
        weldPart(handle, wire2, forwardOffset(-0.12, 0.06, 0.18))
        local detonator = createPartInTool(tool, "Detonator", Vector3.new(0.18, 0.1, 0.08), Color3.fromRGB(170, 48, 38), Enum.Material.SmoothPlastic)
        weldPart(handle, detonator, forwardOffset(0, -0.08, 0.18))
        local detButton = createPartInTool(tool, "DetButton", Vector3.new(0.1, 0.04, 0.06), Color3.fromRGB(200, 55, 45), Enum.Material.SmoothPlastic)
        weldPart(handle, detButton, forwardOffset(0, -0.12, 0.18))
    elseif weaponId == "TNT" then
        -- TNT: red wrapper sticks, paper texture (stripes), fuse, glowing spark
        local stick1 = createPartInTool(tool, "Stick1", Vector3.new(0.32, 0.18, 0.48), Color3.fromRGB(138, 52, 48), Enum.Material.SmoothPlastic)
        weldPart(handle, stick1, forwardOffset(0, 0, 0))
        local stick2 = createPartInTool(tool, "Stick2", Vector3.new(0.28, 0.16, 0.44), Color3.fromRGB(128, 46, 42), Enum.Material.SmoothPlastic)
        weldPart(handle, stick2, forwardOffset(0, 0.14, 0.04))
        local wrapStripe1 = createPartInTool(tool, "WrapStripe1", Vector3.new(0.26, 0.03, 0.42), Color3.fromRGB(118, 40, 36), Enum.Material.SmoothPlastic)
        weldPart(handle, wrapStripe1, forwardOffset(0, 0.16, 0.04))
        local wrapStripe2 = createPartInTool(tool, "WrapStripe2", Vector3.new(0.3, 0.03, 0.46), Color3.fromRGB(118, 40, 36), Enum.Material.SmoothPlastic)
        weldPart(handle, wrapStripe2, forwardOffset(0, 0.02, 0))
        local fuse = createPartInTool(tool, "Fuse", Vector3.new(0.05, 0.05, 0.32), Color3.fromRGB(88, 82, 68), Enum.Material.SmoothPlastic)
        weldPart(handle, fuse, forwardOffset(0.08, 0.22, 0.2))
        local fuseTip = createPartInTool(tool, "FuseTip", Vector3.new(0.06, 0.06, 0.08), Color3.fromRGB(78, 72, 58), Enum.Material.SmoothPlastic)
        weldPart(handle, fuseTip, forwardOffset(0.08, 0.38, 0.2))
        local spark = createPartInTool(tool, "Spark", Vector3.new(0.07, 0.07, 0.07), Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
        weldPart(handle, spark, forwardOffset(0.08, 0.42, 0.2))
    end

    return tool
end

local function getOrCreateToolTemplate(weaponId)
    if toolCache[weaponId] then
        return toolCache[weaponId]:Clone()
    end
    local tool = createToolForWeapon(weaponId)
    tool.Parent = ServerStorage
    toolCache[weaponId] = tool
    return tool:Clone()
end

function WeaponService.init(remotes)
    remotesRef = remotes
    for _, weaponId in ipairs(WeaponConfig.Order) do
        getOrCreateToolTemplate(weaponId)
    end
end

local function stripWeaponsFromPlayer(player)
    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character
    for _, weaponId in ipairs(WeaponConfig.Order) do
        local config = WeaponConfig.Weapons[weaponId]
        local name = config and config.DisplayName or weaponId
        if backpack then
            local tool = backpack:FindFirstChild(name)
            if tool then tool:Destroy() end
        end
        if character then
            local tool = character:FindFirstChild(name)
            if tool then tool:Destroy() end
        end
    end
end

function WeaponService.giveWeapon(player, weaponId)
    weaponId = weaponId or "Sword"
    if not WeaponConfig.Weapons[weaponId] then
        weaponId = "Sword"
    end

    local backpack = player:WaitForChild("Backpack", 5)
    if not backpack then
        return
    end

    stripWeaponsFromPlayer(player)

    local clone = getOrCreateToolTemplate(weaponId)
    clone.Activated:Connect(function()
        WeaponService.processAttack(clone)
    end)
    clone.Parent = backpack
end

-- Apply damage to one enemy (used by melee overlap and Touched)
local function applyMeleeHit(model, humanoid, hitPart, hitThisSwing, baseDmg, headMult, player)
    if not model or not humanoid or hitThisSwing[model] then
        return
    end
    if humanoid.Health <= 0 then
        return
    end
    hitThisSwing[model] = true
    local isHead = hitPart and hitPart.Name == "Head"
    local damage = baseDmg * (isHead and headMult or 1)
    humanoid:TakeDamage(damage)
    if remotesRef and remotesRef.HitEffect then
        local pos = model.PrimaryPart and model.PrimaryPart.Position or (hitPart and hitPart.Position)
        if pos then
            remotesRef.HitEffect:FireClient(player, pos, damage)
        end
    end
end

-- Melee hitbox attack (headshot = hit Head part).
-- Uses GetPartsInPart so enemies already inside the hitbox when it spawns are hit (Touched often doesn't fire for overlapping parts).
local function doMeleeAttack(character, player, root, config, baseDamage)
    local look = root.CFrame.LookVector
    local range = config.Range or 8
    local hitbox = Instance.new("Part")
    hitbox.Name = "WeaponHitbox"
    hitbox.Size = Vector3.new(10, 8, 12)
    hitbox.Transparency = 1
    hitbox.CanCollide = false
    hitbox.Anchored = true
    hitbox.CastShadow = false
    hitbox.CFrame = root.CFrame + look * range
    hitbox.Parent = Workspace

    local baseDmg = baseDamage or config.Damage or 12
    local headMult = WeaponConfig.HeadshotMultiplier or 1
    local hitThisSwing = {}

    -- OverlapParams: ignore player character so we don't hit ourselves
    local overlapParams = OverlapParams.new()
    overlapParams.FilterDescendantsInstances = {character}
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude

    -- Immediately check for parts already inside the hitbox (Touched does not fire for already-overlapping parts)
    local parts = Workspace:GetPartsInPart(hitbox, overlapParams)
    for _, otherPart in ipairs(parts) do
        local model, humanoid, hitPart = getEnemyModelFromPart(otherPart)
        applyMeleeHit(model, humanoid, hitPart, hitThisSwing, baseDmg, headMult, player)
    end

    local function onTouched(otherPart)
        if otherPart and otherPart:IsDescendantOf(character) then
            return
        end
        local model, humanoid, hitPart = getEnemyModelFromPart(otherPart)
        applyMeleeHit(model, humanoid, hitPart, hitThisSwing, baseDmg, headMult, player)
    end

    local conn = hitbox.Touched:Connect(onTouched)
    task.delay(Constants.Weapon.HitboxDuration or 0.2, function()
        conn:Disconnect()
        hitbox:Destroy()
    end)
end

-- Raycast ignoring the shooter's character (hits map, enemies, etc.)
local function raycastFromCharacter(origin, direction, character)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    return Workspace:Raycast(origin, direction, params)
end

-- Raycast that ONLY hits parts in the Enemies folder (shot passes through map/terrain)
local function raycastOnlyEnemies(origin, direction)
    local enemyFolder = Workspace:FindFirstChild("Enemies")
    if not enemyFolder then return nil end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {enemyFolder}
    params.FilterType = Enum.RaycastFilterType.Include
    return Workspace:Raycast(origin, direction, params)
end

-- Hitscan: raycast from origin in direction. Only hits enemies (passes through map). Returns list of hit positions.
local function doHitscanAttack(character, player, root, config, baseDamage, fromOrigin, fromDirection)
    local range = config.Range or 120
    local spread = (config.Spread or 2) * (math.pi / 180)
    local pellets = config.Pellets or 1
    local baseDmg = (baseDamage or config.Damage or 16) / math.max(1, pellets)
    local headMult = WeaponConfig.HeadshotMultiplier or 1
    local hitPositions = {}

    local origin, look
    if fromOrigin and fromDirection then
        origin = fromOrigin
        look = fromDirection
    else
        look = root.CFrame.LookVector
        origin = root.Position + look * 2
    end

    local up = (math.abs(look.Y) < 0.99) and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
    local right = look:Cross(up).Unit
    up = right:Cross(look).Unit

    for _ = 1, pellets do
        local dir = (look + right * (math.random() - 0.5) * spread * 2 + up * (math.random() - 0.5) * spread * 2).Unit
        -- Only hit enemies so shot isn't blocked by terrain/walls
        local ray = raycastOnlyEnemies(origin, dir * range)
        if ray and ray.Instance then
            local model, humanoid, hitPart = getEnemyModelFromPart(ray.Instance)
            if model and humanoid then
                local isHead = hitPart and hitPart.Name == "Head"
                local damage = baseDmg * (isHead and headMult or 1)
                humanoid:TakeDamage(damage)
                table.insert(hitPositions, ray.Position)
                if remotesRef and remotesRef.HitEffect then
                    remotesRef.HitEffect:FireClient(player, ray.Position, damage)
                end
            end
        end
    end
    return hitPositions
end

-- Explosive: raycast to point, then damage in radius (distance falloff). Returns explosion center for effects.
local function doExplosiveAttack(character, player, root, config, baseDamage, fromOrigin, fromDirection)
    local range = config.Range or 120
    local radius = config.Radius or 12
    local damage = baseDamage or config.Damage or 60

    local origin, look
    if fromOrigin and fromDirection then
        origin = fromOrigin
        look = fromDirection
    else
        look = root.CFrame.LookVector
        origin = root.Position + look * 2
    end

    local ray = raycastFromCharacter(origin, look * range, character)
    local center = ray and ray.Position or (origin + look * range)

    local enemyFolder = workspace:FindFirstChild("Enemies")
    if enemyFolder then
        for _, model in ipairs(enemyFolder:GetChildren()) do
            if model:IsA("Model") and model:GetAttribute("IsEnemy") then
                local hrp = model:FindFirstChild("HumanoidRootPart")
                local humanoid = model:FindFirstChild("Humanoid")
                if hrp and humanoid and humanoid.Health > 0 then
                    local dist = (hrp.Position - center).Magnitude
                    if dist <= radius then
                        local falloff = 1 - (dist / radius) * 0.6
                        humanoid:TakeDamage(damage * falloff)
                        if remotesRef and remotesRef.HitEffect then
                            remotesRef.HitEffect:FireClient(player, hrp.Position, damage * falloff)
                        end
                    end
                end
            end
        end
    end
    return { center }
end

function WeaponService.processAttack(tool)
    local character = tool.Parent
    if not character or not character:IsA("Model") then
        return
    end
    local player = Players:GetPlayerFromCharacter(character)
    if not player then
        return
    end

    local weaponId = normalizeWeaponId(tool:GetAttribute("WeaponId") or tool.Name) or "Sword"
    local config = WeaponConfig.Weapons[weaponId] or WeaponConfig.Weapons.Sword

    local cooldown = config.Cooldown or Constants.Weapon.Cooldown

    if config.Mode == "hitscan" or config.Mode == "explosive" then
        local token = (pendingGunFallbackByPlayer[player] or 0) + 1
        pendingGunFallbackByPlayer[player] = token
        task.delay(0.05, function()
            if pendingGunFallbackByPlayer[player] ~= token then
                return
            end
            local recentCameraShot = lastCameraShotByPlayer[player]
            if recentCameraShot and (os.clock() - recentCameraShot) <= 0.1 then
                return
            end
            local now = os.clock()
            local last = lastAttackByPlayer[player] or 0
            if now - last < cooldown then
                return
            end
            local root = character:FindFirstChild("HumanoidRootPart")
            if not root then
                return
            end
            local baseDamage = player:GetAttribute("Damage") or config.Damage
            lastAttackByPlayer[player] = now
            local look = root.CFrame.LookVector
            local origin = root.Position + Vector3.new(0, 1.5, 0) + look * 3
            local hitPositions = {}
            if config.Mode == "hitscan" then
                hitPositions = doHitscanAttack(character, player, root, config, baseDamage, origin, look) or {}
            else
                hitPositions = doExplosiveAttack(character, player, root, config, baseDamage, origin, look) or {}
            end
            if remotesRef and remotesRef.WeaponEffect then
                remotesRef.WeaponEffect:FireAllClients(origin, look, weaponId, hitPositions, false)
            end
        end)
        return
    end

    local now = os.clock()
    local last = lastAttackByPlayer[player] or 0
    if now - last < cooldown then
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local baseDamage = player:GetAttribute("Damage") or config.Damage

    lastAttackByPlayer[player] = now

    if config.Mode == "melee" then
        doMeleeAttack(character, player, root, config, baseDamage)
    else
        doMeleeAttack(character, player, root, config, baseDamage)
    end
    -- Visual/audio: melee slash effect (all clients)
    if remotesRef and remotesRef.WeaponEffect then
        local look = root.CFrame.LookVector
        local origin = root.Position + look * 2
        remotesRef.WeaponEffect:FireAllClients(origin, look, weaponId, {}, true)
    end
end

-- Called when client sends camera origin + direction (so shots go where player aims).
-- weaponIdFromClient: optional; if provided, use it (avoids tool replication delay when equipping).
function WeaponService.processShootFromCamera(player, origin, direction, weaponIdFromClient)
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local weaponId = normalizeWeaponId(weaponIdFromClient)
    if not weaponId then
        -- Fallback: find tool in character or backpack (in case client didn't send weaponId)
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") then
                local id = normalizeWeaponId(child:GetAttribute("WeaponId") or child.Name)
                if id then
                    weaponId = id
                    break
                end
            end
        end
        if not weaponId then
            local backpack = player:FindFirstChild("Backpack")
            if backpack then
                for _, child in ipairs(backpack:GetChildren()) do
                    if child:IsA("Tool") then
                        local id = normalizeWeaponId(child:GetAttribute("WeaponId") or child.Name)
                        if id then
                            weaponId = id
                            break
                        end
                    end
                end
            end
        end
    end
    if not weaponId then weaponId = "Sword" end
    local config = WeaponConfig.Weapons[weaponId]
    if not config then return end
    if config.Mode ~= "hitscan" and config.Mode ~= "explosive" then return end

    local cooldown = config.Cooldown or Constants.Weapon.Cooldown
    local now = os.clock()
    lastCameraShotByPlayer[player] = now
    local last = lastAttackByPlayer[player] or 0
    if now - last < cooldown then
        return
    end
    lastAttackByPlayer[player] = now

    local baseDamage = player:GetAttribute("Damage") or config.Damage

    local hitPositions = {}
    if config.Mode == "hitscan" then
        hitPositions = doHitscanAttack(character, player, root, config, baseDamage, origin, direction) or {}
    else
        hitPositions = doExplosiveAttack(character, player, root, config, baseDamage, origin, direction) or {}
    end
    if remotesRef and remotesRef.WeaponEffect then
        remotesRef.WeaponEffect:FireAllClients(origin, direction, weaponId, hitPositions, false)
    end
end

return WeaponService
