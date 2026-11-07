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

-- Turn intensity from the real change in facing, not the target's unseen
-- coordinates. Positive values indicate a rightward turn from world -Z to +X.
-- Angular rate is normalized, so 8Hz distant rigs and 15Hz nearby rigs
-- receive comparable turns without instantaneous upper-body snapping.
function Motion.turnSignal(previousX, previousZ, currentX, currentZ, dt)
    local values = { previousX, previousZ, currentX, currentZ, dt }
    for _, n in ipairs(values) do
        if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then
            return 0
        end
    end
    if dt <= 0 or previousX * previousX + previousZ * previousZ < 0.0001
        or currentX * currentX + currentZ * currentZ < 0.0001 then
        return 0
    end
    local cross = previousX * currentZ - previousZ * currentX
    local dot = previousX * currentX + previousZ * currentZ
    return math.clamp(math.atan2(cross, dot)
        / (math.max(dt, 0.025) * 6), -1, 1)
end

-- Body-velocity reversal is a separate transition from chassis rotation.
-- It is used for a short planted-foot braking pose after an actual dodge.
function Motion.reversalSignal(previousX, previousZ, currentX, currentZ)
    local values = { previousX, previousZ, currentX, currentZ }
    for _, n in ipairs(values) do
        if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then
            return 0
        end
    end
    local before = previousX * previousX + previousZ * previousZ
    local after = currentX * currentX + currentZ * currentZ
    if before < 16 or after < 16 then return 0 end
    local alignment = (previousX * currentX + previousZ * currentZ)
        / math.sqrt(before * after)
    return math.clamp((-alignment - 0.15) / 0.85, 0, 1)
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
