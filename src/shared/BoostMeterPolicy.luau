-- IRON YARD / pure scheduling for mobile boost-meter animation.
-- Limits cosmetic HUD Tweens to at most 10/s during gradual fuel changes,
-- while responding immediately to empty/full fuel and warning transitions.
local Policy = {}
Policy.MIN_INTERVAL = 0.1
Policy.MIN_DELTA = 0.005

local function finite(value)
    return type(value) == "number"
        and value == value and value < math.huge and value > -math.huge
end

function Policy.zone(ratio)
    if ratio <= 0.12 then return "CRITICAL" end
    if ratio <= 0.25 then return "WARNING" end
    return "NORMAL"
end

function Policy.shouldDraw(previousRatio, previousAt, currentRatio, now)
    if not finite(currentRatio) or not finite(now) or now < 0 then
        return false, nil, nil
    end
    local ratio = math.clamp(currentRatio, 0, 1)
    local zone = Policy.zone(ratio)
    if previousRatio == nil or previousAt == nil then
        return true, ratio, zone
    end
    if not finite(previousRatio) or not finite(previousAt)
        or now < previousAt then
        return false, ratio, zone
    end
    if ratio == previousRatio then return false, ratio, zone end
    if zone ~= Policy.zone(previousRatio) then
        return true, ratio, zone
    end
    -- React instantly when fuel becomes empty or full.
    if ratio == 0 or ratio == 1 then return true, ratio, zone end
    if now - previousAt < Policy.MIN_INTERVAL
        or math.abs(ratio - previousRatio) < Policy.MIN_DELTA then
        return false, ratio, zone
    end
    return true, ratio, zone
end

return Policy
