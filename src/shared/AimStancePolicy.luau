-- IRON YARD: pure server-side validated aiming stance.
-- The client requests a stance, not an accuracy or damage value.
local Aim = {}
Aim.SETTLE_SECONDS = 0.14
Aim.MAX_AIM_WALK_SPEED = 23
Aim.RIFLE_CONE_FACTOR = 0.70
Aim.SHOTGUN_CONE_FACTOR = 0.86
local function finite(n)
    return type(n) == "number" and n == n and n < math.huge and n > -math.huge
end
function Aim.ready(aimSince, now, movementAllowed, grounded, planarSpeed)
    return finite(aimSince) and aimSince >= 0
        and finite(now) and now - aimSince >= Aim.SETTLE_SECONDS
        and movementAllowed == true and grounded == true
        and finite(planarSpeed) and planarSpeed >= 0
        and planarSpeed <= Aim.MAX_AIM_WALK_SPEED
end
function Aim.cone(weaponId, baseDegrees, ready)
    if not finite(baseDegrees) or baseDegrees < 0 or baseDegrees > 45 then
        return nil
    end
    if ready ~= true or baseDegrees == 0 then return baseDegrees end
    if weaponId == "AssaultRifle" then
        return baseDegrees * Aim.RIFLE_CONE_FACTOR
    elseif weaponId == "Shotgun" then
        return baseDegrees * Aim.SHOTGUN_CONE_FACTOR
    end
    return baseDegrees
end
return Aim
