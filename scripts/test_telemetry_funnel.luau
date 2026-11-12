-- IRON YARD / executable funnel telemetry accounting (LOT 0b).
-- Verifies the pure counters only. No session is real here: this suite cannot
-- prove what players actually do on a published server, it proves the numbers
-- a dashboard would read are correct once such sessions exist.
local TelemetryFunnel = require("../src/shared/TelemetryFunnel")

local funnel = TelemetryFunnel.new()
local empty = TelemetryFunnel.snapshot(funnel)
assert(empty.uniquePlayers == 0 and empty.kills == 0 and #empty.weapons == 0,
    "A fresh funnel must be empty")
assert(empty.rounds.completed == 0 and empty.rounds.abandoned == 0,
    "A fresh funnel has no rounds")
assert(empty.rounds.abandonRate == 0 and empty.rounds.averageSeconds == 0,
    "Empty rounds must not divide by zero")
for _, stage in ipairs(TelemetryFunnel.STAGES) do
    assert(empty.stages[stage] == false, "Stage " .. stage .. " must start false")
end

-- 1. Join, then return: the second visit is the SECOND_SESSION marker.
assert(TelemetryFunnel.recordJoin(funnel, 1001) == "FIRST_SESSION", "first visit")
assert(TelemetryFunnel.snapshot(funnel).stages.JOINED == true, "JOINED must be set")
assert(TelemetryFunnel.recordJoin(funnel, 1002) == "FIRST_SESSION", "second player")
assert(TelemetryFunnel.snapshot(funnel).uniquePlayers == 2, "two distinct players")
assert(TelemetryFunnel.snapshot(funnel).stages.SECOND_SESSION == false,
    "A first visit is not a returning session")
assert(TelemetryFunnel.recordJoin(funnel, 1001) == "RETURNING", "returning player")
local snapshot = TelemetryFunnel.snapshot(funnel)
assert(snapshot.stages.SECOND_SESSION == true, "SECOND_SESSION must be set")
assert(snapshot.uniquePlayers == 2, "Returning must not add a unique player")

-- 2. Kills are counted per weapon and sorted by volume.
assert(TelemetryFunnel.snapshot(funnel).stages.FIRST_KILL == false, "no kill yet")
assert(TelemetryFunnel.recordKill(funnel, "AssaultRifle") == 1, "first kill")
assert(TelemetryFunnel.recordKill(funnel, "AssaultRifle") == 2, "second kill")
TelemetryFunnel.recordKill(funnel, "Knife")
TelemetryFunnel.recordKill(funnel, "Shotgun")
snapshot = TelemetryFunnel.snapshot(funnel)
assert(snapshot.kills == 4, "four kills expected")
assert(snapshot.stages.FIRST_KILL == true, "FIRST_KILL must be set")
assert(snapshot.weapons[1].id == "AssaultRifle" and snapshot.weapons[1].kills == 2,
    "The most used weapon must come first")
