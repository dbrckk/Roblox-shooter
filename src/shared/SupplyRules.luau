-- Deterministic, server-authoritative field medical supply rules.
local Rules = {}
Rules.HEAL_AMOUNT = 40
Rules.COOLDOWN = 24
Rules.SERVER_RANGE = 12
Rules.STATIONS_FOLDER = "IronYardMedicalStations"
Rules.NEXT_OPENING_ATTRIBUTE = "IronYardMedicalNextOpeningAt"
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

-- A positive deadline is published only when every station is recharging.
function Rules.nextOpening(stations, now)
    if #stations == 0 or not finite(now) then return 0 end
    local earliest = math.huge
    for _, station in ipairs(stations) do
        local deadline = station.readyAt
        if not finite(deadline) or deadline <= now then return 0 end
        earliest = math.min(earliest, deadline)
    end
    return earliest
end

function Rules.needsHeal(health, maxHealth)
    return finite(health) and finite(maxHealth)
        and maxHealth > 0 and health > 0 and health < maxHealth
end

function Rules.shouldGuide(mode, phase, health, maxHealth)
    return mode == "FFA" and phase == "LIVE"
        and Rules.needsHeal(health, maxHealth) and health / maxHealth <= 0.40
end

function Rules.guideBearing(dx, dz, rightX, rightZ)
    local right = dx * rightX + dz * rightZ
    local forward = dx * rightZ - dz * rightX
    return math.deg(math.atan2(right, forward))
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
function Rules.formatHealAmount(amount)
    if not finite(amount) or amount <= 0 then return nil end
    -- Keep fractional health legible without printing a long floating-point tail.
    if amount < 0.05 then return "+<0.1 HP" end
    local rounded = string.format("%.1f", math.min(amount, Rules.HEAL_AMOUNT))
    local displayed = rounded:gsub("%.0$", "")
    return "+" .. displayed .. " HP"
end

return Rules
