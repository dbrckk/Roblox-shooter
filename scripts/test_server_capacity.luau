-- IRON YARD / executable server capacity policy (LOT 0b of the RIVALS plan).
-- There is no engine here: these are the pure rules a published place must be
-- configured to respect. Passing this suite does NOT prove that the Roblox
-- place is configured with 12 maximum players; it proves the policy is
-- coherent and that the numbers on record were not changed by accident.
-- BotConfig cannot be required from a standalone Luau run (it builds
-- Vector3 values), so its ceilings are repeated here and tied back to the real
-- file by scripts/check_observability_contract.py.
local ServerCapacity = require("../src/shared/ServerCapacity")

local MAX_COMBATANTS = 6 -- BotConfig.MaxCombatants
local MAX_BOTS = 4 -- BotConfig.MaxBots

-- 1. The decision of record: 10 combatants, 2 spectator slots, 12 in total.
assert(ServerCapacity.MAX_PLAYERS == 12, "Server capacity decision drifted")
assert(ServerCapacity.SPECTATOR_SLOTS == 2, "Spectator slots drifted")
assert(ServerCapacity.COMBATANT_LIMIT == 10, "Combatant limit drifted")
assert(ServerCapacity.COMBATANT_LIMIT + ServerCapacity.SPECTATOR_SLOTS
    == ServerCapacity.MAX_PLAYERS, "Capacity slots must add up")

-- 2. The duel gate needs exactly two ready players, so the roster limit can
-- never be smaller than a duel, and bots must fit inside the roster.
assert(ServerCapacity.COMBATANT_LIMIT >= 2, "A 1v1 must fit in the roster")
assert(MAX_COMBATANTS <= ServerCapacity.COMBATANT_LIMIT,
    "Bots plus humans must fit inside the combatant limit")
assert(MAX_BOTS <= ServerCapacity.COMBATANT_LIMIT,
    "The bot ceiling must fit inside the combatant limit")

-- 3. Classification boundaries, from an empty server to a full one.
local expected = {
    { 0, "COMBATANT" }, { 9, "COMBATANT" },
    { 10, "SPECTATOR" }, { 11, "SPECTATOR" },
    { 12, "FULL" }, { 40, "FULL" },
}
for _, case in ipairs(expected) do
    local where = ServerCapacity.classify(case[1])
    assert(where == case[2], string.format("%d players: expected %s, got %s",
        case[1], case[2], where))
end
assert(ServerCapacity.admits(11) == true, "One free slot must admit")
assert(ServerCapacity.admits(12) == false, "A full server must refuse")

-- 3 bis. Join classification is pure and takes the roster size AFTER the
-- join, because PlayerAdded already counts the newcomer. The service must not
-- do this arithmetic itself: the off-by-one is policy, not plumbing.
local joins = {
    { 1, "COMBATANT" }, { 2, "COMBATANT" }, { 10, "COMBATANT" },
    { 11, "SPECTATOR" }, { 12, "SPECTATOR" },
    { 13, "FULL" }, { 41, "FULL" },
}
for _, case in ipairs(joins) do
    local slot = ServerCapacity.classifyJoin(case[1])
    assert(slot == case[2], string.format("roster of %d: expected %s, got %s",
        case[1], case[2], slot))
end
-- The pure helper must stay exactly equivalent to classifying the population
-- before the join, otherwise the two entry points could drift apart.
for roster = 1, 13 do
    assert(ServerCapacity.classifyJoin(roster) == ServerCapacity.classify(roster - 1),
        "classifyJoin must agree with classify on the population before the join")
end
assert(ServerCapacity.classifyJoin(1) == "COMBATANT",
    "The first player of an empty server is a combatant")

-- 4. Free slots never go negative, even if Roblox overshoots the policy.
assert(ServerCapacity.freeSlots(0) == 12, "Empty server must show 12 slots")
assert(ServerCapacity.freeSlots(11) == 1, "One player missing")
assert(ServerCapacity.freeSlots(12) == 0, "Full server has no slots")
assert(ServerCapacity.freeSlots(40) == 0, "An overshoot cannot open slots")

-- 5. The bot budget mirrors BotService's formula exactly.
local budget = {
    { 0, 4 }, { 2, 4 }, { 3, 3 }, { 5, 1 }, { 6, 0 }, { 9, 0 },
}
for _, case in ipairs(budget) do
    local bots = ServerCapacity.botBudget(case[1], MAX_COMBATANTS, MAX_BOTS)
    assert(bots == case[2], string.format("%d humans: expected %d bots, got %d",
        case[1], case[2], bots))
end
assert(ServerCapacity.botBudget(0, 6, 0) == 0, "A zero bot ceiling spawns none")

-- 6. The place configuration audit names the real gap instead of guessing.
local unset = ServerCapacity.checkPlaceMaxPlayers(nil)
assert(unset.ok == false and unset.reason == "UNSET",
    "An absent Players.MaxPlayers must be reported as UNSET")
local exact = ServerCapacity.checkPlaceMaxPlayers(12)
assert(exact.ok == true and exact.reason == "EXACT", "12 must be EXACT")
local small = ServerCapacity.checkPlaceMaxPlayers(10)
assert(small.ok == false and small.reason == "TOO_SMALL", "10 must be TOO_SMALL")
local big = ServerCapacity.checkPlaceMaxPlayers(16)
assert(big.ok == false and big.reason == "OVERFLOW", "16 must be OVERFLOW")

-- 7. Invalid input fails loudly instead of silently producing a capacity.
local function rejects(operation, label)
    assert(not pcall(operation), "Capacity policy accepted an invalid input: " .. label)
end
rejects(function() ServerCapacity.classify(-1) end, "negative population")
rejects(function() ServerCapacity.classify(1.5) end, "fractional population")
rejects(function() ServerCapacity.classify(0 / 0) end, "NaN population")
rejects(function() ServerCapacity.classify(nil) end, "missing population")
rejects(function() ServerCapacity.classifyJoin(0) end, "empty roster after a join")
rejects(function() ServerCapacity.classifyJoin(-1) end, "negative roster")
rejects(function() ServerCapacity.classifyJoin(1.5) end, "fractional roster")
rejects(function() ServerCapacity.classifyJoin(0 / 0) end, "NaN roster")
rejects(function() ServerCapacity.classifyJoin(nil) end, "missing roster")
rejects(function() ServerCapacity.freeSlots(-2) end, "negative free slots")
rejects(function() ServerCapacity.botBudget(-1, 6, 4) end, "negative humans")
rejects(function() ServerCapacity.botBudget(0, 6, -4) end, "negative bot ceiling")
rejects(function() ServerCapacity.checkPlaceMaxPlayers(0 / 0) end, "NaN maximum")

print("IRON YARD server capacity policy (12 players, 10 combatants, bot budget): OK")
