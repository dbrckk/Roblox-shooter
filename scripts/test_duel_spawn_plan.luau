local P = require("../src/shared/DuelSpawnPlan")
local all = {}
for i = 1, 12 do all[i] = true end
local a,b = P.select(all, 1)
assert(a == 1 and b == 4)
local c,d = P.select(all, 2)
assert(c == b and d == a, "Sides must alternate every bout")
local blocked = table.clone(all)
blocked[1] = false
assert(select(1,P.select(blocked,1)) == 2)
local expected = {2,3}
local x,y = P.select(blocked,2)
assert(x == expected[2] and y == expected[1])
for _, pair in ipairs(P.PAIRS) do
    local first, second = pair[1], pair[2]
    local only = {}
    only[first] = true
    assert(P.select(only,1)==nil, "Both pads must be physically clear")
    only[second] = true
    local s,t = P.select(only,1)
    assert(s==first and t==second)
end
assert(P.select({},1)==nil)
assert(P.select(all,0)==nil)
assert(P.select(all,0/0)==nil)
assert(P.select(all,math.huge)==nil)
assert(P.select(all,1.5)==nil)
assert(P.select("not a map",1)==nil)
local evaluations=0
for mask=0,4095 do
    local flags = {}
    for i=1,12 do
        flags[i] = (math.floor(mask / (2^(i-1))) % 2 == 1)
    end
    for bout=1,8 do
        local left,right = P.select(flags,bout)
        local expectedFirst,expectedSecond=nil,nil
        for _,pair in ipairs(P.PAIRS) do
            if flags[pair[1]] and flags[pair[2]] then
                expectedFirst,expectedSecond=pair[1],pair[2]
                if bout%2==0 then expectedFirst,expectedSecond=expectedSecond,expectedFirst end
                break
            end
        end
        assert(left==expectedFirst and right==expectedSecond,
            "No blocked/occupied pad may be selected")
        evaluations+=1
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
