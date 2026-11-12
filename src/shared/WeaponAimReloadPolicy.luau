-- IRON YARD / first-person ADS vs server-authoritative reload.
-- Never cancel ADS from speculative ReloadWeapon input: requests can be
-- rejected (full magazine, cooldown, wrong equipped gun).
local P = {}
function P.canEnterAim(ammo)
    -- Unknown ammo does not prove a reload is active.
    return type(ammo) ~= "table" or ammo.reloading ~= true
end
function P.releaseOnConfirmedReload(equippedWeapon, updatedWeapon, reloading, scoped)
    return type(equippedWeapon) == "string" and equippedWeapon ~= ""
        and equippedWeapon == updatedWeapon
        and reloading == true and scoped == true
end
return P
