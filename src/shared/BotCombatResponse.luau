-- IRON YARD / bounded, server-authoritative incoming-fire responses.
-- Pure Luau for replayable rules without Roblox services.
local Response = {}

function Response.reaction(side, front, now, healthRatio)
    local x = math.clamp(tonumber(side) or 0, -1, 1)
    local z = math.clamp(tonumber(front) or 0, -1, 1)
    local health = math.clamp(tonumber(healthRatio) or 1, 0, 1)
    local duration = health <= 0.40 and 3.2 or 2.3
    return {
        hitSide = x,
        hitFront = z,
        suppressedUntil = now + duration,
    }
end

function Response.shouldTakeCover(healthRatio, secondsSinceHit, reloading, suppressed)
    local health = math.clamp(tonumber(healthRatio) or 1, 0, 1)
    local age = tonumber(secondsSinceHit) or math.huge
    return reloading == true or suppressed == true
        or (age >= 0 and age < 4.5 and health < 0.68)
end

return Response
