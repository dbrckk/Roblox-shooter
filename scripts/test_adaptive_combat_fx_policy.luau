-- Adaptive combat FX never changes user graphics quality or server combat.
local Adaptive = require("../src/shared/AdaptiveCombatFxPolicy")
local Pool = require("../src/shared/TransientFxPool")

local function samples(state, dt, n, preset, touch)
    local cap
    for _ = 1, n do
        cap = Adaptive.sample(state, dt, preset, touch)
    end
    return cap
end

local q = Adaptive.new()
assert(Adaptive.cap(q, "QUALITY", true) == 72)
assert(samples(q, 0.05, 20, "QUALITY", true) == 72,
    "One slow second is not enough for a downgrade")
assert(samples(q, 0.05, 21, "QUALITY", true) == 48,
    "Sustained mobile slowdown must reduce only one visual FX tier")
assert(samples(q, 0.05, 41, "QUALITY", true) == 24,
    "Second sustained slowdown may reduce QUALITY FX to ECO pool size")
assert(samples(q, 0.034, 120, "QUALITY", true) == 24,
    "Intermediate frame times must not cause tier oscillation")
assert(samples(q, 0.016, 260, "QUALITY", true) == 48,
    "Recovery restores one tier, not a sudden full-budget burst")
assert(samples(q, 0.016, 260, "QUALITY", true) == 72,
    "Sustained fast frames eventually restore full premium effects")

local b = Adaptive.new()
assert(samples(b, 0.05, 45, "BALANCED", true) == 24)
assert(samples(b, 0.05, 100, "BALANCED", true) == 24,
    "BALANCED never degrades below bounded ECO FX capacity")
assert(samples(b, 0.016, 520, "BALANCED", true) == 48)
assert(Adaptive.sample(b, 0.05, "QUALITY", true) == 72,
    "Changing quality preset clears the previous adaptive tier")
assert(Adaptive.sample(b, 0.05, "ECO", true) == 24)
assert(samples(b, 0.05, 160, "ECO", true) == 24,
    "ECO cannot degrade again")
assert(Adaptive.sample(b, 0.05, "BALANCED", false) == 80)
assert(samples(b, 0.05, 160, "QUALITY", false) == 96,
    "Desktop keeps full original pool size")

local hitch = Adaptive.new()
assert(samples(hitch, 0.05, 20, "QUALITY", true) == 72)
assert(Adaptive.sample(hitch, 9, "QUALITY", true) == 72)
assert(Adaptive.sample(hitch, 0/0, "QUALITY", true) == 72)
assert(Adaptive.sample(hitch, math.huge, "QUALITY", true) == 72)
assert(Adaptive.sample(hitch, 0, "QUALITY", true) == 72)
assert(samples(hitch, 0.05, 20, "QUALITY", true) == 72,
    "Android background resumes and bad delta times cannot trigger a downgrade")
assert(samples(hitch, 0.05, 21, "QUALITY", true) == 48)
assert(Adaptive.sample(hitch, 20, "QUALITY", true) == 48,
    "A resume hitch cannot make the already-reduced budget worse")
assert(samples(hitch, 0.016, 260, "QUALITY", true) == 72,
    "Stable performance recovers after suspension")

-- At 24 effects the original pool still prioritizes confirmed hits and
-- muzzle flashes over low-priority debris; no gameplay messaging changes.
local slots = {}
for _ = 1, 24 do
    assert(Pool.claim(slots, 100, 0.3, Adaptive.cap({tier=2}, "QUALITY", true), 1))
end
assert(#slots == 24)
local core = Pool.claim(slots, 100.01, 0.2, 24, 4)
assert(core and core.priority == 4, "Confirmed hits still preempt ambient debris")
assert(Pool.claim(slots, 100.02, 0.2, 24, 1) ~= nil,
    "Lower-priority debris still cycles within the same pool")
print("IRON YARD adaptive Android FX: hysteresis, resume safety, priority and full recovery OK")
