Roblox Studio Setup (Minimal Steps)

1) Create a new Roblox place (Baseplate).
2) In Explorer, create these folders:
   - ReplicatedStorage
     - Modules (Folder)
   - ServerScriptService
     - Modules (Folder)
   - StarterPlayer
     - StarterPlayerScripts (Folder)

3) Copy the files from this workspace into the matching locations:
   - ReplicatedStorage/Modules/Constants.lua
   - ReplicatedStorage/Modules/EnemyConfig.lua
   - ReplicatedStorage/Modules/WaveConfig.lua
   - ServerScriptService/Modules/MapBuilder.lua
   - ServerScriptService/Modules/PlayerService.lua
   - ServerScriptService/Modules/EnemyService.lua
   - ServerScriptService/Modules/WaveManager.lua
   - ServerScriptService/GameServer.server.lua
   - StarterPlayerScripts/ClientUI.client.lua

4) Press Play. The map, remotes, and gameplay will build automatically.
   - Click READY to start.
   - Upgrade using the neon stations in the arena between waves.

Notes:
- Only default primitives are used. You can swap materials/colors easily.
- Add custom models or sounds later by editing MapBuilder.lua and EnemyService.lua.
