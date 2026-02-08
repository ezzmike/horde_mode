local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local function getCamera()
    return workspace.CurrentCamera
end

local Constants = require(ReplicatedStorage.Modules.Constants)
local SoundConfig = require(ReplicatedStorage.Modules.SoundConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
    return remotes:WaitForChild(name)
end

local readyRemote = getRemote(Constants.Remotes.Ready)
local currencyRemote = getRemote(Constants.Remotes.Currency)
local waveRemote = getRemote(Constants.Remotes.Wave)
local messageRemote = getRemote(Constants.Remotes.Message)
local upgradeRemote = getRemote(Constants.Remotes.Upgrade)
local hitEffectRemote = getRemote(Constants.Remotes.HitEffect)
local weaponEffectRemote = getRemote(Constants.Remotes.WeaponEffect)
local weaponShootRequestRemote = getRemote(Constants.Remotes.WeaponShootRequest)
local playSoundRemote = getRemote(Constants.Remotes.PlaySound)
local adminGodModeRemote = getRemote(Constants.Remotes.AdminGodMode)
local adminGiveWeaponRemote = getRemote(Constants.Remotes.AdminGiveWeapon)
local adminNukeAllRemote = getRemote(Constants.Remotes.AdminNukeAll)
local adminPanelVisibleRemote = getRemote(Constants.Remotes.AdminPanelVisible)

-- User options (Auto Aim, Auto Skip Intermission)
local autoAimEnabled = false
local autoSkipIntermissionEnabled = false

-- Music: try new AudioPlayer API first (AudioPlayer + AudioDeviceOutput + Wire), fallback to Sound.
local currentMusicSound = nil
local currentAudioPlayer = nil
local SOUND_LOAD_TIMEOUT = 6

local function stopMusic()
    if currentMusicSound then
        pcall(function() currentMusicSound:Stop() currentMusicSound:Destroy() end)
        currentMusicSound = nil
    end
    if currentAudioPlayer then
        pcall(function() currentAudioPlayer:Stop() currentAudioPlayer:Destroy() end)
        currentAudioPlayer = nil
    end
end

-- Try new audio system (AudioPlayer + Wire + AudioDeviceOutput) for background music
local function playMusicWithAudioPlayer(id, volume)
    if not id or id == "" then return false end
    local assetId = type(id) == "string" and (id:match("^rbxassetid://") and id or ("rbxassetid://" .. id)) or ("rbxassetid://" .. tostring(id))
    local ok, ap = pcall(function()
        local AudioPlayer = Instance.new("AudioPlayer")
        AudioPlayer.AssetId = assetId
        AudioPlayer.Looping = true
        AudioPlayer.Volume = volume or 0.55
        AudioPlayer.Parent = SoundService

        local deviceOutput = SoundService:FindFirstChildOfClass("AudioDeviceOutput")
        if not deviceOutput then
            deviceOutput = Instance.new("AudioDeviceOutput")
            deviceOutput.Parent = SoundService
        end

        local wire = Instance.new("Wire")
        wire.SourceInstance = AudioPlayer
        wire.TargetInstance = deviceOutput
        wire.Parent = SoundService

        AudioPlayer:Play()
        return AudioPlayer
    end)
    if ok and ap then
        currentAudioPlayer = ap
        return true
    end
    return false
end

-- Fallback: legacy Sound. Uses Loaded only; after timeout try next ID.
local function playMusicWithSound(key)
    stopMusic()
    local primaryId = SoundConfig.getMusicId(key)
    local fallbacks = SoundConfig.getMusicFallbacks(key) or {}
    local volume = SoundConfig.DefaultMusicVolume or 0.55
    local idsToTry = { primaryId }
    for _, fb in ipairs(fallbacks) do table.insert(idsToTry, fb) end

    local function tryPlayId(index)
        if index > #idsToTry or not idsToTry[index] then return end
        local id = idsToTry[index]
        local soundId = (type(id) == "string" and id:match("^rbxassetid://") and id) or ("rbxassetid://" .. tostring(id))
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = volume
        sound.Looped = true
        sound.Parent = SoundService

        sound.Loaded:Connect(function()
            pcall(function() sound:Play() end)
            currentMusicSound = sound
        end)
        -- Also try Play after a short delay in case Loaded fires late
        task.delay(1, function()
            if sound.Parent and not currentMusicSound then
                pcall(function() sound:Play() end)
                currentMusicSound = sound
            end
        end)

        task.delay(SOUND_LOAD_TIMEOUT, function()
            if not sound.Parent then return end
            if sound.IsLoaded then return end
            sound:Destroy()
            tryPlayId(index + 1)
        end)
    end

    tryPlayId(1)
end

local function playMusic(key)
    stopMusic()
    local id = SoundConfig.getMusicId(key)
    local volume = SoundConfig.DefaultMusicVolume or 0.55
    if id and playMusicWithAudioPlayer(id, volume) then
        return
    end
    playMusicWithSound(key)
end

-- SFX: try new AudioPlayer first (handles new-audio IDs), then legacy Sound with same or fallback ID.
local function playSfxWithAudioPlayer(assetId, volume)
    if not assetId or assetId == "" then return false end
    local rawId = assetId:gsub("rbxassetid://", "")
    local ok = pcall(function()
        local ap = Instance.new("AudioPlayer")
        ap.AssetId = assetId
        ap.Volume = volume or SoundConfig.DefaultSfxVolume or 0.7
        ap.Looping = false
        ap.Parent = SoundService
        local deviceOutput = SoundService:FindFirstChildOfClass("AudioDeviceOutput")
        if not deviceOutput then
            deviceOutput = Instance.new("AudioDeviceOutput")
            deviceOutput.Parent = SoundService
        end
        local wire = Instance.new("Wire")
        wire.SourceInstance = ap
        wire.TargetInstance = deviceOutput
        wire.Parent = SoundService
        ap:Play()
        task.delay(2, function()
            pcall(function() ap:Stop() ap:Destroy() end)
        end)
    end)
    return ok
end

local function playSfx(key, volume)
    local id = SoundConfig.getSfxId(key)
    if not id then return end
    local vol = volume or SoundConfig.DefaultSfxVolume or 0.7
    if playSfxWithAudioPlayer(id, vol) then return end
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Volume = vol
    sound.Looped = false
    sound.Parent = SoundService
    sound.Loaded:Connect(function()
        pcall(function() sound:Play() end)
    end)
    task.delay(1, function()
        if sound.Parent and not sound.IsLoaded then
            local fallbackId = SoundConfig.getSfxFallbackId and SoundConfig.getSfxFallbackId(key)
            if fallbackId and fallbackId ~= id then
                sound.SoundId = fallbackId
            end
        end
    end)
    task.delay(5, function()
        if sound.Parent then sound:Destroy() end
    end)
    sound.Ended:Once(function()
        if sound.Parent then sound:Destroy() end
    end)
end

playSoundRemote.OnClientEvent:Connect(function(soundName, options)
    if type(soundName) ~= "string" or soundName == "" then return end
    options = options or {}
    if soundName == "MusicLobby" or soundName == "MusicArena" then
        playMusic(soundName == "MusicLobby" and "Lobby" or "Arena")
    else
        playSfx(soundName, options.Volume)
    end
end)

-- Start lobby music shortly after load so there's always background music (server may not have fired yet)
task.delay(2.5, function()
    if not currentMusicSound then
        playMusic("Lobby")
    end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ArenaUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local function addRoundedCorner(obj, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = obj
    return corner
end

-- Top-left panel: Wave + Timer
local leftPanel = Instance.new("Frame")
leftPanel.Name = "LeftPanel"
leftPanel.Size = UDim2.new(0, 260, 0, 90)
leftPanel.Position = UDim2.new(0, 20, 0, 20)
leftPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
leftPanel.BackgroundTransparency = 0.2
leftPanel.BorderSizePixel = 0
leftPanel.Parent = screenGui
addRoundedCorner(leftPanel, 12)

local waveLabel = Instance.new("TextLabel")
waveLabel.Size = UDim2.new(1, -24, 0, 32)
waveLabel.Position = UDim2.new(0, 12, 0, 8)
waveLabel.BackgroundTransparency = 1
waveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
waveLabel.Font = Enum.Font.GothamBold
waveLabel.TextSize = 20
waveLabel.Text = "Wave: -"
waveLabel.TextXAlignment = Enum.TextXAlignment.Left
waveLabel.TextStrokeTransparency = 0.5
waveLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
waveLabel.Parent = leftPanel

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -24, 0, 28)
timerLabel.Position = UDim2.new(0, 12, 0, 42)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 16
timerLabel.Text = ""
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Parent = leftPanel

-- Options panel (below left panel): Auto Aim, Auto Skip Intermission
local optionsPanel = Instance.new("Frame")
optionsPanel.Name = "OptionsPanel"
optionsPanel.Size = UDim2.new(0, 260, 0, 72)
optionsPanel.Position = UDim2.new(0, 20, 0, 118)
optionsPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
optionsPanel.BackgroundTransparency = 0.2
optionsPanel.BorderSizePixel = 0
optionsPanel.Parent = screenGui
addRoundedCorner(optionsPanel, 12)

local function makeOptionRow(parent, y, labelText, getValue, setValue)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -16, 0, 28)
    row.Position = UDim2.new(0, 8, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local check = Instance.new("TextButton")
    check.Size = UDim2.new(0, 22, 0, 22)
    check.Position = UDim2.new(0, 0, 0, 2)
    check.Text = ""
    check.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    check.Parent = row
    addRoundedCorner(check, 4)
    local checkMark = Instance.new("TextLabel")
    checkMark.Size = UDim2.new(1, 0, 1, 0)
    checkMark.Position = UDim2.new(0, 0, 0, 0)
    checkMark.BackgroundTransparency = 1
    checkMark.Text = ""
    checkMark.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkMark.Font = Enum.Font.GothamBold
    checkMark.TextSize = 14
    checkMark.Parent = check
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -32, 0, 26)
    label.Position = UDim2.new(0, 28, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(220, 220, 230)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local function updateVisual()
        if getValue() then
            checkMark.Text = "X"
            check.BackgroundColor3 = Color3.fromRGB(70, 130, 200)
        else
            checkMark.Text = ""
            check.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        end
    end
    check.MouseButton1Click:Connect(function()
        setValue(not getValue())
        updateVisual()
    end)
    updateVisual()
    return updateVisual
end
makeOptionRow(optionsPanel, 6, "Auto Aim", function() return autoAimEnabled end, function(v) autoAimEnabled = v end)
makeOptionRow(optionsPanel, 36, "Auto Skip Intermission", function() return autoSkipIntermissionEnabled end, function(v) autoSkipIntermissionEnabled = v end)

-- Top-right: Currency
local currencyPanel = Instance.new("Frame")
currencyPanel.Name = "CurrencyPanel"
currencyPanel.Size = UDim2.new(0, 220, 0, 44)
currencyPanel.Position = UDim2.new(1, -240, 0, 20)
currencyPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
currencyPanel.BackgroundTransparency = 0.2
currencyPanel.BorderSizePixel = 0
currencyPanel.Parent = screenGui
addRoundedCorner(currencyPanel, 12)

local currencyLabel = Instance.new("TextLabel")
currencyLabel.Size = UDim2.new(1, -24, 1, 0)
currencyLabel.Position = UDim2.new(0, 12, 0, 0)
currencyLabel.BackgroundTransparency = 1
currencyLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
currencyLabel.Font = Enum.Font.GothamBold
currencyLabel.TextSize = 18
currencyLabel.Text = "Currency: 0"
currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
currencyLabel.Parent = currencyPanel

-- Health bar (bottom-left)
local healthPanel = Instance.new("Frame")
healthPanel.Name = "HealthPanel"
healthPanel.Size = UDim2.new(0, 280, 0, 44)
healthPanel.Position = UDim2.new(0, 20, 1, -64)
healthPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
healthPanel.BackgroundTransparency = 0.2
healthPanel.BorderSizePixel = 0
healthPanel.Parent = screenGui
addRoundedCorner(healthPanel, 12)

local healthBarBg = Instance.new("Frame")
healthBarBg.Name = "HealthBarBg"
healthBarBg.Size = UDim2.new(1, -24, 0, 20)
healthBarBg.Position = UDim2.new(0, 12, 0, 10)
healthBarBg.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
healthBarBg.BorderSizePixel = 0
healthBarBg.Parent = healthPanel
addRoundedCorner(healthBarBg, 6)

local healthBarFill = Instance.new("Frame")
healthBarFill.Name = "HealthBarFill"
healthBarFill.Size = UDim2.new(1, 0, 1, 0)
healthBarFill.Position = UDim2.new(0, 0, 0, 0)
healthBarFill.BackgroundColor3 = Color3.fromRGB(200, 60, 50)
healthBarFill.BorderSizePixel = 0
healthBarFill.Parent = healthBarBg
addRoundedCorner(healthBarFill, 6)

local healthLabel = Instance.new("TextLabel")
healthLabel.Size = UDim2.new(1, -24, 0, 18)
healthLabel.Position = UDim2.new(0, 12, 0, -2)
healthLabel.BackgroundTransparency = 1
healthLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
healthLabel.Font = Enum.Font.Gotham
healthLabel.TextSize = 14
healthLabel.Text = "100 / 100"
healthLabel.TextXAlignment = Enum.TextXAlignment.Left
healthLabel.Parent = healthPanel

-- Weapon hint
local weaponHint = Instance.new("TextLabel")
weaponHint.Size = UDim2.new(0, 220, 0, 28)
weaponHint.Position = UDim2.new(0, 20, 1, -110)
weaponHint.BackgroundTransparency = 1
weaponHint.TextColor3 = Color3.fromRGB(160, 160, 170)
weaponHint.Font = Enum.Font.Gotham
weaponHint.TextSize = 14
weaponHint.Text = "Equip your weapon & click to attack"
weaponHint.TextXAlignment = Enum.TextXAlignment.Left
weaponHint.Parent = screenGui

-- Damage numbers + hit effect
local function showDamageNumber(worldPos, damage)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.CFrame = CFrame.new(worldPos + Vector3.new(0, 1.5, 0))
    part.Parent = workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 80, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 0, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "-" .. tostring(math.floor(damage))
    label.TextColor3 = Color3.fromRGB(255, 220, 80)
    label.TextStrokeColor3 = Color3.fromRGB(80, 40, 0)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 28
    label.Parent = billboard

    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))
    particles.Size = NumberSequence.new(0.2, 0)
    particles.Transparency = NumberSequence.new(0.3, 1)
    particles.Lifetime = NumberRange.new(0.2, 0.35)
    particles.Rate = 50
    particles.Speed = NumberRange.new(2, 5)
    particles.SpreadAngle = Vector2.new(360, 360)
    particles.Parent = part
    particles:Emit(12)

    task.spawn(function()
        for i = 1, 24 do
            task.wait(1/30)
            part.CFrame = part.CFrame + Vector3.new(0, 0.08, 0)
            label.TextTransparency = (i / 24) * 0.8
        end
        part:Destroy()
    end)
