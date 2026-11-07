-- Pure limited acoustic investigation; gunfire never authorizes target acquisition.
local Search = {}
Search.PHASE_COUNT = 3
Search.MAX_SECONDS = 17
Search.REACHED_RADIUS = 5
Search.PHASE_SECONDS = { 7, 4.5, 4.5 }

local function finite(n)
    return type(n) == "number" and n == n and n < math.huge and n > -math.huge
end

function Search.offsets(phase, strafeSign)
    local sign = strafeSign == -1 and -1 or 1
    if phase == 1 then
        return {
            {forward = 0, lateral = 0},
            {forward = -3, lateral = sign * 12},
            {forward = -3, lateral = -sign * 12},
        }
    elseif phase == 2 then
        return {
            {forward = -3, lateral = sign * 15},
            {forward = -11, lateral = sign * 11},
            {forward = 6, lateral = sign * 12},
        }
    elseif phase == 3 then
        return {
            {forward = -3, lateral = -sign * 15},
            {forward = -11, lateral = -sign * 11},
            {forward = 6, lateral = -sign * 12},
        }
    end
    return {}
end

-- Returns nextPhase, changed, done. Per-step timeouts prevent endlessly
-- attempting inaccessible corners. Arrival proceeds to adjacent sweeps.
function Search.advance(phase, searchStarted, stepStarted, now, goalDistance)
    if not finite(now) or not finite(searchStarted) or not finite(stepStarted)
        or not finite(goalDistance) or goalDistance < 0
        or now < stepStarted or now < searchStarted
        or phase ~= math.floor(tonumber(phase) or 0) or phase < 1
        or phase > Search.PHASE_COUNT then
        return nil, false, true
    end
    if now - searchStarted >= Search.MAX_SECONDS then
        return nil, false, true
    end
    if goalDistance > Search.REACHED_RADIUS
        and now - stepStarted < Search.PHASE_SECONDS[phase] then
        return phase, false, false
    end
    if phase == Search.PHASE_COUNT then return nil, true, true end
    return phase + 1, true, false
end

return Search
