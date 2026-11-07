-- Pure, bounded engagement decisions: no Roblox services or client positions.
-- Front/side offsets are converted to server-validated world goals by BotTactics.
local Plan = {}

Plan.GOAL_LIFETIME = 1.65
Plan.TARGET_SHIFT = 14
Plan.MIN_REPLAN_GAP = 0.70
Plan.SHOTS_BEFORE_REPOSITION = 3
Plan.MIN_REPOSITION_SECONDS = 2.8

function Plan.mode(distance)
    if type(distance) ~= "number" or distance ~= distance then return "HOLD" end
    if distance > 52 then return "ADVANCE" end
    if distance < 18 then return "DISENGAGE" end
    return "STRAFE"
end

function Plan.offsets(distance, strafeSign)
    local sign = strafeSign == -1 and -1 or 1
    local mode = Plan.mode(distance)
    if mode == "ADVANCE" then
        local forward = math.clamp(distance - 34, 9, 24)
        return {
            { forward = forward, lateral = sign * 9 },
            { forward = forward, lateral = -sign * 9 },
            { forward = math.max(7, forward * 0.6), lateral = 0 },
        }
    elseif mode == "DISENGAGE" then
        return {
            { forward = -15, lateral = sign * 10 },
            { forward = -14, lateral = -sign * 10 },
            { forward = -11, lateral = 0 },
        }
    elseif mode == "STRAFE" then
        return {
            { forward = 2, lateral = sign * 16 },
            { forward = -2, lateral = -sign * 14 },
            { forward = 7, lateral = sign * 8 },
        }
    end
    return {}
end

function Plan.reuseGoal(now, expiresAt, targetShift, sampledAt)
    if type(now) ~= "number" or now ~= now
        or type(expiresAt) ~= "number" or expiresAt ~= expiresAt
        or type(targetShift) ~= "number" or targetShift ~= targetShift then
        return false
    end
    if now >= expiresAt then return false end
    return targetShift < Plan.TARGET_SHIFT
        or (type(sampledAt) == "number" and now - sampledAt < Plan.MIN_REPLAN_GAP)
end

-- Burst-based lateral repositioning is bounded by both shot count and
-- elapsed time, so it cannot force re-paths every 5Hz AI think tick.
function Plan.shouldReposition(shots, now, lastAt, distance, healthRatio, safeToMove)
    if safeToMove ~= true or type(shots) ~= "number"
        or shots ~= shots or shots < Plan.SHOTS_BEFORE_REPOSITION
        or type(now) ~= "number" or now ~= now
        or type(lastAt) ~= "number" or lastAt ~= lastAt
        or type(distance) ~= "number" or distance ~= distance
        or type(healthRatio) ~= "number" or healthRatio ~= healthRatio then
        return false
    end
    return now - lastAt >= Plan.MIN_REPOSITION_SECONDS
        and distance >= 20 and distance <= 105
        and healthRatio >= 0.42
end

function Plan.aimReady(dotProduct, distance)
    if type(dotProduct) ~= "number" or dotProduct ~= dotProduct then return false end
    if type(distance) ~= "number" or distance ~= distance or distance < 0 then return false end
    -- Longer shots require more deliberate aiming; near fights remain responsive.
    return dotProduct >= (distance > 70 and 0.975 or 0.947)
end

return Plan
