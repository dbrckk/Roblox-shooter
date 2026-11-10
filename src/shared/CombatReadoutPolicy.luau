-- IRON YARD / pure readout snapshots for combat HUD.
-- Display updates are event-driven and cannot change authoritative ammo,
-- damage, health or mobility. Unchanged network snapshots create no UI writes.
local Policy = {}

function Policy.ammo(loaded, capacity, reloading)
    if capacity == nil or capacity <= 0 then
        return "UNLIMITED", "UNLIMITED"
    end
    if reloading == true then
        return "RELOADING...", "RELOADING"
    end
    if loaded == nil then
        return string.format("-- / %d", capacity), "UNKNOWN"
    end
    local remaining = math.clamp(math.floor(loaded), 0, capacity)
    return string.format("%02d / %02d", remaining, capacity),
        remaining <= 3 and "LOW" or "READY"
end

function Policy.health(health, maxHealth)
    health = type(health) == "number" and health or 0
    maxHealth = type(maxHealth) == "number" and maxHealth or 100
    local ratio = maxHealth > 0 and math.clamp(health / maxHealth, 0, 1) or 0
    local tone = "HEALTHY"
    if ratio <= 0.3 then tone = "CRITICAL"
    elseif ratio <= 0.6 then tone = "WARNING" end
    return ratio, tone,
        string.format("%d / %d", math.max(0, math.ceil(health)),
            math.ceil(maxHealth))
end

return Policy
