-- IRON YARD / last-person-left lobby reset regression.
-- No live Roblox service needed: server tick uses the SAME pure predicate.
local Policy = require("../src/shared/MatchLobbyPolicy")
for _, phase in ipairs({"COUNTDOWN", "LIVE", "DUEL_PREP",
    "DUEL_BREAK", "RESULTS"}) do
    assert(Policy.shouldReset(0, phase, "DUEL", true),
        "Empty server cannot retain a duel or its podium")
    assert(Policy.shouldReset(0, phase, "FFA", false),
        "Empty server must clear a final FFA scoreboard")
    for _, n in ipairs({1,2,3,8}) do
        assert(not Policy.shouldReset(n, phase, "DUEL", true),
            "Remaining duel player must be resolved by forfeit logic")
        assert(not Policy.shouldReset(n, phase, "FFA", false),
            "Joining or playing humans must not trigger empty reset")
    end
end
assert(Policy.shouldReset(0, "WAITING", "DUEL", true),
    "New player must never inherit a previous duel mode")
assert(Policy.shouldReset(0, "WAITING", "FFA", true),
    "A stale duel reference cannot leak into a fresh waiting room")
assert(Policy.shouldReset(0, "WAITING", "DUEL", false),
    "Bad mode must be cleared even when the duel reference is gone")
assert(not Policy.shouldReset(0, "WAITING", "FFA", false),
    "Empty WAITING lobby is already clean; no repeated publishing")
for _, bad in ipairs({-1, 0/0, math.huge, 1.5}) do
    assert(not Policy.shouldReset(bad, "RESULTS", "DUEL", true))
end
assert(not Policy.shouldReset("0", "RESULTS", "DUEL", true))
print("IRON YARD empty lobby: FFA/duel results cleared, survivors preserved, idempotent waiting OK")
