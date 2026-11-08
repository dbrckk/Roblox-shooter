-- IRON YARD / deterministic first-match briefing; no persistent data or input locks.
local Guide = {}
function Guide.objective(limit)
    local n = type(limit) == "number" and limit == limit
        and math.floor(limit) or 15
    return string.format("FIRST TO %d ELIMINATIONS", math.clamp(n, 1, 100))
end

function Guide.hint(touch, shots, eliminations)
    if (tonumber(eliminations) or 0) > 0 then return nil end
    if (tonumber(shots) or 0) > 0 then
        return touch and "KEEP MOVING • USE COVER • RELOAD"
            or "USE COVER • RELOAD [R] • CHANGE WEAPON [1-5]"
    end
    return touch and "LEFT STICK MOVE • RIGHT SIDE AIM • FIRE"
        or "WASD MOVE • MOUSE AIM • LEFT CLICK FIRE"
end

function Guide.shouldPrompt(phase, alreadyGuided)
    return phase == "LIVE" and not alreadyGuided
end

return Guide
