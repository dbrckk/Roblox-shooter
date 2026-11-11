-- Deterministic first-person FX scheduling independent of Roblox Studio.
local P = require("../src/shared/WeaponFxFramePolicy")
assert(P.flashReady("Pistol", 10, 10))
assert(P.flashReady("AssaultRifle", 10, 10.016))
assert(P.flashReady("Shotgun", 10, 10.1))
assert(not P.flashReady("Knife", 10, 10.016))
assert(not P.flashReady("Pistol", 10, 9.99), "Never emit before the shot")
assert(not P.flashReady("Pistol", 10, 10.19),
    "Do not draw a muzzle flash after a missed Android render")
assert(P.casingReady("AssaultRifle", "AssaultRifle", 10, 10.016))
assert(P.casingReady("Pistol", "Pistol", 10, 10))
assert(P.casingReady("Shotgun", "Shotgun", 10.39, 10.4),
    "Pump shell must align with the first valid post-action frame")
assert(P.casingReady("Sniper", "Sniper", 10.43, 10.48))
assert(not P.casingReady("Pistol", "Shotgun", 10, 10),
    "A weapon swap must never emit its predecessor's casing")
assert(not P.casingReady("Shotgun", "Shotgun", 10.39, 10.37))
assert(not P.casingReady("Sniper", "Sniper", 10.43, 10.8),
    "Do not emit an old shell after a long frame hitch")
for _, bad in ipairs({-1, math.huge, -math.huge, 0/0, "0", false}) do
    assert(not P.flashReady("Pistol", bad, 10))
    assert(not P.flashReady("Pistol", 10, bad))
    assert(not P.casingReady("Pistol", "Pistol", bad, 10))
    assert(not P.casingReady("Pistol", "Pistol", 10, bad))
end
assert(not P.flashReady(nil, 10, 10))
assert(not P.casingReady(nil, nil, 10, 10))
assert(not P.casingReady("Pistol", nil, 10, 10))
assert(not P.casingReady("Pistol", "Pistol", nil, 10))
print("IRON YARD: current-frame flash and casing admission / stale FX: OK")
