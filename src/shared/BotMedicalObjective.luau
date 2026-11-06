-- Deterministic medical objective selection; all candidate sightings verified server-side.
local Objective = {}
Objective.SEARCH_RADIUS = 65
Objective.HOLD_SECONDS = 2.0
Objective.AVOID_SECONDS = 14
Objective.DANGER_RADIUS = 25
local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

function Objective.choose(candidates, now, previousId, holdUntil, failedId, failedUntil)
    if not finite(now) then return nil end
    local best, bestScore = nil, math.huge
    local previousValid = false
    for _, candidate in ipairs(candidates) do
        local distance = candidate.distance
        local danger = candidate.dangerDistance
        if candidate.id ~= nil and candidate.available == true
            and finite(distance) and distance >= 0
            and distance <= Objective.SEARCH_RADIUS
            and (danger == nil or (finite(danger) and danger >= 0))
            and not (candidate.id == failedId
                and finite(failedUntil) and now < failedUntil)
            and (danger == nil or danger >= Objective.DANGER_RADIUS) then
            local score = distance + (danger and math.max(0, 55 - danger) * 1.1 or 0)
            if score < bestScore then
                best, bestScore = candidate.id, score
            end
            if candidate.id == previousId then previousValid = true end
        end
    end
    if previousValid and finite(holdUntil) and now < holdUntil then
        return previousId
    end
    return best
end
return Objective
