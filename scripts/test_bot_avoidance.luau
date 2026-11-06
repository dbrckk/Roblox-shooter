-- The same candidate ordering and retry policy run on the game server.
local Planner = require("../src/shared/BotAvoidancePlan")

local expected = {
    { -2, 11 }, { -2, -11 },
    { 5, 16 }, { 5, -16 },
    { -12, 7 }, { -12, -7 },
}
local first = Planner.offsets(1, 0)
assert(#first == 6, "All six bounded escape directions must be considered")
for i, pair in ipairs(expected) do
    assert(first[i].forward == pair[1] and first[i].lateral == pair[2],
        "Detour ordering changed at candidate " .. i)
end

local reversed = Planner.offsets(1, 1)
local mirrored = Planner.offsets(-1, 0)
assert(reversed[1].lateral == -11 and mirrored[1].lateral == -11,
    "First preferred side must alternate after a failed attempt")
assert(Planner.offsets(1, 2)[1].lateral == 11, "Third escape attempt returns")
assert(Planner.offsets(nil, 0)[1].lateral == 11, "Default lateral preference")

assert(Planner.retryDelay(0) == 0.9, "First failed path retries at 0.9s")
assert(Planner.retryDelay(2) == 2.0, "Backoff grows with failures")
assert(Planner.retryDelay(100) == 4.2, "Backoff must be capped")
assert(Planner.retryDelay(-2) == 0.9, "Invalid negative failure count")
assert(Planner.blockedAhead(4, 3), "Future blockage must invalidate")
assert(Planner.blockedAhead(3, 3), "Current waypoint blockage must invalidate")
assert(not Planner.blockedAhead(2, 3), "Behind-waypoint blockage is already cleared")
assert(not Planner.blockedAhead(nil, 3), "Missing block index must be harmless")
assert(not Planner.blockedAhead(0, 3), "Zero index must be rejected")
assert(not Planner.blockedAhead(3, 0), "Invalid current index must be rejected")
assert(Planner.targetChanged(21, 20), "Large goal shift must invalidate stale route")
assert(not Planner.targetChanged(20, 20), "At threshold existing path stays usable")
assert(not Planner.targetChanged(nil, 20), "Missing shift must not invalidate")
assert(Planner.reusePath(true, 8, 2, 20, 6), "Valid route must be reused")
assert(not Planner.reusePath(true, 25, 2, 20, 6), "Moved target requires a new path")
assert(not Planner.reusePath(true, 8, 6, 20, 6), "Old route must expire")
assert(not Planner.reusePath(false, 8, 2, 20, 6), "No waypoints means no reusable route")
assert(not Planner.reusePath(true, 8, -1, 20, 6), "Invalid path age must be rejected")
print("IRON YARD bounded bot detours, path reuse, revalidation and backoff: OK")
