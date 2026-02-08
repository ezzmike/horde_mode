local Constants = {}

Constants.Remotes = {
    Ready = "ReadyEvent",
    Currency = "CurrencyEvent",
    Wave = "WaveEvent",
    Message = "MessageEvent",
    Upgrade = "UpgradeRequest",
    HitEffect = "HitEffect",
    WeaponShootRequest = "WeaponShootRequest",
    WeaponEffect = "WeaponEffect",
    PlaySound = "PlaySound",
    -- Admin
    AdminGodMode = "AdminGodMode",
    AdminGiveWeapon = "AdminGiveWeapon",
    AdminNukeAll = "AdminNukeAll",
    AdminPanelVisible = "AdminPanelVisible",
}

Constants.Game = {
    MinReadyPlayers = 1,
    LobbyCountdown = 30,
    ReadyCountdown = 10,
    IntermissionTime = 20,
    AutoStart = true,
    AutoStartDelay = 4,
    -- AI bots: set BotsEnabled = true to spawn bots that fight zombies with players
    BotsEnabled = true,
    BotsScale = 0.5,   -- bots per human (e.g. 0.5 = 1 bot per 2 players)
    BotsMin = 0,
    BotsMax = 4,
    -- Single player: number of AI teammates when only 1 human is in the match (0 = none)
    SinglePlayerTeammates = 2,
}

-- UserIds that can use the admin panel (add your Roblox UserId here)
Constants.AdminUserIds = {
    [0] = true,  -- placeholder; replace 0 with your UserId
}

Constants.Weapon = {
    AttackRange = 18,
    AttackConeDegrees = 200,
    Cooldown = 0.45,
    HitboxDuration = 0.22,
}

return Constants
