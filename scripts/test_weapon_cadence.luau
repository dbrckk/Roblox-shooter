-- Exact fire cadence shared by server security and local prediction.
local Config = require("../src/shared/WeaponConfig")

for _, weaponId in ipairs(Config.Order) do
    local config = Config.get(weaponId)
    local readyAt = Config.nextGlobalFireAt(weaponId, 10)
    assert(math.abs(readyAt - (10 + config.fireCooldown)) < 1e-8,
        "Global cooldown does not match weapon " .. weaponId)
    assert(readyAt > 10, "Every weapon must have a positive interval")
end

local shotgunReady = Config.nextGlobalFireAt("Shotgun", 10)
assert(10.3 < shotgunReady and shotgunReady < 10.9,
    "Shotgun swap must not become a faster pistol shot")
assert(shotgunReady > Config.nextGlobalFireAt("Pistol", 10),
    "Heavy weapons cannot be cancelled by a pistol swap")
local sniperReady = Config.nextGlobalFireAt("Sniper", 10)
assert(sniperReady > shotgunReady, "Sniper weapon must retain long recovery")
local okInvalid = pcall(function() Config.nextGlobalFireAt("Exploit", 10) end)
assert(not okInvalid, "Unknown client weapon id must not bypass cadence")
local okTime = pcall(function() Config.nextGlobalFireAt("Pistol", 0 / 0) end)
assert(not okTime, "Invalid non-finite timestamps must fail")
print("IRON YARD server/client weapon-swap cadence and quick-throw gating: OK")
