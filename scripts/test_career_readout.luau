-- Pure shared podium and mobile career status regression.
local R = require("../src/shared/CareerReadout")
local function eq(x, y, reason) assert(x == y, reason .. ": " .. tostring(x)) end
eq(R.save("ONLINE", 570, 570).tone, "saved", "Saved only when equal")
eq(R.save("ONLINE", 570, 420).pending, 150, "Unsaved delta")
eq(R.save("ONLINE", 570, 420).compact, "150 XP PENDING", "Android compact")
eq(R.save("ONLINE", 420, 570).label, "CAREER / SYNCING...", "Replication reordering")
eq(R.save("ONLINE", 420, 570).tone, "pending", "No false saved badge")
eq(R.save("LOADING", 1, 0).tone, "pending", "Loading")
eq(R.save("STUDIO", 120, 0).label, "STUDIO / SESSION ONLY", "Studio")
eq(R.save("LOCKED", 120, 0).label, "SAVE BUSY / RETRYING", "Lease conflict")
for _, status in ipairs({"UNAVAILABLE", "RETRYING", "CLOSED"}) do
    eq(R.save(status, 120, 120).tone, "warning", "No offline success")
end
eq(R.save(nil, 120, 120).tone, "warning", "Missing status")
eq(R.save("ONLINE", 0, 0).tone, "saved", "Empty career")
eq(R.save("ONLINE", 1.99, 1.1).tone, "saved", "Integer semantics")
for _, bad in ipairs({-1, math.huge, 0/0}) do
    eq(R.count(bad), 0, "Bad count")
end
eq(R.count(nil), 0, "Absent value")
eq(R.count(99.9), 99, "Truncate")
local rank = R.rank(125, 1)
eq(rank.toNext, 125, "Remaining to rank 2")
eq(rank.fraction, 0.5, "Rank bar 50%")
eq(R.rank(0, 1).toNext, 250, "First milestone")
eq(R.rank(250, 2).toNext, 750, "Rank 2 target")
eq(R.rank(999, 2).toNext, 1, "Just before level 3")
local top = R.rank(250 * 999 * 999, 1000)
assert(top.maxed and top.fraction == 1 and top.toNext == 0)
eq(R.rank(0, 0).rank, 1, "Minimum rank")
eq(R.rank(0/0, 1).fraction, 0, "Corrupt XP bar safe")
print("IRON YARD career save status, podium and rank readout regression: OK")
