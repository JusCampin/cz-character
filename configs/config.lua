-- cz-character config
Config = Config or {}
Config.Character = Config.Character or {}

-- Maximum number of characters a user may create
Config.Character.max_characters = 3

-- Enable NUI character menu
Config.Character.enable_nui = true

-- NUI settings
Config.Character.ui = {
    width = 600,
    height = 400
}

-- Spawn points: can list multiple sets; server will pick one at random for new characters
Config.Character.SpawnPoints = Config.Character.SpawnPoints or {
    { x = -540.58, y = -212.02, z = 37.65, heading = 208.88 }, -- defaultSpawn
    { x = 354.09, y = -603.54, z = 28.78, heading = 260.0 }     -- hospitalSpawn
}

-- Per-resource development/debug flag (local only)
Config.Dev = Config.Dev or {}
Config.Dev.enabled = Config.Dev.enabled or true -- set to true on development servers to enable verbose logging

return Config
