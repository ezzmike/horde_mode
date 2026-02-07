local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Constants = require(ReplicatedStorage.Modules.Constants)

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

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ArenaUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local waveLabel = Instance.new("TextLabel")
waveLabel.Size = UDim2.new(0, 240, 0, 30)
waveLabel.Position = UDim2.new(0, 20, 0, 20)
waveLabel.BackgroundTransparency = 0.3
waveLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
waveLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
waveLabel.Font = Enum.Font.GothamBold
waveLabel.TextSize = 18
waveLabel.Text = "Wave: -"
waveLabel.Parent = screenGui

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(0, 240, 0, 30)
timerLabel.Position = UDim2.new(0, 20, 0, 55)
timerLabel.BackgroundTransparency = 0.3
timerLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
timerLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 16
timerLabel.Text = ""
timerLabel.Parent = screenGui

local currencyLabel = Instance.new("TextLabel")
currencyLabel.Size = UDim2.new(0, 200, 0, 30)
currencyLabel.Position = UDim2.new(1, -220, 0, 20)
currencyLabel.AnchorPoint = Vector2.new(0, 0)
currencyLabel.BackgroundTransparency = 0.3
currencyLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
currencyLabel.TextColor3 = Color3.fromRGB(240, 220, 120)
currencyLabel.Font = Enum.Font.GothamBold
currencyLabel.TextSize = 18
currencyLabel.Text = "Currency: 0"
currencyLabel.Parent = screenGui

local messageLabel = Instance.new("TextLabel")
messageLabel.Size = UDim2.new(0.6, 0, 0, 60)
messageLabel.Position = UDim2.new(0.2, 0, 0.15, 0)
messageLabel.BackgroundTransparency = 0.4
messageLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
messageLabel.Font = Enum.Font.GothamBold
messageLabel.TextSize = 24
messageLabel.Text = ""
messageLabel.Visible = false
messageLabel.Parent = screenGui

local readyButton = Instance.new("TextButton")
readyButton.Size = UDim2.new(0, 160, 0, 40)
readyButton.Position = UDim2.new(0.5, -80, 1, -90)
readyButton.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
readyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
readyButton.Font = Enum.Font.GothamBold
readyButton.TextSize = 20
readyButton.Text = "READY"
readyButton.Parent = screenGui

readyButton.MouseButton1Click:Connect(function()
    readyRemote:FireServer()
end)

currencyRemote.OnClientEvent:Connect(function(amount)
    currencyLabel.Text = "Currency: " .. tostring(amount)
end)

waveRemote.OnClientEvent:Connect(function(phase, value)
    if phase == "Wave" then
        waveLabel.Text = "Wave: " .. tostring(value)
        timerLabel.Text = ""
        readyButton.Visible = false
    elseif phase == "Intermission" then
        timerLabel.Text = "Intermission: " .. tostring(value)
        readyButton.Visible = false
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
    end
end)
