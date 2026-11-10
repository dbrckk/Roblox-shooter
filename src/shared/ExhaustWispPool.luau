-- IRON YARD / local rooftop vapor uses a tiny recyclable Part pool.
-- Pure Luau: no Workspace/Tween/Debris dependencies or gameplay effects.
local Pool = {}
Pool.MAX_PARTS = 12
Pool.DURATION = 1.08

local function finite(n)
    return type(n) == "number" and n == n
        and n > -math.huge and n < math.huge
end

-- Exhaust source count and emission rate already follow EnvironmentProfile.
-- Reserve enough slots for simultaneous wisps plus a small timing margin;
-- never allow an unlimited source or a malformed preset to grow this pool.
function Pool.cap(settings)
    if type(settings) ~= "table" or not finite(settings.exhausts)
        or not finite(settings.exhaustInterval)
        or settings.exhausts <= 0 or settings.exhaustInterval <= 0 then
        return 0
    end
    return math.min(Pool.MAX_PARTS, math.ceil(
        math.min(4, settings.exhausts) *
        (Pool.DURATION / settings.exhaustInterval + 1)))
end

-- Active particles are never preempted to paint background vapor.
-- If the chosen quality is saturated, skip the emission instead.
function Pool.claim(slots, now, cap)
    if type(slots) ~= "table" or not finite(now) or now < 0
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
    slot.expiresAt = now + Pool.DURATION
    slots.lastAt = now
    return slot, index
end

-- Exact normalized Tween Quad.Out curve; called only on active slots.
function Pool.alpha(slot, now, visible)
    if type(slot) ~= "table" or visible ~= true or not finite(now)
        or not finite(slot.startedAt) or not finite(slot.expiresAt)
        or now < slot.startedAt or now >= slot.expiresAt then return nil end
    local duration = slot.expiresAt - slot.startedAt
    if duration <= 0 then return nil end
    local t = math.clamp((now - slot.startedAt) / duration, 0, 1)
    return 1 - (1 - t) * (1 - t)
end

return Pool