assert(#snapshot.weapons == 3, "three weapons used")

-- 3. Long weapon identifiers are truncated, never kept unbounded.
local longId = string.rep("w", 40)
TelemetryFunnel.recordKill(funnel, longId)
snapshot = TelemetryFunnel.snapshot(funnel)
local truncated = false
for _, row in ipairs(snapshot.weapons) do
    if row.id == string.rep("w", TelemetryFunnel.MAX_IDENTIFIER) then truncated = true end
    assert(#row.id <= TelemetryFunnel.MAX_IDENTIFIER, "weapon id must be bounded")
end
assert(truncated, "A long weapon id must be truncated, not dropped")

-- 4. More distinct weapons than the bound fall into a single 'other' bucket,
-- and no kill is ever lost from the total.
local wide = TelemetryFunnel.new()
for index = 1, TelemetryFunnel.MAX_TRACKED_WEAPONS + 5 do
    TelemetryFunnel.recordKill(wide, "weapon_" .. index)
end
local wideSnapshot = TelemetryFunnel.snapshot(wide)
assert(wideSnapshot.kills == TelemetryFunnel.MAX_TRACKED_WEAPONS + 5,
    "Every kill must be counted")
local tallied = 0
local overflow = 0
for _, row in ipairs(wideSnapshot.weapons) do
    tallied = tallied + row.kills
    if row.id == TelemetryFunnel.OTHER_WEAPON then overflow = row.kills end
end
assert(tallied == wideSnapshot.kills, "Weapon tallies must sum to the kill count")
assert(overflow == 5, "Five weapons beyond the bound belong to 'other'")

-- 5. Rounds: completed and abandoned both count, durations stay honest.
local rounds = TelemetryFunnel.new()
assert(TelemetryFunnel.recordRound(rounds, 240, true) == 1, "first round")
assert(TelemetryFunnel.snapshot(rounds).stages.ROUND_COMPLETED == true,
    "ROUND_COMPLETED must be set only by a completed round")
TelemetryFunnel.recordRound(rounds, 10, false)
local roundSnapshot = TelemetryFunnel.snapshot(rounds)
assert(roundSnapshot.rounds.completed == 1, "one completed round")
assert(roundSnapshot.rounds.abandoned == 1, "one abandoned round")
assert(roundSnapshot.rounds.longestSeconds == 240, "longest round tracked")
assert(math.abs(roundSnapshot.rounds.averageSeconds - 125) < 1e-9,
    "The average must include abandoned rounds")
assert(math.abs(roundSnapshot.rounds.abandonRate - 0.5) < 1e-9,
    "Abandon rate must be a share of all rounds")
local abandonedOnly = TelemetryFunnel.new()
TelemetryFunnel.recordRound(abandonedOnly, 5, false)
assert(TelemetryFunnel.snapshot(abandonedOnly).stages.ROUND_COMPLETED == false,
    "An abandoned round must not mark ROUND_COMPLETED")

-- 6. Bounded player tracking: the funnel never grows past its bound.
local crowd = TelemetryFunnel.new()
for index = 1, TelemetryFunnel.MAX_TRACKED_PLAYERS + 3 do
    TelemetryFunnel.recordJoin(crowd, 5000 + index)
end
assert(TelemetryFunnel.snapshot(crowd).uniquePlayers == TelemetryFunnel.MAX_TRACKED_PLAYERS,
    "Tracked players must stay bounded")
assert(TelemetryFunnel.snapshot(crowd).stages.JOINED == true,
    "JOINED must still be marked past the bound")

-- 7. Snapshots are detached copies: a dashboard cannot rewrite live counters.
local live = TelemetryFunnel.new()
TelemetryFunnel.recordJoin(live, 7)
TelemetryFunnel.recordKill(live, "Pistol")
local copy = TelemetryFunnel.snapshot(live)
copy.kills = 999
copy.weapons[1].kills = 999
copy.stages.JOINED = false
local intact = TelemetryFunnel.snapshot(live)
assert(intact.kills == 1, "Mutating a snapshot must not change the funnel")
assert(intact.weapons[1].kills == 1, "Weapon rows must be copies")
assert(intact.stages.JOINED == true, "Stage flags must be copies")

-- 8. Invalid input fails loudly instead of poisoning the counters.
local killsBefore = TelemetryFunnel.snapshot(funnel).kills
local function rejects(operation, label)
    assert(not pcall(operation), "Funnel accepted an invalid input: " .. label)
end
rejects(function() TelemetryFunnel.recordJoin(funnel, 0) end, "zero userId")
rejects(function() TelemetryFunnel.recordJoin(funnel, 0 / 0) end, "NaN userId")
rejects(function() TelemetryFunnel.recordJoin(funnel, nil) end, "missing userId")
rejects(function() TelemetryFunnel.recordJoin(nil, 1) end, "missing state")
rejects(function() TelemetryFunnel.recordKill(funnel, "") end, "empty weapon")
rejects(function() TelemetryFunnel.recordKill(funnel, nil) end, "missing weapon")
rejects(function() TelemetryFunnel.recordRound(funnel, -1, true) end, "negative duration")
rejects(function() TelemetryFunnel.recordRound(funnel, 0 / 0, true) end, "NaN duration")
rejects(function() TelemetryFunnel.recordRound(funnel,
    TelemetryFunnel.MAX_ROUND_SECONDS + 1, true) end, "absurd duration")
rejects(function() TelemetryFunnel.recordRound(funnel, 10, "yes") end,
    "non-boolean completion")
assert(TelemetryFunnel.snapshot(funnel).kills == killsBefore,
    "Rejected input must not change the counters")

print("IRON YARD funnel telemetry (joins, sessions, kills, rounds, bounds): OK")
