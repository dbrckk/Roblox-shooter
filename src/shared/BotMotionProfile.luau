-- IRON YARD / pure math used by server R6 bot combat poses.
-- The caller owns movement truth. This module never advances navigation.
local Motion = {}

-- Pose helpers run for up to four server bots at 8-15Hz. Validate scalar
-- components directly instead of allocating a temporary table per signal.
local function finite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

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
    if not finite(previousX) or not finite(previousZ)
        or not finite(currentX) or not finite(currentZ)
        or not finite(dt) then return 0 end
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
    if not finite(previousX) or not finite(previousZ)
        or not finite(currentX) or not finite(currentZ) then return 0 end
    local before = previousX * previousX + previousZ * previousZ
    local after = currentX * currentX + currentZ * currentZ
    if before < 16 or after < 16 then return 0 end
    local alignment = (previousX * currentX + previousZ * currentZ)
        / math.sqrt(before * after)
    return math.clamp((-alignment - 0.15) / 0.85, 0, 1)
end

-- A confirmed impact produces a punch followed by a smaller opposite
-- rebound. Both fade within half a second, with no hitbox motion.
function Motion.hitImpulse(secondsSinceHit)
    local age = tonumber(secondsSinceHit)
    if not age or age ~= age or age < 0 or age == math.huge then
        return 0, 0
    end
    local impact = math.max(0, 1 - age / 0.22)
    impact *= impact
    local rebound = math.max(0, 1 - math.abs(age - 0.30) / 0.16) * 0.30
    return impact, rebound
end

-- Motion around cover is purely cosmetic. The walking rig is never shrunk
-- or granted smaller hitboxes: a grounded bot approaches in low-ready, then
-- braces once physically near its selected cover destination.
function Motion.coverPose(hasCover, distance, travelledSpeed, defensive, grounded)
    if not hasCover or not defensive or not grounded
        or type(distance) ~= "number" or distance ~= distance or distance < 0
        or distance == math.huge or type(travelledSpeed) ~= "number"
        or travelledSpeed ~= travelledSpeed or travelledSpeed < 0
        or travelledSpeed == math.huge then
        return 0, 0
    end
    local moving = math.clamp((travelledSpeed - 2) / 10, 0, 1)
    local approach = moving * math.clamp((distance - 5) / 16, 0, 1)
    local brace = math.clamp((9 - distance) / 9, 0, 1)
        * math.clamp(1 - travelledSpeed / 5, 0, 1)
    return approach, brace
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

-- Avoid four square roots for each bot proximity refresh. The radius remains
-- EXACTLY 155 studs: this changes no animation LOD threshold.
function Motion.intervalSquared(nearestPlayerDistanceSquared)
    if type(nearestPlayerDistanceSquared) == "number"
        and nearestPlayerDistanceSquared == nearestPlayerDistanceSquared
        and nearestPlayerDistanceSquared >= 0
        and nearestPlayerDistanceSquared <= 155 * 155 then
        return 1 / 15
    end
    return 1 / 8
end

-- Deterministic staggering across four server-authored bot slots. A shared
-- absolute clock prevents update phases from slowly converging after lag.
-- It does not touch the 5Hz tactical loop, damage or navigation cadence.
function Motion.nextPoseAt(now, nearestPlayerDistanceSquared, slot)
    if type(now) ~= "number" or now ~= now
        or now < 0 or now == math.huge then return nil end
    local interval = Motion.intervalSquared(nearestPlayerDistanceSquared)
    local botSlot = type(slot) == "number" and slot >= 1
        and slot <= 4 and slot % 1 == 0 and slot or 1
    local phase = (botSlot - 1) * interval / 4
    -- Floating-point division can round an exact phase boundary just
    -- below an integer; use a tiny tolerance so the next deadline is
    -- strictly after now rather than retriggering on the same frame.
    return (math.floor((now - phase) / interval + 1e-9) + 1)
        * interval + phase
end

return Motion
