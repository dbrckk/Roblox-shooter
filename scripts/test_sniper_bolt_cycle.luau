-- IRON YARD / actual 4-stage precision bolt timing: deterministic offline.
local Cycle = require("../src/shared/SniperBoltCycle")
local Ejection = require("../src/shared/CartridgeEjectionPolicy")
local p = Ejection.plan("Sniper", "QUALITY", false, 1)
assert(p and p.delay == Cycle.PULL_END,
    "Spent sniper case leaves at the actual maximum bolt pull")
local function sample(t, reloading)
    return Cycle.sample(t, reloading)
end
local a, b = sample(0)
assert(a == 0 and b == 0, "No movement before shot cycle")
a, b = sample(Cycle.UNLOCK_START)
assert(a == 0 and b == 0)
a, b = sample((Cycle.UNLOCK_START + Cycle.UNLOCK_END) / 2)
assert(a > 0 and a < 1 and b == 0, "Lift first; do not pull locked bolt")
a, b = sample(Cycle.UNLOCK_END)
assert(a == 1 and b == 0)
a, b = sample(0.34)
assert(a == 1 and b > 0 and b < 1, "Unlock held through pull phase")
a, b = sample(Cycle.PULL_END)
assert(a == 1 and b == 1, "Case ejection at full pull")
a, b = sample(0.49)
assert(a == 1 and b > 0 and b < 1, "Return forward before relocking")
a, b = sample(Cycle.RETURN_END)
assert(a == 1 and b == 0)
a, b = sample(0.61)
assert(a > 0 and a < 1 and b == 0, "Relock only after returning")
a, b = sample(Cycle.LOCK_END)
assert(a == 0 and b == 0)
a, b = sample(2.0)
assert(a == 0 and b == 0)
a, b = sample(Cycle.PULL_END, true)
assert(a == 0 and b == 0, "Authoritative reload suppresses shot bolt")
for _, invalid in ipairs({-1, 0/0, math.huge, -math.huge, "0", false}) do
    local lift, pull = sample(invalid)
    assert(lift == 0 and pull == 0, "Invalid age must not move bolt")
end
for i = 0, 900 do
    local lift, pull = sample(i / 1000)
    assert(lift >= 0 and lift <= 1 and pull >= 0 and pull <= 1)
end
print("IRON YARD: sniper unlock, pull, ejection, return, relock and cancel OK")

-- A confirmed server refill unlocks the sniper bolt immediately and
-- performs the same mechanically correct lift/pull/return/relock sequence.
-- This path never ejects a second casing or changes the weapon magazine.
assert(math.abs(Cycle.RELOAD_DURATION - 0.49) < 1e-9)
local rLift, rPull = Cycle.sampleReload(0, false)
assert(rLift == 0 and rPull == 0)
rLift, rPull = Cycle.sampleReload(0.08, false)
assert(rLift == 1 and rPull == 0)
rLift, rPull = Cycle.sampleReload(0.26, false)
assert(rLift == 1 and rPull == 1)
rLift, rPull = Cycle.sampleReload(0.39, false)
assert(rLift == 1 and rPull == 0)
rLift, rPull = Cycle.sampleReload(Cycle.RELOAD_DURATION, false)
assert(rLift == 0 and rPull == 0)
for i = 0, 490 do
    local age = i / 1000
    local lift, pull = Cycle.sampleReload(age, false)
    local fromShotLift, fromShotPull = Cycle.sample(
        age + Cycle.UNLOCK_START, false)
    assert(math.abs(lift - fromShotLift) < 1e-9
        and math.abs(pull - fromShotPull) < 1e-9,
        "Reload must reuse the exact shot bolt mechanism")
    assert(lift >= 0 and lift <= 1 and pull >= 0 and pull <= 1)
end
for _, bad in ipairs({-1, 0/0, math.huge, -math.huge, "bad"}) do
    assert(select(1, Cycle.sampleReload(bad, false)) == 0)
    assert(select(2, Cycle.sampleReload(bad, false)) == 0)
end
assert(select(1, Cycle.sampleReload(0.26, true)) == 0)
assert(select(2, Cycle.sampleReload(0.26, true)) == 0)
local shotLift, shotPull = Cycle.sample(0.34, false)
local chosenLift, chosenPull = Cycle.present(0.34, 0.26, false)
assert(shotLift == chosenLift and shotPull == chosenPull,
    "Accepted newer shot must supersede pending reload cycle")
assert(select(1, Cycle.present(0, 0.26, false)) == 0)
assert(select(2, Cycle.present(0, 0.26, false)) == 0)
assert(select(1, Cycle.present(2, 0.26, false)) == 1)
assert(select(2, Cycle.present(2, 0.26, false)) == 1)
assert(select(1, Cycle.present(2, 0.26, true)) == 0)
for i = 1, 3600 do
    assert(select(1, Cycle.sample(i / 60 + 1, false)) == 0)
    assert(select(2, Cycle.sample(i / 60 + 1, false)) == 0)
end
print("IRON YARD sniper: authoritative refill rack, shot precedence, cancellation and idle mobile path OK")
