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

return Planner