end

hitEffectRemote.OnClientEvent:Connect(function(worldPos, damage)
    showDamageNumber(worldPos, damage)
    playSfx("Hit")
end)

-- Muzzle flash, slash, and impact effects (from server for player + bots)
local function spawnMuzzleFlash(origin, direction, weaponId)
    local barrelLen = 0.8
    if weaponId == "Pistol" then barrelLen = 0.5
    elseif weaponId == "Shotgun" then barrelLen = 0.9
    elseif weaponId == "M16" then barrelLen = 0.7
    elseif weaponId == "RPG" then barrelLen = 0.6
    end
    local pos = origin + direction * barrelLen
    local flash = Instance.new("Part")
    flash.Name = "MuzzleFlash"
    flash.Size = Vector3.new(0.4, 0.4, 0.15)
    flash.Anchored = true
    flash.CanCollide = false
    flash.Material = Enum.Material.Neon
    flash.Color = Color3.fromRGB(255, 220, 120)
    flash.CFrame = CFrame.lookAt(pos, pos + direction)
    flash.Parent = workspace
    task.delay(0.06, function() if flash.Parent then flash:Destroy() end end)
end

local function spawnSlashEffect(origin, direction)
    local slash = Instance.new("Part")
    slash.Name = "SlashEffect"
    slash.Size = Vector3.new(0.1, 1.2, 2.5)
    slash.Anchored = true
    slash.CanCollide = false
    slash.Transparency = 0.3
    slash.Material = Enum.Material.ForceField
    slash.Color = Color3.fromRGB(200, 220, 255)
    slash.CFrame = CFrame.lookAt(origin + direction * 2, origin + direction * 4)
    slash.Parent = workspace
    task.delay(0.15, function() if slash.Parent then slash:Destroy() end end)
