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
print("IRON YARD bounded bot detour selection and path retry backoff: OK")
