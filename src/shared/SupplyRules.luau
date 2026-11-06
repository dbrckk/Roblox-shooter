-- Deterministic, server-authoritative field medical supply rules.
local Rules = {}
Rules.HEAL_AMOUNT = 40
Rules.COOLDOWN = 24
Rules.SERVER_RANGE = 12
local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
function Rules.canUse(phase, health, maxHealth, distance, now, readyAt)
    if phase ~= "LIVE" then return false end
    if not (finite(health) and finite(maxHealth) and finite(distance)
        and finite(now) and finite(readyAt)) then return false end
    return maxHealth > 0 and health > 0 and health < maxHealth
        and distance >= 0 and distance <= Rules.SERVER_RANGE and now >= readyAt
end
function Rules.healedHealth(health, maxHealth)
    assert(finite(health) and finite(maxHealth) and maxHealth > 0)
    local result = math.min(maxHealth, math.max(0, health) + Rules.HEAL_AMOUNT)
    return result, result - math.clamp(health, 0, maxHealth)
end
return Rules