end

local function spawnImpactEffect(hitPos)
    local p = Instance.new("Part")
    p.Name = "ImpactEffect"
    p.Size = Vector3.new(0.2, 0.2, 0.2)
    p.Anchored = true
    p.CanCollide = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(255, 180, 80)
    p.CFrame = CFrame.new(hitPos)
    p.Parent = workspace
    local em = Instance.new("ParticleEmitter", p)
    em.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100))
    em.Lifetime = NumberRange.new(0.1, 0.2)
    em.Rate = 30
    em.Speed = NumberRange.new(2, 6)
    em.SpreadAngle = Vector2.new(180, 180)
    em:Emit(8)
    task.delay(0.2, function() if p.Parent then p:Destroy() end end)
end

local function spawnExplosionEffect(center)
    local ring = Instance.new("Part")
    ring.Name = "ExplosionRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 4, 4)
    ring.Orientation = Vector3.new(0, 0, 90)
    ring.Anchored = true
    ring.CanCollide = false
    ring.Transparency = 0.2
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(255, 120, 40)
    ring.CFrame = CFrame.new(center)
    ring.Parent = workspace
    local em = Instance.new("ParticleEmitter", ring)
    em.Color = ColorSequence.new(Color3.fromRGB(255, 150, 50))
    em.Lifetime = NumberRange.new(0.2, 0.4)
    em.Rate = 50
    em.Speed = NumberRange.new(8, 15)
    em.SpreadAngle = Vector2.new(360, 360)
    em:Emit(25)
    task.delay(0.4, function() if ring.Parent then ring:Destroy() end end)
