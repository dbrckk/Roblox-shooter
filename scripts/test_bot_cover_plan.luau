local Plan = require("../src/shared/BotCoverPlan")
local right = Plan.offsets(1)
local left = Plan.offsets(-1)
assert(#right == 6, "Every retreat samples six bounded lanes at most")
for i, a in ipairs(right) do
    assert(a.back >= 10 and a.back <= 28, "Retreat distances bounded")
    assert(math.abs(a.lateral) <= 19, "Side steps bounded")
    assert(a.lateral == -left[i].lateral, "Side choices must mirror")
end
assert(right[1].lateral > 0 and right[2].lateral < 0, "Try both cover sides")
assert(Plan.score(true, 30, false) > Plan.score(false, 10, true),
    "Real solid cover beats a slightly closer exposed lane")
assert(Plan.score(false, 20, true) > Plan.score(false, 20, false),
    "Small deterministic side preference breaks ties")
assert(Plan.score(true, 0 / 0, true) == -math.huge, "Reject invalid scores")
assert(Plan.rejected(2, 10, 18), "Do not instantly retry stuck cover")
assert(Plan.rejected(Plan.FAILED_LANE_RADIUS, 10, 18), "Exclusion includes boundary")
assert(not Plan.rejected(10, 10, 18), "Alternatives remain usable")
assert(not Plan.rejected(2, 18, 18), "Failed lane recovers after cooldown")
assert(not Plan.rejected(0 / 0, 10, 18), "Invalid distance must not poison decisions")
print("IRON YARD physical cover prioritization and stuck-lane avoidance: OK")
