local Constants = {}

Constants.Remotes = {
    Ready = "ReadyEvent",
    Currency = "CurrencyEvent",
    Wave = "WaveEvent",
    Message = "MessageEvent",
    Upgrade = "UpgradeRequest",
}

Constants.Game = {
    MinReadyPlayers = 1,
    LobbyCountdown = 30,
    ReadyCountdown = 10,
    IntermissionTime = 20,
}

return Constants
