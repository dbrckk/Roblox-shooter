-- IRON YARD / cosmetic FX frame admission after final viewmodel pose.
-- No network, physics, camera mutation, task, Instance or per-frame allocation.
local Policy = {}

Policy.FLASH_MAX_AGE = 0.17
Policy.CASING_MAX_LATENESS = 0.18

local function stamp(value)
    return type(value) == "number" and value == value
        and value >= 0 and value < math.huge
end

function Policy.flashReady(weaponId, shotAt, now)
    return type(weaponId) == "string" and weaponId ~= "Knife"
        and stamp(shotAt) and stamp(now) and now >= shotAt
        and now - shotAt <= Policy.FLASH_MAX_AGE
end

-- A casing's emission time can lag its firing time for pump/bolt actions.
-- Do not emit spent hulls after a long mobile hitch or a weapon change.
function Policy.casingReady(weaponId, scheduledWeaponId, dueAt, now)
    return type(weaponId) == "string" and weaponId == scheduledWeaponId
        and stamp(dueAt) and stamp(now) and now >= dueAt
        and now - dueAt <= Policy.CASING_MAX_LATENESS
end

return Policy
