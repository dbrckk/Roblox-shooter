-- Original NEON STRIKE bot balance. Server-side AI; no inference API required.
local BotConfig = {}

BotConfig.MaxBots = 4
BotConfig.MaxCombatants = 6
BotConfig.ThinkInterval = 0.2
BotConfig.NavigationRefresh = 1.2
BotConfig.DespawnAfterDeath = 2.5
BotConfig.MaximumSightDistance = 145
BotConfig.MaximumAttackDistance = 115
BotConfig.Damage = 14
BotConfig.BotNames = { "Vega", "Nova", "Kestrel", "Cipher" }

-- All bots are deliberately imperfect: finite reaction, aim drift and fire cadence.
BotConfig.Difficulties = {
    { label = "Rookie", reaction = 0.65, aimErrorDegrees = 3.6, aimSpeed = 2.8, cooldown = 0.82, speed = 13 },
    { label = "Standard", reaction = 0.45, aimErrorDegrees = 2.1, aimSpeed = 4.4, cooldown = 0.63, speed = 14 },
    { label = "Veteran", reaction = 0.32, aimErrorDegrees = 1.4, aimSpeed = 5.2, cooldown = 0.52, speed = 15 },
    { label = "Elite", reaction = 0.27, aimErrorDegrees = 1.0, aimSpeed = 6.2, cooldown = 0.48, speed = 16 },
}

BotConfig.Spawns = {
    Vector3.new(-112, 4, 105),
    Vector3.new(112, 4, 105),
    Vector3.new(-108, 4, -106),
    Vector3.new(108, 4, -106),
}

BotConfig.PatrolPoints = {
    Vector3.new(-135, 3, 68),
    Vector3.new(135, 3, 68),
    Vector3.new(-136, 3, -102),
    Vector3.new(136, 3, -102),
    Vector3.new(-63, 3, 113),
    Vector3.new(65, 3, 112),
    Vector3.new(-62, 3, -115),
    Vector3.new(63, 3, -115),
}
return BotConfig
