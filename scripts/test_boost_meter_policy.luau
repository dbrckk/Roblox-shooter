-- IRON YARD / no excessive HUD Tweens while sprinting, boosting or idle.
local Policy = require("../src/shared/BoostMeterPolicy")
assert(Policy.MIN_INTERVAL == 0.1 and Policy.MIN_DELTA == 0.005)
assert(Policy.zone(1) == "NORMAL")
assert(Policy.zone(0.25) == "WARNING")
assert(Policy.zone(0.12) == "CRITICAL")

local previous, at = nil, nil
local draw, ratio, zone = Policy.shouldDraw(previous, at, 1, 0)
assert(draw and ratio == 1 and zone == "NORMAL")
previous, at = ratio, 0
for i = 1, 1200 do
    assert(not Policy.shouldDraw(previous, at, 1, i / 60),
        "Full meter must create zero repeated idle Tweens")
end
assert(not Policy.shouldDraw(previous, at, 0.99, 0.01),
    "Rapid per-frame updates must be rejected")
assert(not Policy.shouldDraw(previous, at, 0.999, 0.2),
    "Sub-half-percent noise must not animate")
draw, ratio, zone = Policy.shouldDraw(previous, at, 0.8, 0.3)
assert(draw and ratio == 0.8 and zone == "NORMAL")
previous, at = ratio, 0.3
assert(not Policy.shouldDraw(previous, at, 0.7, 0.32),
    "Ten percent fuel change does not bypass frame-rate budget")
draw, ratio, zone = Policy.shouldDraw(previous, at, 0.24, 0.32)
assert(draw and zone == "WARNING",
    "Warnings must react instantly despite update budget")
previous, at = ratio, 0.32
draw, ratio, zone = Policy.shouldDraw(previous, at, 0.11, 0.33)
assert(draw and zone == "CRITICAL",
    "Critical transition cannot wait 100ms")
previous, at = ratio, 0.33
assert(Policy.shouldDraw(previous, at, 0, 0.34),
    "Empty fuel must display immediately")
assert(Policy.shouldDraw(0, 0.34, 1, 0.35),
    "Full refill must display immediately")
assert(not Policy.shouldDraw(0.5, 2, 0.4, 1),
    "Reversed clocks must not emit a Tween")

for _, invalid in ipairs({0 / 0, math.huge, -math.huge}) do
    assert(not Policy.shouldDraw(1, 1, invalid, 2),
        "Invalid fuel ratios are rejected")
    assert(not Policy.shouldDraw(1, 1, 0.5, invalid),
        "Invalid clocks are rejected")
end
local low, normalized = Policy.shouldDraw(nil, nil, -5, 0)
assert(low and normalized == 0)
local high, maxValue = Policy.shouldDraw(nil, nil, 5, 0)
assert(high and maxValue == 1)

-- 60 seconds @ 60FPS with 50 seconds of continuous drain/refill.
-- Previous HUD allocated 3601 Tweens; updated HUD should allocate less
-- than 600 and exactly zero during 10 seconds of static full fuel.
local tweens, prev, prevAt, idleTweens = 0, nil, nil, 0
for frame = 0, 3600 do
    local now = frame / 60
    local fuel
    if frame <= 1800 then
        fuel = 1 - frame / 1800
    elseif frame <= 3000 then
        fuel = (frame - 1800) / 1200
    else
        fuel = 1
    end
    local yes, value = Policy.shouldDraw(prev, prevAt, fuel, now)
    if yes then
        tweens += 1
        if frame > 3000 then idleTweens += 1 end
        prev, prevAt = value, now
    end
end
assert(tweens > 150 and tweens < 600,
    "Continuous fuel movement must be animated but bounded near 10Hz")
assert(idleTweens == 0, "Idle meter does not allocate post-refill Tweens")
print("IRON YARD boost HUD: 3601 frames, bounded Tweens and urgent colors: OK")
