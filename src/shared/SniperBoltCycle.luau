-- IRON YARD / original cinematic 4-stage precision bolt, client-only.
-- Mirrors the exact 0.43s spent-shell release delay; never changes ammunition,
-- hit detection, shot cooldown, remote events or the camera.
-- Return independent scalar lift and pull without any table allocation.
local Cycle = {}

Cycle.UNLOCK_START = 0.17
Cycle.UNLOCK_END = 0.25
Cycle.PULL_END = 0.43
Cycle.RETURN_END = 0.56
Cycle.LOCK_END = 0.66

local function finite(v)
    return type(v) == "number" and v == v
        and v >= 0 and v < math.huge
end

local function smooth(a, b, age)
    local t = math.clamp((age - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
end

function Cycle.sample(shotAge, reloading)
    if reloading == true or not finite(shotAge) then return 0, 0 end
    -- Lift / unlock before the bolt travels rearward; relock only once
    -- the spent case has cleared and the bolt has returned fully forward.
    local lift = smooth(Cycle.UNLOCK_START, Cycle.UNLOCK_END, shotAge)
        * (1 - smooth(Cycle.RETURN_END, Cycle.LOCK_END, shotAge))
    local pull = smooth(Cycle.UNLOCK_END, Cycle.PULL_END, shotAge)
        * (1 - smooth(Cycle.PULL_END, Cycle.RETURN_END, shotAge))
    return lift, pull
end

return Cycle
