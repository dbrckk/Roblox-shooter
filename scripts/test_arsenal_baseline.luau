-- A fixed, zero-spread TTK baseline to flag unintentional weapon balance drift.
-- It is NOT a simulation of player accuracy, pellet dispersion or Roblox lag.
local Arsenal = require("../src/shared/WeaponConfig")
local expected = {
    AssaultRifle = { body = 5, head = 3, magazine = 30 },
    Pistol = { body = 3, head = 1, magazine = 14 },
    Shotgun = { body = 1, head = 1, magazine = 6 },
    Sniper = { body = 2, head = 1, magazine = 5 },
    Knife = { body = 1, head = 1 },
}
local TARGET_HEALTH = 100
for _, name in ipairs(Arsenal.Order) do
    local gun = Arsenal.get(name)
    local ref = expected[name]
    assert(gun and ref and gun.damage > 0 and gun.headshotDamage >= gun.damage,
        "All five guns have valid server damage")
    local pellets = gun.pellets or 1
    local bodyShots = math.ceil(TARGET_HEALTH / (gun.damage * pellets))
    local headShots = math.ceil(TARGET_HEALTH / (gun.headshotDamage * pellets))
    assert(bodyShots == ref.body, name .. " theoretical body-shot TTK drift")
    assert(headShots == ref.head, name .. " theoretical headshot TTK drift")
    assert(gun.magazineSize == ref.magazine, name .. " magazine drift")
    assert(gun.fireCooldown > 0 and gun.range > 0, name .. " cadence/range valid")
end
-- Pistol/knife are one-shot head/throw and shotgun theoretical all-pellet
-- body kill at zero distance. Do NOT alter these without an actual playtest.
print("IRON YARD five-weapon 100 HP theoretical body/headshot baseline: OK")
