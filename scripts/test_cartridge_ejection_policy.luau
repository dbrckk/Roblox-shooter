-- Cosmetic ejection must remain bounded, deterministic and device aware.
local Ejection = require("../src/shared/CartridgeEjectionPolicy")
local Pool = require("../src/shared/TransientFxPool")
local ids = {"AssaultRifle", "Pistol", "Shotgun", "Sniper"}
for _, id in ipairs(ids) do
    local plan = Ejection.plan(id, "QUALITY", false, 1)
    assert(plan and plan.anchor and plan.delay >= 0)
    assert(plan.duration > 0 and plan.duration <= 0.5)
    assert(#plan.tint == 3 and #plan.size == 3)
    assert(#plan.origin == 3 and #plan.travel == 3 and #plan.tumble == 3)
    assert(plan.reflectance >= 0 and plan.reflectance <= 0.05)
    assert(plan.drop > 0 and plan.drop <= 0.5)
    assert(type(plan.hull) == "boolean")
    for _, x in ipairs(plan.origin) do
        assert(x == x and math.abs(x) <= 0.2)
    end
    for _, x in ipairs(plan.travel) do
        assert(x == x and math.abs(x) <= 1.0)
    end
    for _, x in ipairs(plan.tumble) do
        assert(x == x and math.abs(x) <= 2)
    end
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
assert(Ejection.plan("Sniper", "QUALITY", true, 1).anchor == "SniperEjectionPort",
    "Sniper casing must leave the breech, never the GLB Bolt model pivot")
assert(Ejection.plan("Pistol", "BALANCED", true, 1).delay == 0)
local rifle = Ejection.plan("AssaultRifle", "QUALITY", false, 1)
local pistol = Ejection.plan("Pistol", "QUALITY", false, 1)
local hull = Ejection.plan("Shotgun", "QUALITY", false, 1)
local sniper = Ejection.plan("Sniper", "QUALITY", false, 1)
assert(hull.hull and not rifle.hull and not pistol.hull and not sniper.hull,
    "Red polymer shotgun hull must not use reflective brass material")
assert(hull.reflectance == 0 and rifle.reflectance > 0
    and pistol.reflectance > 0 and sniper.reflectance > 0)
assert(rifle.travel[1] > sniper.travel[1]
    and sniper.travel[1] > pistol.travel[1]
    and pistol.travel[1] > hull.travel[1],
    "Different receivers require different lateral ejection velocity")
assert(hull.drop > sniper.drop and sniper.drop > rifle.drop
    and rifle.drop > pistol.drop, "Heavy hull has faster downward fall")
assert(hull.delay > rifle.delay and sniper.delay > rifle.delay)
assert(hull.size[1] > pistol.size[1]
    and sniper.size[1] > rifle.size[1])
local signatures = {}
for _, id in ipairs(ids) do
    local p = Ejection.plan(id, "QUALITY", false, 42)
    local key = tostring(p.travel[1]) .. "|" .. tostring(p.drop)
    assert(not signatures[key], "Each weapon must have a distinct shell trajectory")
    signatures[key] = true
end
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