end

weaponEffectRemote.OnClientEvent:Connect(function(origin, direction, weaponId, hitPositions, isMelee)
    if type(origin) ~= "userdata" or type(direction) ~= "userdata" then return end
    origin = Vector3.new(origin.X, origin.Y, origin.Z)
    direction = Vector3.new(direction.X, direction.Y, direction.Z)
    if direction.Magnitude < 0.01 then return end
    direction = direction.Unit
    isMelee = isMelee == true
    if isMelee then
        spawnSlashEffect(origin, direction)
    else
        spawnMuzzleFlash(origin, direction, weaponId or "Pistol")
        -- Tracer beam for hitscan (short line that fades)
        if weaponId == "Pistol" or weaponId == "Shotgun" or weaponId == "M16" or weaponId == "TurretMG" then
            local endPos = origin + direction * 40
            if hitPositions and hitPositions[1] then
                local p = hitPositions[1]
                endPos = Vector3.new(p.X, p.Y, p.Z)
            end
            local mid = (origin + endPos) / 2
            local len = (endPos - origin).Magnitude
            local beam = Instance.new("Part")
            beam.Name = "Tracer"
            beam.Size = Vector3.new(0.05, 0.05, len)
            beam.Anchored = true
            beam.CanCollide = false
            beam.Material = Enum.Material.Neon
            beam.Color = Color3.fromRGB(255, 240, 150)
            beam.CFrame = CFrame.lookAt(mid, endPos)
            beam.Parent = workspace
            task.delay(0.04, function() if beam.Parent then beam:Destroy() end end)
        end
        if hitPositions and #hitPositions > 0 then
            for _, pos in ipairs(hitPositions) do
                if type(pos) == "userdata" then
                    spawnImpactEffect(Vector3.new(pos.X, pos.Y, pos.Z))
                end
            end
        end
        if weaponId == "RPG" or weaponId == "C4" or weaponId == "TNT" then
            local c = hitPositions and hitPositions[1]
            if c then
                spawnExplosionEffect(Vector3.new(c.X, c.Y, c.Z))
            end
        end
    end
end)

