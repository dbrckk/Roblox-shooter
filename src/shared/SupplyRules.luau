-- Deterministic, server-authoritative field medical supply rules.
local Rules = {}
Rules.HEAL_AMOUNT = 40
Rules.COOLDOWN = 24
Rules.SERVER_RANGE = 12
Rules.PROMPT_TAG = "IronYardMedicalPrompt"
Rules.PROMPT_READY_ATTRIBUTE = "IronYardMedicalPromptReady"
local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
function Rules.stationState(mode, phase, now, readyAt)
    if mode == "DUEL" then return "DUEL_CLOSED" end
    if phase ~= "LIVE" or not (finite(now) and finite(readyAt)) then
        return "STANDBY"
    end
    return now >= readyAt and "READY" or "RECHARGING"
end

function Rules.rechargeSeconds(now, readyAt)
    if not (finite(now) and finite(readyAt)) then return 0 end
    return math.clamp(math.ceil(readyAt - now), 0, Rules.COOLDOWN)
end

function Rules.needsHeal(health, maxHealth)
    return finite(health) and finite(maxHealth)
        and maxHealth > 0 and health > 0 and health < maxHealth
end

function Rules.canUse(phase, health, maxHealth, distance, now, readyAt)
    if phase ~= "LIVE" then return false end
    if not (finite(distance) and finite(now) and finite(readyAt)) then return false end
    return Rules.needsHeal(health, maxHealth)
        and distance >= 0 and distance <= Rules.SERVER_RANGE and now >= readyAt
end
function Rules.botNeedsHeal(health, maxHealth)
    return finite(health) and finite(maxHealth) and maxHealth > 0
        and health > 0 and health / maxHealth <= 0.48
end

function Rules.healedHealth(health, maxHealth)
    assert(finite(health) and finite(maxHealth) and maxHealth > 0)
    local result = math.min(maxHealth, math.max(0, health) + Rules.HEAL_AMOUNT)
    return result, result - math.clamp(health, 0, maxHealth)
end
return Rules
