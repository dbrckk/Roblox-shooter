-- IRON YARD / reusable client-only bot defeat dust.
-- Pure pool policy: no Roblox Instances, collision, server state or timers.
local Plan = require("./BotDeathPlan")
local Pool = {}
Pool.MAX_BOTS = 4
Pool.MAX_PARTS = 16

local function finite(n)
    return type(n) == "number" and n == n
        and n > -math.huge and n < math.huge
end

-- Budget four simultaneous defeats, based on the same per-bot LOD
-- fragments as the existing public art policy. Never exceed 16 Parts.
function Pool.cap(preset, touch)
    return math.min(Pool.MAX_PARTS,
        Plan.dustFragments(preset, touch) * Pool.MAX_BOTS)
end

-- Recycle only expired particles, never cut off still-visible dust.
-- If all slots are active, the next cosmetic fragment is skipped.
function Pool.claim(slots, now, duration, cap)
    if type(slots) ~= "table" or not finite(now) or now < 0
        or not finite(duration) or duration <= 0 or duration > 1
        or not finite(cap) or cap % 1 ~= 0
        or cap < 1 or cap > Pool.MAX_PARTS
        or (slots.lastAt and now < slots.lastAt) then return nil end

    local index = nil
    for i = 1, math.min(#slots, cap) do
        if slots[i].expiresAt <= now then
            index = i
            break
        end
    end
    if not index and #slots < cap then
        index = #slots + 1
        slots[index] = {}
    end
    if not index then return nil end

    local slot = slots[index]
    slot.startedAt = now
    slot.expiresAt = now + duration
    slots.lastAt = now
    return slot, index
end

-- Roblox TweenInfo Quad.Out: result is 0 at spawn and 1 at expiry.
-- This is read only for live particles at a capped animation cadence.
function Pool.ease(slot, now, visible)
    if type(slot) ~= "table" or visible ~= true
        or not finite(now) or not finite(slot.startedAt)
        or not finite(slot.expiresAt) or now < slot.startedAt
        or now >= slot.expiresAt then return nil end
    local duration = slot.expiresAt - slot.startedAt
    if duration <= 0 then return nil end
    local t = math.clamp((now - slot.startedAt) / duration, 0, 1)
    return 1 - (1 - t) * (1 - t)
end

return Pool
