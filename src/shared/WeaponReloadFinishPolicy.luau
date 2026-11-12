-- IRON YARD / cosmetic PBR receiver cycle after authoritative reload.
-- Server-only ammo state; never predicts a refill or changes server combat.
local P = {}
P.DURATION = 0.32
local function finite(n)
    return type(n) == "number" and n == n
        and n > -math.huge and n < math.huge
end
function P.confirmed(weaponId, wasReloading, nowReloading, previousLoaded, loaded, capacity)
    return (weaponId == "Pistol" or weaponId == "AssaultRifle")
        and wasReloading == true and nowReloading == false
        and finite(previousLoaded) and finite(loaded) and finite(capacity)
        and capacity > 0 and capacity % 1 == 0
        and previousLoaded >= 0 and previousLoaded % 1 == 0
        and loaded > previousLoaded and loaded <= capacity and loaded % 1 == 0
end
local function smooth(t)
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end
-- Rack rearward, short hold, return to battery in 320ms.
-- The existing slide/charging-handle Part offsets perform this motion.
function P.sample(weaponId, age, reloading)
    if (weaponId ~= "Pistol" and weaponId ~= "AssaultRifle")
        or reloading == true or not finite(age)
        or age < 0 or age >= P.DURATION then return 0 end
    return smooth((age - 0.025) / 0.125)
        * (1 - smooth((age - 0.155) / 0.155))
end
return P
