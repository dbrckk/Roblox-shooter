-- IRON YARD / cadence-aware input polling for held automatic fire.
-- The server still owns each accepted shot. This only schedules client
-- attempts at the same pace as the local prediction gate.
local Policy = {}
Policy.IDLE_POLL_SECONDS = 0.10
Policy.MIN_AUTOMATIC_WAIT_SECONDS = 0.04
-- Local fireWeapon already requires 101.5% of cooldown; a small margin
-- avoids a too-early timer waking and skipping the desired next shot.
Policy.COOLDOWN_MARGIN = 1.035

function Policy.isAutomatic(weapon)
    return type(weapon) == "table" and weapon.automatic == true
        and type(weapon.fireCooldown) == "number"
        and weapon.fireCooldown == weapon.fireCooldown
        and weapon.fireCooldown > 0
        and weapon.fireCooldown < math.huge
end

function Policy.waitSeconds(weapon)
    if not Policy.isAutomatic(weapon) then return Policy.IDLE_POLL_SECONDS end
    return math.max(Policy.MIN_AUTOMATIC_WAIT_SECONDS,
        weapon.fireCooldown * Policy.COOLDOWN_MARGIN)
end

return Policy
