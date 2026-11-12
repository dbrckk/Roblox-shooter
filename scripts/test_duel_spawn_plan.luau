local P = require("../src/shared/DuelSpawnPlan")
local all = {}
for i = 1, 12 do all[i] = true end
local a, b = P.select(all, 1)
assert(a == 1 and b == 4)
local c, d = P.select(all, 2)
assert(c == b and d == a, "Sides must alternate within each pair")

-- Each pair gets two balanced bouts, then play moves to another sightline.
-- All six pairs must be exercised before the deterministic cycle repeats.
for i, pair in ipairs(P.PAIRS) do
    local odd = 2 * i - 1
    local x, y = P.select(all, odd)
    local u, v = P.select(all, odd + 1)
    assert(x == pair[1] and y == pair[2], "Odd bout must use rotated pair")
    assert(u == pair[2] and v == pair[1], "Even bout must swap sides")
end
for bout = 1, 120 do
    local p, q = P.select(all, bout)
    local r, s = P.select(all, bout + 2 * #P.PAIRS)
    assert(p == r and q == s, "Full cycle must be repeatable")
end

local blocked = table.clone(all)
blocked[1] = false
assert(select(1, P.select(blocked, 1)) == 2,
    "Blocked opening pad must fall forward to the next clear pair")
local x, y = P.select(blocked, 2)
assert(x == 3 and y == 2, "Fallback retains second-bout side reversal")
x, y = P.select(blocked, 3)
assert(x == 2 and y == 3, "Third bout starts at the second pair")

for _, pair in ipairs(P.PAIRS) do
    local first, second = pair[1], pair[2]
    local only = {}
    only[first] = true
    assert(P.select(only, 1) == nil, "Both pads must be physically clear")
    only[second] = true
    local s, t = P.select(only, 1)
    assert(s == first and t == second)
    s, t = P.select(only, 2)
    assert(s == second and t == first)
end
local wrap = {[1] = true, [4] = true}
assert(select(1, P.select(wrap, 11)) == 1,
    "Blocked last pair must wrap back to a safe first pair")
assert(select(1, P.select(wrap, 12)) == 4,
    "Wrap-around fallback must still reverse the two sides")
assert(P.select({}, 1) == nil)
assert(P.select(all, 0) == nil)
assert(P.select(all, 0/0) == nil)
assert(P.select(all, math.huge) == nil)
assert(P.select(all, 1.5) == nil)
assert(P.select("not a map", 1) == nil)

-- Exhaust every physical obstruction mask and every bout in a full cycle.
-- The reference selector is deliberately independent of Plan.select.
local evaluations = 0
for mask = 0, 4095 do
    local flags = {}
    for i = 1, 12 do
        flags[i] = (math.floor(mask / (2^(i-1))) % 2 == 1)
    end
    for bout = 1, 2 * #P.PAIRS do
        local left, right = P.select(flags, bout)
        local expectedFirst, expectedSecond = nil, nil
        local start = math.floor((bout - 1) / 2) % #P.PAIRS + 1
        for offset = 0, #P.PAIRS - 1 do
            local index = (start + offset - 1) % #P.PAIRS + 1
            local pair = P.PAIRS[index]
            if flags[pair[1]] and flags[pair[2]] then
                expectedFirst, expectedSecond = pair[1], pair[2]
                if bout % 2 == 0 then
                    expectedFirst, expectedSecond = expectedSecond, expectedFirst
                end
                break
            end
        end
        assert(left == expectedFirst and right == expectedSecond,
            "Only physically clear rotated pairs are allowed")
        evaluations += 1
    end
end
-- Test the exact two-character generation gate used immediately before
-- SpawnService commits EITHER teleport. Prevent a stale rig from receiving
-- a late duel position while its opponent is already moved.
local lifeA, lifeB = {}, {}
local playerA, playerB = {Character = lifeA}, {Character = lifeB}
assert(P.canCommit(playerA, playerB, lifeA, lifeB, true, true))
assert(not P.canCommit(playerA, playerA, lifeA, lifeB, true, true))
assert(not P.canCommit(playerA, playerB, lifeA, lifeA, true, true))
assert(not P.canCommit(nil, playerB, lifeA, lifeB, true, true))
assert(not P.canCommit(playerA, nil, lifeA, lifeB, true, true))
assert(not P.canCommit(playerA, playerB, nil, lifeB, true, true))
assert(not P.canCommit(playerA, playerB, lifeA, nil, true, true))
assert(not P.canCommit(playerA, playerB, lifeA, lifeB, false, true))
assert(not P.canCommit(playerA, playerB, lifeA, lifeB, true, false))
assert(not P.canCommit(playerA, playerB, lifeA, lifeB, nil, true))
-- A new character immediately invalidates the previously prepared pair;
-- a fresh preparation with BOTH verified generations can still proceed.
for i=1,10000 do
    local previous = playerA.Character
    playerA.Character = {}
    assert(not P.canCommit(playerA, playerB, previous,
        playerB.Character, true, true))
    assert(P.canCommit(playerA, playerB, playerA.Character,
        playerB.Character, true, true))
    if i%3 == 0 then
        local oldB = playerB.Character
        playerB.Character = {}
        assert(not P.canCommit(playerA, playerB, playerA.Character,
            oldB, true, true))
        assert(P.canCommit(playerA, playerB, playerA.Character,
            playerB.Character, true, true))
    end
end
print("IRON YARD opposite duel spawns: "..evaluations.." obstacle masks and alternating sides OK")
