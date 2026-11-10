-- IRON YARD / server-owned first-shot accuracy and automatic burst bloom.
-- Degrees only, no RNG, hit result, client input or world state.
local Policy = {}
Policy.RESET_SECONDS = 0.38
Policy.MAX_BURST = 6
Policy.FIRST_SHOT_DEGREES = 0.17
Policy.STEP_DEGREES = 0.23

local function finite(n)
    return type(n) == "number" and n == n
        and n > -math.huge and n < math.huge
end

-- Returns (coneDegrees, burstCount) for a successfully admitted server shot.
-- Rifle spreads from 0.17 to the configured 1.1 degrees over a sustained
-- burst. Other weapons keep their exact existing dispersion: the shotgun's
-- eight pellets remain wide; the pistol/sniper remain perfectly accurate.
function Policy.next(weaponId, previousAt, previousBurst, now, maxDegrees)
    if not finite(now) or now < 0 or not finite(maxDegrees)
        or maxDegrees < 0 or maxDegrees > 45 then return nil end
    if weaponId ~= "AssaultRifle" or maxDegrees == 0 then
        return maxDegrees, 0
    end

    local continuous = finite(previousAt) and previousAt >= 0
        and previousAt < now and now - previousAt < Policy.RESET_SECONDS
        and finite(previousBurst) and previousBurst >= 1
        and previousBurst % 1 == 0
    local count = continuous and math.min(previousBurst + 1, Policy.MAX_BURST) or 1
    local degrees = math.min(maxDegrees,
        Policy.FIRST_SHOT_DEGREES + (count - 1) * Policy.STEP_DEGREES)
    return degrees, count
end

return Policy
