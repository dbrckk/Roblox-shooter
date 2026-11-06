-- IRON YARD / pure math used by server R6 bot combat poses.
-- The caller owns movement truth. This module never advances navigation.
local Motion = {}

function Motion.smooth(value, target, dt, response)
    local elapsed = math.clamp(tonumber(dt) or 0, 0, 0.35)
    local rate = math.max(0, tonumber(response) or 0)
    return value + (target - value) * (1 - math.exp(-elapsed * rate))
end

function Motion.weights(localX, localZ, travelledSpeed, maxSpeed, grounded)
    if not grounded then return 0, 0, 0 end
    local x = tonumber(localX) or 0
    local z = tonumber(localZ) or 0
    local actual = math.max(0, tonumber(travelledSpeed) or 0)
    local velocity = math.sqrt(x*x + z*z)
    if velocity < 0.15 or actual < 0.15 then return 0, 0, 0 end
    local movement = math.clamp(math.min(actual, velocity) / math.max(1, maxSpeed or 1), 0, 1)
    return movement, math.clamp(-z / velocity, -1, 1),
        math.clamp(x / velocity, -1, 1)
end

function Motion.gaitPhase(previousPhase, travelledDistance)
    local distance = math.clamp(tonumber(travelledDistance) or 0, 0, 10)
    return ((previousPhase or 0) + distance * 0.80) % (math.pi * 2)
end

-- Cosmetic animation frequency, independent of the 5Hz server decision loop.
-- Only four bots exist; far rigs can run at 8Hz instead of 15Hz.
function Motion.interval(nearestPlayerDistance)
    if type(nearestPlayerDistance) == "number"
        and nearestPlayerDistance <= 155 then
        return 1 / 15
    end
    return 1 / 8
end

return Motion
