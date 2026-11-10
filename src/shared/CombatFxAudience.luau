-- IRON YARD / conservative server-side recipient admission for shot FX.
-- No influence on hits, ammunition, sound-based AI or scoreboard events.
-- The 256-stud radius exceeds the largest client tracer (220 studs) and
-- all existing weapon-audio hearing distances (max 205 studs), with
-- additional slack for character root vs. first-person camera position.
local Audience = {}
Audience.MAX_DISTANCE = 256
Audience.MAX_DISTANCE_SQUARED = Audience.MAX_DISTANCE * Audience.MAX_DISTANCE
Audience.ROSTER_REFRESH_SECONDS = 0.15

local function finite(n)
    return type(n) == "number" and n == n
        and n > -math.huge and n < math.huge
end

local function validPosition(position)
    return position ~= nil and finite(position.X)
        and finite(position.Y) and finite(position.Z)
end

-- Always keep the shooter, dead/spectating players, respawning players,
-- and listeners with missing position data. Only an unquestionably distant
-- ACTIVE player can be culled. No client sends distance or origin data.
function Audience.wants(origin, listener, isShooter, isActive)
    if isShooter == true or isActive ~= true then return true end
    if not validPosition(origin) or not validPosition(listener) then
        return true
    end
    local dx = origin.X - listener.X
    local dy = origin.Y - listener.Y
    local dz = origin.Z - listener.Z
    return dx * dx + dy * dy + dz * dz <= Audience.MAX_DISTANCE_SQUARED
end

-- A roster snapshot caches only expensive Player/Character/Humanoid/Root
-- lookups, never root positions or health values. Both are read LIVE per
-- accepted shot, so sprinting, boosting and death affect every packet.
function Audience.needsRosterRefresh(now, previous, dirty)
    if dirty == true or not finite(now) or not finite(previous)
        or now < previous then return true end
    return now - previous >= Audience.ROSTER_REFRESH_SECONDS
end

function Audience.deliveryMode(included, total)
    if type(included) ~= "number" or type(total) ~= "number"
        or included % 1 ~= 0 or total % 1 ~= 0
        or total < 0 or included < 0 or included > total then return "NONE" end
    if included == 0 then return "NONE" end
    if included == total then return "ALL" end
    return "SOME"
end

return Audience
