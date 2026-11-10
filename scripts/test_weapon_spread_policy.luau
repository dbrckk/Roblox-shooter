-- IRON YARD / authoritative accuracy profile, simulated cadence and resets.
local Spread = require("../src/shared/WeaponSpreadPolicy")
local WeaponConfig = require("../src/shared/WeaponConfig")
local ar = WeaponConfig.get("AssaultRifle")
local burst, stamp = nil, nil
local values = {}
for i = 1, 12 do
    local at = 10 + (i - 1) * ar.fireCooldown
    local degrees, newCount = Spread.next("AssaultRifle", stamp, burst, at,
        ar.spreadDegrees)
    assert(degrees and degrees >= 0 and degrees <= ar.spreadDegrees)
    values[i] = degrees
    if i > 1 then assert(degrees >= values[i - 1]) end
    burst, stamp = newCount, at
end
assert(values[1] == Spread.FIRST_SHOT_DEGREES)
assert(values[1] < ar.spreadDegrees / 3,
    "First shot must be substantially more precise than full-auto spray")
assert(values[6] == ar.spreadDegrees and values[12] == ar.spreadDegrees,
    "Auto fire must eventually return to existing maximum dispersion")
local recovered, resetCount = Spread.next("AssaultRifle", stamp, burst,
    stamp + Spread.RESET_SECONDS + 0.001, ar.spreadDegrees)
assert(recovered == values[1] and resetCount == 1,
    "A brief tap-fire pause resets first-shot accuracy")
local atBoundary, countBoundary = Spread.next("AssaultRifle", 10, 5,
    10 + Spread.RESET_SECONDS, ar.spreadDegrees)
assert(atBoundary == values[1] and countBoundary == 1,
    "Recovery includes the reset threshold")
assert(Spread.next("AssaultRifle", 10, 5, 10, ar.spreadDegrees) == values[1],
    "Clock reversal or a same-tick timestamp cannot grow a burst")
assert(Spread.next("AssaultRifle", 10, 0/0, 10.1, ar.spreadDegrees) == values[1],
    "Invalid client-independent state resets safely")
for _, id in ipairs({"Shotgun", "Pistol", "Sniper", "Knife"}) do
    local config = WeaponConfig.get(id)
    local expected = config.spreadDegrees or 0
    local degrees, count = Spread.next(id, 1, 6, 2, expected)
    assert(degrees == expected and count == 0,
        "Non-automatic weapon spread must retain the baseline: " .. id)
end
for _, invalid in ipairs({0/0, math.huge, -1, -math.huge}) do
    assert(Spread.next("AssaultRifle", 0, 0, invalid, 1.1) == nil)
    assert(Spread.next("AssaultRifle", 0, 0, 10, invalid) == nil)
end
assert(Spread.next("AssaultRifle", 0, 0, 10, 46) == nil)
assert(Spread.next("AssaultRifle", 0, 0, 10, nil) == nil)
assert(Spread.next("AssaultRifle", nil, nil, 10, 0) == 0)
local stateAt, stateBurst = nil, 0
for i = 1, 50000 do
    local at = i * 0.115
    local spread, count = Spread.next("AssaultRifle", stateAt, stateBurst, at, 1.1)
    assert(spread and spread <= 1.1 and count >= 1 and count <= 6)
    stateAt, stateBurst = at, count
end
local restarted = Spread.next("AssaultRifle", nil, nil, 0, 1.1)
assert(restarted == Spread.FIRST_SHOT_DEGREES,
    "New life/round state must not carry burst recoil")
print("IRON YARD accepted-shot authoritative burst cone: 50k shots, recovery and five guns OK")
