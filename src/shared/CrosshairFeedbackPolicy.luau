-- IRON YARD / client-only responsive crosshair feedback. No combat authority.
-- Radius is intentionally indicative; it never claims to be the server spread.
local Policy = {}
local BASE = { AssaultRifle = 15, Pistol = 13, Shotgun = 19, Sniper = 12, Knife = 14 }
local IMPULSE = { AssaultRifle = 3.8, Pistol = 4.5, Shotgun = 6.0, Sniper = 6.0, Knife = 3.0 }
local function finite(n)
    return type(n) == "number" and n == n
        and math.abs(n) ~= math.huge
end

function Policy.kick(weaponId, previous)
    if not finite(previous) then previous = 0 end
    return math.min(12, math.max(0, previous) + (IMPULSE[weaponId] or 0))
end

function Policy.recover(previous, dt)
    if not finite(previous) or not finite(dt) then return 0 end
    return math.max(0, previous) * math.exp(-9 * math.clamp(dt, 0, 0.5))
end

function Policy.radius(weaponId, moveAmount, sprinting, kick)
    if not finite(moveAmount) or not finite(kick) then return 15 end
    local base = BASE[weaponId] or 15
    return math.floor(math.clamp(base + math.clamp(moveAmount, 0, 1) * 4
        + (sprinting == true and 5 or 0) + math.max(0, kick),
        10, 33) + 0.5)
end

-- No UI updates when rounded radius is unchanged; no per-shot Tweens.
function Policy.shouldDraw(now, previousAt, previousRadius, radius)
    return finite(now) and finite(radius)
        and previousRadius ~= radius
        and (not finite(previousAt) or now - previousAt >= 0.045)
end

return Policy
