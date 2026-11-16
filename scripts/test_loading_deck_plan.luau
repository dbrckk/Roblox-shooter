local Plan = require("../src/shared/LoadingDeckPlan")
local Movement = require("../src/shared/MovementConfig")

assert(Plan.x == 13 and Plan.z == 85 and Plan.top == 8.5)
assert(Plan.top > Movement.mantleMaxHeight, "The route must work without an uphill mantle")
local ramp = Plan.ramp()
assert(ramp.pitch > 0 and ramp.pitch < math.rad(20), "Moderate ramp pitch")
local midY = ramp.y + math.cos(ramp.pitch) * ramp.height / 2
local midZ = ramp.z + math.sin(ramp.pitch) * ramp.height / 2
local rise = math.sin(ramp.pitch) * ramp.length / 2
local run = math.cos(ramp.pitch) * ramp.length / 2
assert(math.abs(midY + rise - Plan.top) < 0.001 and math.abs(midY - rise) < 0.001,
    "The walking surface joins both ground and deck")
local deckEdge = Plan.z + Plan.depth / 2
assert(midZ - run < deckEdge and midZ - run > deckEdge - 0.25, "Small deck overlap")
assert(math.abs(midZ + run - 116) < 0.001)
assert(ramp.x - ramp.width / 2 > Plan.x - Plan.width / 2
    and ramp.x + ramp.width / 2 < Plan.x + Plan.width / 2, "Ramp stays inside the width of the deck")

local left, right = Plan.support(-1), Plan.support(1)
assert(left.x - left.width / 2 > Plan.x - Plan.width / 2)
assert(right.x + right.width / 2 < Plan.x + Plan.width / 2)
assert(left.y - left.height / 2 == 0 and right.y - right.height / 2 == 0)
assert(left.height == Plan.top - Plan.height and right.height == left.height)
assert(right.x - left.x - (left.width + right.width) / 2 >= 12,
    "Keep a wide passage under the deck")
-- A 4.2-stud character envelope fits along the offset approach into the
-- underpass without entering the adjacent ramp or left support.
assert(ramp.x - ramp.width / 2 - (left.x + left.width / 2) > 4.2)
print("IRON YARD transfer deck, ramp and underpass: OK")