local function updateHealth(character)
    local humanoid = character and character:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end
    local health = math.max(0, humanoid.Health)
    local maxHealth = humanoid.MaxHealth
    local scale = maxHealth > 0 and (health / maxHealth) or 0
    healthBarFill.Size = UDim2.new(scale, 0, 1, 0)
    healthLabel.Text = math.floor(health) .. " / " .. math.floor(maxHealth)
    if scale > 0.5 then
        healthBarFill.BackgroundColor3 = Color3.fromRGB(200, 60, 50)
    elseif scale > 0.25 then
        healthBarFill.BackgroundColor3 = Color3.fromRGB(220, 140, 50)
    else
        healthBarFill.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
end

player.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid")
    updateHealth(character)
    humanoid.HealthChanged:Connect(function()
        updateHealth(character)
    end)
end)
if player.Character then
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if humanoid then
        updateHealth(player.Character)
        humanoid.HealthChanged:Connect(function()
            updateHealth(player.Character)
        end)
    end
end

-- Center message (game events)
local messageLabel = Instance.new("TextLabel")
messageLabel.Size = UDim2.new(0.6, 0, 0, 70)
messageLabel.Position = UDim2.new(0.2, 0, 0.12, 0)
messageLabel.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
messageLabel.BackgroundTransparency = 0.3
messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
messageLabel.Font = Enum.Font.GothamBold
messageLabel.TextSize = 26
messageLabel.Text = ""
messageLabel.Visible = false
messageLabel.Parent = screenGui
addRoundedCorner(messageLabel, 10)

