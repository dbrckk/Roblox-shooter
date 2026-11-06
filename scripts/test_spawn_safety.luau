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
print("IRON YARD spawn exposure, cover and separation scoring: OK")
