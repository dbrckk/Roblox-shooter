-- Pure bounded retreat plan for NPCs under fire; geometry is validated by BotTactics.
local Plan = {}
Plan.FAILED_LANE_SECONDS = 8
Plan.FAILED_LANE_RADIUS = 9

function Plan.offsets(strafeSign)
    local side = strafeSign == -1 and -1 or 1
    return {
        { back = 19, lateral = side * 12 },
        { back = 19, lateral = -side * 12 },
        { back = 28, lateral = side * 7 },
        { back = 28, lateral = -side * 7 },
        { back = 10, lateral = side * 19 },
        { back = 10, lateral = -side * 19 },
    }
end

function Plan.rejected(distanceFromFailed, now, failedUntil)
    if type(distanceFromFailed) ~= "number"
        or distanceFromFailed ~= distanceFromFailed
        or type(now) ~= "number" or now ~= now
        or type(failedUntil) ~= "number" or failedUntil ~= failedUntil then
        return false
    end
    return now < failedUntil and distanceFromFailed <= Plan.FAILED_LANE_RADIUS
end

function Plan.score(blocksEnemyFire, travelDistance, preferredSide)
    local distance = tonumber(travelDistance)
    if not distance or distance ~= distance or distance < 0 or distance == math.huge then
        return -math.huge
    end
    -- A real line-of-fire blocker dominates small distance differences.
    -- Still permit an exposed evasive lane if every nearby cover is blocked.
    return (blocksEnemyFire == true and 82 or -16)
        - distance * 0.36 + (preferredSide == true and 2 or 0)
end

return Plan
