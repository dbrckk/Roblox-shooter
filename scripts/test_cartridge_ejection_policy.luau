-- Cosmetic ejection must remain bounded, deterministic and device aware.
local Ejection = require("../src/shared/CartridgeEjectionPolicy")
local Pool = require("../src/shared/TransientFxPool")
local ids = {"AssaultRifle", "Pistol", "Shotgun", "Sniper"}
for _, id in ipairs(ids) do
    local plan = Ejection.plan(id, "QUALITY", false, 1)
    assert(plan and plan.anchor and plan.delay >= 0)
    assert(plan.duration > 0 and plan.duration <= 0.5)
    assert(#plan.tint == 3 and #plan.size == 3)
    assert(Ejection.plan(id, "ECO", true, 1) == nil)
    assert(Ejection.plan(id, "BALANCED", false, 1) == plan)
    assert(Ejection.plan(id, "QUALITY", true, 1) == plan)
end
assert(Ejection.plan("Knife", "QUALITY", false, 1) == nil)
assert(Ejection.plan("Unknown", "QUALITY", false, 1) == nil)
assert(not Ejection.plan("AssaultRifle", "BALANCED", true, 1))
assert(Ejection.plan("AssaultRifle", "BALANCED", true, 2))
assert(not Ejection.plan("AssaultRifle", "BALANCED", true, 3))
assert(Ejection.plan("Shotgun", "BALANCED", true, 1).delay > 0)
assert(Ejection.plan("Shotgun", "BALANCED", true, 1).anchor == "ShotgunEjectionPort",
    "Spent 12-gauge hull must exit the dedicated receiver port, not its center")
assert(Ejection.plan("Sniper", "QUALITY", true, 1).delay > 0)
assert(Ejection.plan("Pistol", "BALANCED", true, 1).delay == 0)
for _, value in ipairs({0, -1, 1.5, math.huge, -math.huge, 0/0}) do
    assert(Ejection.plan("Pistol", "QUALITY", false, value) == nil)
end
assert(Ejection.plan("Pistol", "QUALITY", false, nil) == nil)
assert(Ejection.arc(0, 0.3) == 0)
assert(Ejection.arc(1, 0.3) == 0)
assert(math.abs(Ejection.arc(0.5, 0.3) - 0.3) < 0.00001)
assert(math.abs(Ejection.arc(0.25, 0.4) - 0.3) < 0.00001)
assert(Ejection.arc(0/0, 0.3) == 0)
assert(Ejection.arc(0.2, math.huge) == 0)
local caps = {ECO = 24, BALANCED = 48, QUALITY = 72}
for _, preset in ipairs({"ECO", "BALANCED", "QUALITY"}) do
    local slots = {}
    local cap = Pool.cap(preset, true)
    assert(cap == caps[preset])
    for i = 1, 18000 do
        local p = Ejection.plan("AssaultRifle", preset, true, i)
        if p then Pool.claim(slots, i * 0.04, p.duration, cap, 1) end
        assert(#slots <= cap, "Casings never bypass existing mobile FX pool")
    end
end
print("IRON YARD weapon shell ejection: four profiles, ECO off, Android and pool bound: OK")
