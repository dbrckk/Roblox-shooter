local P = require("../src/shared/AutomaticFireCadence")
local WeaponConfig = require("../src/shared/WeaponConfig")
assert(P.IDLE_POLL_SECONDS >= 0.08)
assert(P.COOLDOWN_MARGIN > 1.015 and P.COOLDOWN_MARGIN < 1.10)
assert(P.waitSeconds(nil) == P.IDLE_POLL_SECONDS)
assert(P.waitSeconds({}) == P.IDLE_POLL_SECONDS)
assert(P.waitSeconds(WeaponConfig.get("Pistol")) == P.IDLE_POLL_SECONDS)
assert(P.waitSeconds(WeaponConfig.get("Knife")) == P.IDLE_POLL_SECONDS)
local ar = WeaponConfig.get("AssaultRifle")
assert(P.isAutomatic(ar))
assert(P.waitSeconds(ar) > ar.fireCooldown * 1.015,
    "Held fire must not repeatedly fail the local cooldown gate")
assert(P.waitSeconds(ar) < ar.fireCooldown * 1.10,
    "Automatic fire should remain close to the configured gun cadence")
assert(P.waitSeconds(ar) > ar.fireCooldown * 0.40 * 2,
    "Do not waste 2.5x polling work between admitted shots")
for _, invalid in ipairs({0, -1, 0/0, math.huge}) do
    local config = {automatic=true, fireCooldown=invalid}
    assert(not P.isAutomatic(config))
    assert(P.waitSeconds(config) == P.IDLE_POLL_SECONDS)
end
assert(not P.isAutomatic({automatic=false, fireCooldown=0.115}))
assert(not P.isAutomatic({automatic=true, fireCooldown="fast"}))
assert(P.waitSeconds({automatic=true, fireCooldown=0.01})
    == P.MIN_AUTOMATIC_WAIT_SECONDS)
-- Repeated held input traverses semi-auto weapons without consuming ammo
-- or spawning another fire task; switching back resumes the auto cadence.
local held = {ar, WeaponConfig.get("Sniper"), ar}
assert(P.isAutomatic(held[1]) and not P.isAutomatic(held[2])
    and P.isAutomatic(held[3]))
assert(P.waitSeconds(held[2]) >= P.MIN_AUTOMATIC_WAIT_SECONDS)
print("IRON YARD automatic cadence interval and weapon-switch continuity: OK")
