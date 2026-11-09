-- IRON YARD / deterministic recycling of cosmetic surface impact marks.
-- No Roblox APIs; tested with the standalone Luau interpreter.
local Pool = {}
Pool.MAX_PARTS = 36
Pool.FADE_SECONDS = 1.1
Pool.INITIAL_ALPHA = 0.24

local function finite(n)
    return type(n) == "number" and n == n and n >= 0 and n < math.huge
end

function Pool.claim(slots, now, seconds, cap)
    if type(slots) ~= "table" or not finite(now)
        or not finite(seconds) or seconds <= Pool.FADE_SECONDS
        or not finite(cap) or cap % 1 ~= 0
        or cap < 1 or cap > Pool.MAX_PARTS then return nil end

    local available
    local oldest
    local oldestUntil = math.huge
    for i = 1, math.min(#slots, cap) do
        local entry = slots[i]
        if entry.expiresAt <= now then
            available = i
            break
        end
        if entry.expiresAt < oldestUntil then
            oldestUntil = entry.expiresAt
            oldest = i
        end
    end

    if not available then
        if #slots < cap then
            available = #slots + 1
            slots[available] = {}
        else
            -- Active cap exhausted: replace the oldest visible mark rather
            -- than generating a new Roblox Part or evicting unrelated VFX.
            available = oldest
        end
    end
    local slot = slots[available]
    slot.startedAt = now
    slot.expiresAt = now + seconds
    return slot
end

function Pool.alpha(slot, now, visible)
    if type(slot) ~= "table" or not visible or not finite(now)
        or not finite(slot.startedAt) or not finite(slot.expiresAt)
        or now < slot.startedAt or now >= slot.expiresAt then return nil end
    local remaining = slot.expiresAt - now
    if remaining >= Pool.FADE_SECONDS then return Pool.INITIAL_ALPHA end
    local t = 1 - remaining / Pool.FADE_SECONDS
    -- Smooth fade to invisible without scheduling a Tween or Debris item.
    local eased = 1 - (1 - t) * (1 - t)
    return Pool.INITIAL_ALPHA + (1 - Pool.INITIAL_ALPHA) * eased
end

return Pool