-- Ready button
local readyButton = Instance.new("TextButton")
readyButton.Size = UDim2.new(0, 180, 0, 48)
readyButton.Position = UDim2.new(0.5, -90, 1, -100)
readyButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
readyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
readyButton.Font = Enum.Font.GothamBold
readyButton.TextSize = 22
readyButton.Text = "READY UP"
readyButton.Parent = screenGui
addRoundedCorner(readyButton, 10)

readyButton.MouseButton1Click:Connect(function()
    readyRemote:FireServer()
end)

readyButton.MouseEnter:Connect(function()
    readyButton.BackgroundColor3 = Color3.fromRGB(70, 200, 100)
end)
readyButton.MouseLeave:Connect(function()
    readyButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
end)

currencyRemote.OnClientEvent:Connect(function(amount)
    currencyLabel.Text = "Currency: " .. tostring(amount)
    currencyPanel.BackgroundColor3 = Color3.fromRGB(40, 35, 15)
    task.delay(0.15, function()
        currencyPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    end)
end)

waveRemote.OnClientEvent:Connect(function(phase, value)
    if phase == "Wave" then
        waveLabel.Text = "Wave: " .. tostring(value)
        timerLabel.Text = ""
        readyButton.Visible = false
    elseif phase == "Intermission" then
        timerLabel.Text = "Intermission: " .. tostring(value)
        readyButton.Visible = false
        if autoSkipIntermissionEnabled then
            readyRemote:FireServer()
        end
    elseif phase == "Lobby" then
        timerLabel.Text = "Starting in: " .. tostring(value)
        readyButton.Visible = true
    end
end)

