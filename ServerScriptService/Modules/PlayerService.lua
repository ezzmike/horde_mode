local Players = game:GetService("Players")
local PlayerService = {}

function PlayerService.init(remotes)
    PlayerService.remotes = remotes
end

function PlayerService.setupPlayer(player)
    player:SetAttribute("Currency", 0)
    player:SetAttribute("Damage", 10)
    player:SetAttribute("MaxHealth", 100)
    player:SetAttribute("WalkSpeed", 16)
    player:SetAttribute("SpeedLevel", 0)
    player:SetAttribute("HealthLevel", 0)
    player:SetAttribute("DamageLevel", 0)
end

function PlayerService.applyCharacter(player, character)
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.MaxHealth = player:GetAttribute("MaxHealth") or 100
    humanoid.Health = humanoid.MaxHealth
    humanoid.WalkSpeed = player:GetAttribute("WalkSpeed") or 16
end

function PlayerService.addCurrency(player, amount)
    local current = player:GetAttribute("Currency") or 0
    local newValue = math.max(0, current + amount)
    player:SetAttribute("Currency", newValue)

    if PlayerService.remotes and PlayerService.remotes.Currency then
        PlayerService.remotes.Currency:FireClient(player, newValue)
    end
end

function PlayerService.resetRunStats(player)
    player:SetAttribute("Currency", 0)
    player:SetAttribute("Damage", 10)
    player:SetAttribute("MaxHealth", 100)
    player:SetAttribute("WalkSpeed", 16)
    player:SetAttribute("SpeedLevel", 0)
    player:SetAttribute("HealthLevel", 0)
    player:SetAttribute("DamageLevel", 0)
end

function PlayerService.getAlivePlayers()
    local alive = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            table.insert(alive, player)
        end
    end
    return alive
end

function PlayerService.getAllPlayers()
    return Players:GetPlayers()
end

function PlayerService.getUpgradeCost(player, upgradeType, baseCost, increment)
    local levelAttr = upgradeType .. "Level"
    local level = player:GetAttribute(levelAttr) or 0
    return baseCost + (level * increment)
end

function PlayerService.applyUpgrade(player, upgradeType, amount)
    local levelAttr = upgradeType .. "Level"
    local level = player:GetAttribute(levelAttr) or 0
    player:SetAttribute(levelAttr, level + 1)

    if upgradeType == "Speed" then
        player:SetAttribute("WalkSpeed", (player:GetAttribute("WalkSpeed") or 16) + amount)
    elseif upgradeType == "Health" then
        player:SetAttribute("MaxHealth", (player:GetAttribute("MaxHealth") or 100) + amount)
    elseif upgradeType == "Damage" then
        player:SetAttribute("Damage", (player:GetAttribute("Damage") or 10) + amount)
    end

    local character = player.Character
    if character then
        PlayerService.applyCharacter(player, character)
    end
end

return PlayerService
