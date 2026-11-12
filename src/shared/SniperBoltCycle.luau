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
-- Reload confirmation starts a fresh cosmetic bolt cycle immediately.
-- Reuse the exact four-stage motion, removing its initial post-shot delay.
Cycle.RELOAD_DURATION = Cycle.LOCK_END - Cycle.UNLOCK_START

local function finite(v)
    return type(v) == "number" and v == v
        and v >= 0 and v < math.huge
end

local function smooth(a, b, age)
    local t = math.clamp((age - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
end

function Cycle.sample(shotAge, reloading)
    -- Early-out on idle/mobile scoped frames: avoid four smoothstep calls
    -- every RenderStepped when the precision bolt is at rest.
    if reloading == true or not finite(shotAge)
        or shotAge < Cycle.UNLOCK_START
        or shotAge >= Cycle.LOCK_END then return 0, 0 end
    -- Lift / unlock before the bolt travels rearward; relock only once
    -- the spent case has cleared and the bolt has returned fully forward.
    local lift = smooth(Cycle.UNLOCK_START, Cycle.UNLOCK_END, shotAge)
        * (1 - smooth(Cycle.RETURN_END, Cycle.LOCK_END, shotAge))
    local pull = smooth(Cycle.UNLOCK_END, Cycle.PULL_END, shotAge)
        * (1 - smooth(Cycle.PULL_END, Cycle.RETURN_END, shotAge))
    return lift, pull
end

-- Pure presentation after a *server-confirmed* ammo refill. The caller
-- supplies the age of the confirmed snapshot, never the reload input time.
function Cycle.sampleReload(confirmedAge, reloading)
    if reloading == true or not finite(confirmedAge)
        or confirmedAge >= Cycle.RELOAD_DURATION then return 0, 0 end
    return Cycle.sample(confirmedAge + Cycle.UNLOCK_START, false)
end

-- A newly fired shot takes priority over an unfinished cosmetic reload rack,
-- so the glove and bolt never play two conflicting timelines. No allocation.
function Cycle.present(shotAge, confirmedAge, reloading)
    if reloading == true then return 0, 0 end
    if finite(shotAge) and shotAge < Cycle.LOCK_END then
        return Cycle.sample(shotAge, false)
    end
    return Cycle.sampleReload(confirmedAge, false)
end

return Cycle