local function showMessage(text, duration)
    messageLabel.Text = text
    messageLabel.Visible = true
    task.delay(duration, function()
        messageLabel.Visible = false
    end)
end

messageRemote.OnClientEvent:Connect(function(_type, text, duration)
    showMessage(text, duration or 2)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
    local station = prompt.Parent
    if station and station:GetAttribute("UpgradeType") then
        local upgradeType = station:GetAttribute("UpgradeType")
        local baseCost = station:GetAttribute("BaseCost") or 10
        local increment = station:GetAttribute("CostIncrement") or 5
        local amount = station:GetAttribute("UpgradeAmount") or 1
        upgradeRemote:FireServer(upgradeType, baseCost, increment, amount)
        playSfx("Upgrade")
    end
end)

-- Admin panel (only visible to admins)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)
local adminPanel = Instance.new("Frame")
adminPanel.Name = "AdminPanel"
adminPanel.Size = UDim2.new(0, 200, 0, 290)
adminPanel.Position = UDim2.new(1, -220, 0, 280)
adminPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
adminPanel.BackgroundTransparency = 0.15
adminPanel.BorderSizePixel = 0
adminPanel.Visible = false
adminPanel.Parent = screenGui
addRoundedCorner(adminPanel, 10)

local adminTitle = Instance.new("TextLabel")
adminTitle.Size = UDim2.new(1, -16, 0, 28)
adminTitle.Position = UDim2.new(0, 8, 0, 6)
adminTitle.BackgroundTransparency = 1
adminTitle.Text = "Admin"
adminTitle.TextColor3 = Color3.fromRGB(255, 200, 80)
adminTitle.Font = Enum.Font.GothamBold
adminTitle.TextSize = 18
adminTitle.TextXAlignment = Enum.TextXAlignment.Left
adminTitle.Parent = adminPanel

local godModeBtn = Instance.new("TextButton")
godModeBtn.Size = UDim2.new(1, -16, 0, 36)
godModeBtn.Position = UDim2.new(0, 8, 0, 38)
godModeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
godModeBtn.Text = "God Mode: Toggle"
godModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
godModeBtn.Font = Enum.Font.Gotham
godModeBtn.TextSize = 14
godModeBtn.Parent = adminPanel
addRoundedCorner(godModeBtn, 6)
godModeBtn.MouseButton1Click:Connect(function()
    adminGodModeRemote:FireServer()
end)

local weaponLabel = Instance.new("TextLabel")
weaponLabel.Size = UDim2.new(1, -16, 0, 20)
weaponLabel.Position = UDim2.new(0, 8, 0, 82)
weaponLabel.BackgroundTransparency = 1
weaponLabel.Text = "Give weapon:"
weaponLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
weaponLabel.Font = Enum.Font.Gotham
weaponLabel.TextSize = 12
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.Parent = adminPanel

local weaponList = Instance.new("Frame")
weaponList.Name = "WeaponList"
weaponList.Size = UDim2.new(1, -16, 0, 130)
weaponList.Position = UDim2.new(0, 8, 0, 102)
weaponList.BackgroundTransparency = 1
weaponList.Parent = adminPanel

local y = 0
for _, weaponId in ipairs(WeaponConfig.Order) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 88, 0, 28)
    btn.Position = UDim2.new(0, ((y % 2) * 92), 0, math.floor(y / 2) * 32)
    btn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
    btn.Text = weaponId
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.Parent = weaponList
    addRoundedCorner(btn, 4)
    btn.MouseButton1Click:Connect(function()
        adminGiveWeaponRemote:FireServer(weaponId)
    end)
    y = y + 1
