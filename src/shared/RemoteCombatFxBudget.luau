-- IRON YARD / bounded client-only emission of distant combat visual groups.
-- Pure Luau: local shot prediction, verified hit confirmations, audio and
-- server damage do not depend on or call this admission policy.
local Vfx = require("./CombatVfxProfile")
local Budget = {}

local function finite(value)
    return type(value) == "number" and value == value
        and value < math.huge and value > -math.huge
end

-- Max remote visual groups per second and short burst capacities.
-- Player and bot channels do NOT compete for the same tokens.
local ECO = {
    PLAYER = { rate = 8, burst = 2 },
    BOT = { rate = 4, burst = 2 },
}
local MOBILE = {
    PLAYER = { rate = 10, burst = 3 },
    BOT = { rate = 7, burst = 3 },
}
local MOBILE_QUALITY = {
    PLAYER = { rate = 12, burst = 4 },
    BOT = { rate = 11, burst = 4 },
}
local DESKTOP = {
    PLAYER = { rate = 14, burst = 5 },
    BOT = { rate = 12, burst = 4 },
}
local DESKTOP_QUALITY = {
    PLAYER = { rate = 20, burst = 6 },
    BOT = { rate = 20, burst = 6 },
}

function Budget.limits(preset, touch, kind)
    local levels = preset == "ECO" and ECO
        or (preset == "QUALITY" and
            (touch and MOBILE_QUALITY or DESKTOP_QUALITY))
        or (touch and MOBILE or DESKTOP)
    return levels[kind]
end

function Budget.new()
    return {}
end

-- Admission is evaluated only for an actual remote tracer message.
-- Reject invalid/out-of-range data BEFORE consuming tokens or creating Parts.
-- A closed-form refill avoids per-frame work and keeps fixed O(1) memory.
function Budget.allow(state, now, preset, touch, distance, kind)
    if type(state) ~= "table" or not finite(now) or now < 0
        or not finite(distance) or distance < 0 then return false end
    local limit = Budget.limits(preset, touch, kind)
    if not limit or not Vfx.budget(preset, touch, distance) then return false end

    local bucket = state[kind]
    if not bucket then
        bucket = { tokens = limit.burst, lastAt = now }
        state[kind] = bucket
    elseif now < bucket.lastAt then
        -- A reversed clock cannot be used to refill or consume a burst.
        return false
    else
        local refill = (now - bucket.lastAt) * limit.rate
        bucket.tokens = math.min(limit.burst, bucket.tokens + refill)
        bucket.lastAt = now
    end
    if bucket.tokens < 1 then return false end
    bucket.tokens -= 1
    return true
end

return Budget
