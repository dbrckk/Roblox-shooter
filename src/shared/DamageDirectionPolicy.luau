-- Planar screen direction keeps camera pitch and roll out of the bearing.
local Direction = {}
Direction.DURATION = 0.76
local HOLD = 0.18

function Direction.project(dx, dz, forwardX, forwardZ, rightX, rightZ)
    local distanceSquared = dx * dx + dz * dz
    if not (distanceSquared >= 0.25 and distanceSquared < math.huge) then return nil end

    local facingSquared = forwardX * forwardX + forwardZ * forwardZ
    if facingSquared < 1e-6 then
        forwardX, forwardZ = rightZ, -rightX
        facingSquared = forwardX * forwardX + forwardZ * forwardZ
        if facingSquared < 1e-6 then return nil end
    end

    local scale = 1 / math.sqrt(distanceSquared * facingSquared)
    return (-forwardZ * dx + forwardX * dz) * scale,
        -(forwardX * dx + forwardZ * dz) * scale
end

function Direction.transparency(elapsed, reducedMotion)
    if reducedMotion then return 0 end
    return math.clamp((elapsed - HOLD) / (Direction.DURATION - HOLD), 0, 1)
end

return Direction
