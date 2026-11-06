-- IRON YARD / deterministic local obstacle detour candidate ordering.
-- Pure Luau; the server validates collision, ground and height separately.
local Planner = {}

-- Backward steps escape corners; lateral sweeps go around freight cover.
local STEPS = {
    { forward = -2, lateral = 11 },
    { forward = 5, lateral = 16 },
    { forward = -12, lateral = 7 },
}

function Planner.offsets(strafeSign, attempt)
    local side = strafeSign == -1 and -1 or 1
    local count = math.max(0, math.floor(tonumber(attempt) or 0))
    if count % 2 == 1 then side = -side end
    local candidates = {}
    for _, step in ipairs(STEPS) do
        table.insert(candidates, { forward = step.forward, lateral = step.lateral * side })
        table.insert(candidates, { forward = step.forward, lateral = -step.lateral * side })
    end
    return candidates
end

function Planner.retryDelay(failures)
    local count = math.max(0, math.floor(tonumber(failures) or 0))
    return math.min(4.2, 0.9 + count * 0.55)
end

-- A newly obstructed waypoint only invalidates the route when the
-- obstruction is ahead of (or is) the current waypoint.
function Planner.blockedAhead(blockedIndex, currentIndex)
    return type(blockedIndex) == "number" and blockedIndex % 1 == 0
        and blockedIndex >= 1 and type(currentIndex) == "number"
        and currentIndex % 1 == 0 and currentIndex >= 1
        and blockedIndex >= currentIndex
end

function Planner.targetChanged(waypointGoalDistance, threshold)
    return type(waypointGoalDistance) == "number"
        and waypointGoalDistance == waypointGoalDistance
        and waypointGoalDistance > threshold
end

-- Reuse a traversable path for its intended goal rather than launching
-- ComputeAsync on every AI think tick. A finite TTL prevents stale routes.
function Planner.reusePath(hasWaypoints, distanceToOriginalGoal, age, threshold, maxAge)
    return hasWaypoints == true
        and type(age) == "number" and age >= 0 and age < maxAge
        and type(distanceToOriginalGoal) == "number"
        and distanceToOriginalGoal <= threshold
end

return Planner
