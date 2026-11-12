-- IRON YARD / pure, deterministic opposite-pad selection for 1v1 rounds.
-- The server checks physical cover without considering either combatant an obstacle.
local Plan = {}
Plan.PAIRS = {{1,4}, {2,3}, {5,8}, {6,7}, {9,10}, {11,12}}

function Plan.select(clear, bout)
    if type(clear) ~= "table" or type(bout) ~= "number"
        or bout ~= bout or bout == math.huge or bout == -math.huge
        or bout < 1 or bout % 1 ~= 0 then
        return nil
    end
    for _, pair in ipairs(Plan.PAIRS) do
        local first, second = pair[1], pair[2]
        if clear[first] == true and clear[second] == true then
            if bout % 2 == 0 then return second, first end
            return first, second
        end
    end
    return nil
end


-- Validate both ORIGINAL Roblox Player objects and character generations
-- immediately before an opposite-pad commit. A respawned avatar or missing
-- rig invalidates the entire pair, never half-spawns one competitor.
-- Pure Luau: exercised without running Roblox physics in CI.
function Plan.canCommit(aPlayer, bPlayer, expectedA, expectedB, aReady, bReady)
    return aPlayer ~= nil and bPlayer ~= nil and aPlayer ~= bPlayer
        and expectedA ~= nil and expectedB ~= nil and expectedA ~= expectedB
        and aPlayer.Character == expectedA and bPlayer.Character == expectedB
        and aReady == true and bReady == true
end

return Plan
