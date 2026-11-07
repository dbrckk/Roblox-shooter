local M = require("../src/shared/BotMotionProfile")

local function near(actual, expected, tolerance, label)
    assert(math.abs(actual - expected) <= (tolerance or 0.00001),
        label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local v, f, s = M.weights(0, -16, 16, 16, true)
near(v, 1, nil, "normal travel")
near(f, 1, nil, "forward motion")
near(s, 0, nil, "no strafing")
v, f, s = M.weights(0, 16, 16, 16, true)
near(v, 1, nil, "reverse travel")
near(f, -1, nil, "reverse leg direction")
v, f, s = M.weights(10, 0, 10, 16, true)
near(v, 0.625, nil, "speed scaling")
near(s, 1, nil, "right strafe")
v, f, s = M.weights(10, 0, 0, 16, true)
near(v, 0, nil, "no skating while blocked")
v, f, s = M.weights(0, -16, 16, 16, false)
near(v, 0, nil, "airborne feet do not run")
near(M.smooth(0, 1, 0, 9), 0, nil, "zero dt")
assert(M.smooth(0, 1, 0.1, 10) > M.smooth(0, 1, 0.1, 3),
    "Higher response blends more quickly")
assert(M.smooth(0.5, 1, 0.1, 10) < 1, "No overshoot")
near(M.gaitPhase(0, 0), 0, nil, "no distance: no foot cycle")
near(M.gaitPhase(0, math.pi / 0.80), math.pi, 0.00001, "phase tracks distance")
near(M.interval(100), 1 / 15, nil, "visible rig runs at 15Hz")
near(M.interval(300), 1 / 8, nil, "distant rig runs at 8Hz")
assert(M.turnSignal(0, -1, 1, 0, 0.1) > 0,
    "Clockwise chassis turn should produce a positive planted pivot")
assert(M.turnSignal(0, -1, -1, 0, 0.1) < 0,
    "Counter-clockwise chassis turn must mirror the same pose")
near(M.turnSignal(0, -1, 0, -1, 0.1), 0, nil, "no torso motion on stable facing")
near(M.turnSignal(0, -1, 0, 0, 0.1), 0, nil, "zero-length facing is ignored")
near(M.turnSignal(0, -1, 1, 0, 0), 0, nil, "zero elapsed duration is ignored")
near(M.turnSignal(0, -1, 0/0, 0, 0.1), 0, nil, "nonfinite aim rejected")
assert(math.abs(M.turnSignal(0, -1, 1, 0, 0.01)) <= 1,
    "Fast rotations remain pose bounded")
near(M.reversalSignal(0, -12, 0, 12), 1, nil, "reversing movement plants both feet")
near(M.reversalSignal(0, -12, 0, -12), 0, nil, "continuing forward does not brake")
near(M.reversalSignal(0, -12, 12, 0), 0, nil, "side strafing is not a reversal")
near(M.reversalSignal(0, -2, 0, 2), 0, nil, "idle positional jitter is ignored")
near(M.reversalSignal(0/0, -12, 0, 12), 0, nil, "nonfinite velocity ignored")
assert(M.smooth(1, 0, 0.1, 12) < 0.5,
    "Pivot impulse should relax quickly instead of freezing a stiff pose")
print("IRON YARD grounded R6 turning, actual reversal braking, poses and LOD: OK")
