local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local WeatherService = {}

local remotes
local config
local atmosphere
local currentState

local function ensureAtmosphere()
    if atmosphere and atmosphere.Parent then
        return atmosphere
    end
    atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end
    return atmosphere
end

local function tweenLighting(target)
    local tween = TweenService:Create(Lighting, TweenInfo.new(config.TransitionSeconds), {
        Brightness = target.Brightness,
        OutdoorAmbient = target.OutdoorAmbient,
        Ambient = target.Ambient,
        FogStart = target.FogStart,
        FogEnd = target.FogEnd,
    })
    tween:Play()
end

local function tweenAtmosphere(target)
    local atm = ensureAtmosphere()
    local tween = TweenService:Create(atm, TweenInfo.new(config.TransitionSeconds), {
        Density = target.AtmosphereDensity,
        Haze = target.AtmosphereHaze,
        Glare = target.AtmosphereGlare,
    })
    tween:Play()
end

local function setState(stateName)
    local state = config.States[stateName]
    if not state then
        return
    end

    currentState = stateName
    tweenLighting(state)
    tweenAtmosphere(state)

    if remotes and remotes.Weather then
        remotes.Weather:FireAllClients(stateName)
    end
end

function WeatherService.init(remotesRef, weatherConfig)
    remotes = remotesRef
    config = weatherConfig
    ensureAtmosphere()
end

function WeatherService.start()
    if not config then
        return
    end

    local order = { "Clear", "Storm" }
    local index = 1

    setState(order[index])

    task.spawn(function()
        while true do
            task.wait(config.CycleSeconds)
            index = (index % #order) + 1
            setState(order[index])
        end
    end)
end

function WeatherService.getCurrentState()
    return currentState
end

return WeatherService