end

local nukeBtn = Instance.new("TextButton")
nukeBtn.Size = UDim2.new(1, -16, 0, 36)
nukeBtn.Position = UDim2.new(0, 8, 0, 242)
nukeBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
nukeBtn.Text = "Nuke All Enemies"
nukeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
nukeBtn.Font = Enum.Font.GothamBold
nukeBtn.TextSize = 14
nukeBtn.Parent = adminPanel
addRoundedCorner(nukeBtn, 6)
nukeBtn.MouseButton1Click:Connect(function()
    adminNukeAllRemote:FireServer()
end)

adminPanelVisibleRemote.OnClientEvent:Connect(function(visible)
    adminPanel.Visible = visible == true
end)

-- Weapon sounds and send camera aim for hitscan/explosive
local WeaponConfigClient = require(ReplicatedStorage.Modules.WeaponConfig)
local function getWeaponIdFromTool(tool)
    local id = tool:GetAttribute("WeaponId")
    if id then return id end
    return WeaponConfigClient.getWeaponIdFromDisplayName and WeaponConfigClient.getWeaponIdFromDisplayName(tool.Name) or nil
end

-- Auto aim: nearest enemy in cone (degrees) in front of origin; returns direction to target or nil
local AUTO_AIM_CONE_DEG = 45
local AUTO_AIM_MAX_RANGE = 200
local function getAutoAimDirection(origin, defaultDirection)
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    local bestTarget = nil
    local bestScore = -1
    local coneRad = math.rad(AUTO_AIM_CONE_DEG)
    for _, model in ipairs(enemies:GetChildren()) do
        if not model:IsA("Model") or not model:GetAttribute("IsEnemy") then
            -- skip
        else
            local hrp = model:FindFirstChild("HumanoidRootPart")
            local humanoid = model:FindFirstChild("Humanoid")
            if hrp and humanoid and humanoid.Health > 0 then
                local toTarget = (hrp.Position - origin).Unit
                local dot = defaultDirection:Dot(toTarget)
                if dot >= math.cos(coneRad) then
                    local dist = (hrp.Position - origin).Magnitude
                    if dist <= AUTO_AIM_MAX_RANGE then
                        local score = dot * 1000 - dist
                        if score > bestScore then
                            bestScore = score
                            bestTarget = hrp
                        end
                    end
                end
            end
        end
    end
    if bestTarget then
        return (bestTarget.Position - origin).Unit
    end
    return nil
end

local connectedTools = {}
local function connectToolShoot(tool)
    if not tool:IsA("Tool") then return end
    if connectedTools[tool] then return end
    connectedTools[tool] = true
    tool.Activated:Connect(function()
        local weaponId = getWeaponIdFromTool(tool)
        if not weaponId then return end
        local config = WeaponConfigClient.Weapons[weaponId]
        if not config then return end
        local sfxKey = SoundConfig.getSfxForWeapon(weaponId, config.Mode)
        playSfx(sfxKey)
        if config.Mode == "melee" then
            -- Server does melee + WeaponEffect in processAttack
        elseif config.Mode == "hitscan" or config.Mode == "explosive" then
            local camera = getCamera()
            if camera then
                local origin = camera.CFrame.Position
                local direction = camera.CFrame.LookVector
                if autoAimEnabled then
                    direction = getAutoAimDirection(origin, direction) or direction
                end
                weaponShootRequestRemote:FireServer(origin, direction, weaponId)
            end
        end
    end)
end
-- Connect tools in Backpack and when equipped (Character)
player.Backpack.ChildAdded:Connect(connectToolShoot)
player.CharacterAdded:Connect(function(character)
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then connectToolShoot(child) end
    end)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then connectToolShoot(child) end
    end
end)
if player.Character then
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        connectToolShoot(tool)
    end
    for _, child in ipairs(player.Character:GetChildren()) do
        if child:IsA("Tool") then connectToolShoot(child) end
    end
end
