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

local padUse = {}
assert(#P.PADS == 12)
for _, pair in ipairs(P.PAIRS) do
    local left, right = P.PADS[pair[1]], P.PADS[pair[2]]
    for _, index in ipairs(pair) do
        assert(not padUse[index] and #P.padLabel(index) <= 26)
        padUse[index] = true
    end
    local dx, dz = right.x - left.x, right.z - left.z
    assert(dx * dx + dz * dz > 260^2, "Both pads have distinct, opposed viewing origins")
end
assert(P.padLabel(nil) == nil and P.padLabel(0/0) == nil and P.padLabel(13) == nil)

local bay = P.SortingBay
assert(P.nextArena(nil, "") == P.SORTING)
assert(P.nextArena(nil, "0000") == P.YARD)
assert(P.nextArena(nil, "000f") == P.SORTING)
assert(P.nextArena(P.SORTING, "0000") == P.YARD)
assert(P.nextArena(P.YARD, "0000") == P.SORTING)

local clearByIndex = {}
for index, pad in ipairs(bay.pads) do
    assert(math.abs(pad.x) + 2.1 < bay.halfWidth - 1)
    assert(math.abs(pad.z) + 2.1 < bay.halfDepth - 1)
    assert(P.padLabel(index, P.SORTING) == pad.label)
    clearByIndex[index] = true
    for _, shape in ipairs(bay.covers) do
        for _, side in ipairs({ -1, 1 }) do
            assert(math.abs(pad.x - side * shape.x) > shape.w / 2 + 2.1
                or math.abs(pad.z - side * shape.z) > shape.d / 2 + 2.1,
                "Sorting Bay pads must clear the overlap query footprint")
        end
    end
end

for i, pair in ipairs(bay.pairs) do
    local first, second = bay.pads[pair[1]], bay.pads[pair[2]]
    assert(first.x == -second.x and first.z == -second.z, "Spawns mirror through the hall")
    local center = bay.covers[1]
    assert(center.x == 0 and center.z == 0 and center.h > 7,
        "Cover must intercept direct spawn-to-spawn sight lines")
    local left, right = P.select(clearByIndex, i * 2 - 1, P.SORTING)
    assert(left == pair[1] and right == pair[2])
    local nextLeft, nextRight = P.select(clearByIndex, i * 2, P.SORTING)
    assert(nextLeft == right and nextRight == left)
end
for _, cover in ipairs(bay.covers) do
    assert(math.abs(cover.x) + cover.w / 2 <= 36, "Keep the long exterior service lanes open")
end
clearByIndex[1] = false
assert(P.select(clearByIndex, 1, P.SORTING) == 3)
assert(P.select({}, 1, P.SORTING) == nil)
print("IRON YARD Sorting Bay: map rotation, mirrored starts, hidden approaches and clear service lanes")
