-- Spawn scoring is shared by human and AI respawns.
local Risk = require("../src/shared/SpawnSafety")

local score = Risk.score
assert(score(95, 0, Risk.EXPOSURE_RANGE, 0)
    > score(95, 1, 95, 0), "Cover should beat an equally distant open pad")
assert(score(135, 0, Risk.EXPOSURE_RANGE, 0)
    > score(42, 0, Risk.EXPOSURE_RANGE, 0), "Avoid spawns beside active fighters")
assert(score(150, 1, 150, 0)
    > score(60, 0, Risk.EXPOSURE_RANGE, 0), "Distance must still dominate close-range cover")
assert(score(110, 1, 90, 0)
    > score(110, 4, 60, 0), "Multiple visible opponents should raise danger")
assert(score(110, 0, Risk.EXPOSURE_RANGE, 0)
    == score(110, 0, 5, 0), "Invisible enemies cannot add exposure penalty")
assert(score(110, 0, Risk.EXPOSURE_RANGE, 500)
    == score(110, 0, Risk.EXPOSURE_RANGE, 6), "Randomized tiebreak must be capped")
assert(score(110, 0, Risk.EXPOSURE_RANGE, -500)
    == score(110, 0, Risk.EXPOSURE_RANGE, -6), "Negative tiebreak must be capped")
-- Genuine emergency placements are checked against physical cover before
-- being scored. No clear cell means nil, not an unsafe guess.
local checked, scored = 0, 0
local x, z = Risk.chooseEmergencyPad(function(px, pz)
    checked += 1
    assert(px >= -126 and px <= 126 and pz >= -126 and pz <= 126)
    return px == 42 and pz == -42
end, function(px, pz)
    scored += 1
    assert(px == 42 and pz == -42)
    return 100
end)
assert(x == 42 and z == -42, "Emergency fallback finds a physically clear cell")
assert(checked == 49 and scored == 1,
    "Exactly 49 bounded physical checks, scoring only free cells")
local pickedX, pickedZ = Risk.chooseEmergencyPad(function(px, pz)
    return (px == 0 and pz == 0) or (px == 126 and pz == 126)
end, function(px, pz)
    return px + pz
end)
assert(pickedX == 126 and pickedZ == 126, "Choose safer of clear emergency pads")
assert(Risk.chooseEmergencyPad(function() return false end,
    function() error("Never score an obstructed spawn") end) == nil,
    "Fully blocked arena must fail closed rather than teleport into cover")
assert(Risk.chooseEmergencyPad(nil, function() return 1 end) == nil)
assert(Risk.chooseEmergencyPad(function() return true end, nil) == nil)
assert(Risk.chooseEmergencyPad(function() return true end,
    function() return math.huge end) == nil,
    "Invalid exposure score must never authorize a spawn")
assert(Risk.chooseEmergencyPad(function() return true end,
    function() return 0/0 end) == nil,
    "NaN exposure score must never authorize a spawn")
print("IRON YARD spawn scoring and bounded collision-free emergency recovery: OK")
