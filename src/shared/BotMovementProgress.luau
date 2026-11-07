-- IRON YARD: pure objective-progress monitor for server-owned NPC navigation.
-- Measures progress toward the ACTUAL MoveTo target (waypoint or detour).
-- Lateral movement without closing distance does not clear a real blockage.
local Progress = {}
Progress.GOAL_CHANGE_DISTANCE = 3.5
Progress.REACHED_DISTANCE = 4.5
Progress.MIN_PROGRESS_DISTANCE = 1.15
Progress.STALL_SECONDS = 2.8
Progress.WAIT_GRACE_SECONDS = 4.5

local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function restart(now, distance)
    return { since = now, referenceDistance = distance }
end

-- Returns (nextState, stalled, madeProgress).
-- A pending async PathfindingService call cannot be cancelled by a simplistic
-- 5Hz speed check; BotNavigation enforces its own compute timeout.
function Progress.step(previous, now, distance, goalShift, mode, modeAge, pathing)
    if not finite(now) or not finite(distance) or distance < 0 then
        return nil, false, false
    end
    if distance <= Progress.REACHED_DISTANCE or mode == "IDLE" then
        return restart(now, distance), false, false
    end
    if not previous or not finite(previous.since)
        or not finite(previous.referenceDistance)
        or not finite(goalShift)
        or goalShift > Progress.GOAL_CHANGE_DISTANCE
        or now < previous.since then
        return restart(now, distance), false, false
    end
    if previous.referenceDistance - distance >= Progress.MIN_PROGRESS_DISTANCE then
        return restart(now, distance), false, true
    end
    if pathing == true then
        return previous, false, false
    end
    if mode == "WAIT" and finite(modeAge) and modeAge < Progress.WAIT_GRACE_SECONDS then
        return previous, false, false
    end
    if now - previous.since >= Progress.STALL_SECONDS then
        return restart(now, distance), true, false
    end
    return previous, false, false
end
return Progress
