-- IRON YARD / pure, fixed-memory, priority-aware client transient FX policy.
-- One pool services tracers, impact chips/dust, pellet glints and muzzle flashes.
-- Actual damage, audio, confirmed hit HUD and the server never call this policy.
local Pool = {}
Pool.MAX_PARTS = 96

local function finite(n)
    return type(n) == "number" and n == n
        and n >= 0 and n < math.huge
end

function Pool.cap(preset, touch)
    if preset == "ECO" then return 24 end
    if touch then return preset == "QUALITY" and 72 or 48 end
    return preset == "QUALITY" and 96 or 80
end

-- Lower-priority sparks can be displaced by muzzle flashes or tracers.
-- Active high-priority slots are never preempted by low-priority debris.
-- At capacity a slot is RECYCLED, never instantiated without bound.
function Pool.claim(slots, now, duration, cap, priority)
    if type(slots) ~= "table" or not finite(now)
        or not finite(duration) or duration <= 0 or duration > 0.5
        or not finite(cap) or cap % 1 ~= 0
        or cap < 1 or cap > Pool.MAX_PARTS
        or not finite(priority) or priority % 1 ~= 0
        or priority < 1 or priority > 4
        or (slots.lastAt and now < slots.lastAt) then return nil end

    local index, oldestIndex
    local oldestTime, lowestPriority = math.huge, math.huge
    local limit = math.min(#slots, cap)
    for i = 1, limit do
        local slot = slots[i]
        if slot.expiresAt <= now then
            index = i
            break
        end
        -- Preserve important confirmation/muzzle FX: evict the lowest
        -- eligible priority FIRST, then the earliest expiry within it.
        -- Otherwise a fresh priority-4 flash could replace another flash
        -- even while an older priority-1 dust part remains.
        if slot.priority <= priority and
            (slot.priority < lowestPriority
                or (slot.priority == lowestPriority and slot.expiresAt < oldestTime)) then
            lowestPriority = slot.priority
            oldestTime = slot.expiresAt
            oldestIndex = i
        end
    end
    if not index then
        if #slots < cap then
            index = #slots + 1
            slots[index] = {}
        else
            index = oldestIndex
        end
    end
    if not index then return nil end

    local slot = slots[index]
    slot.startedAt = now
    slot.expiresAt = now + duration
    slot.priority = priority
    slots.lastAt = now
    -- Return the exact slot index so the renderer never needs a reverse
    -- scan to track a live effect. Existing one-value callers are unchanged.
    return slot, index
end

-- Immutable per-spawn classification for VFX with no world-space movement.
-- Stationary cores/glints still animate Size and Transparency. Their
-- authored Part.CFrame is set at spawn, never redundantly every frame.
-- A reused pooled slot MUST recompute this flag for each new effect.
function Pool.moves(targetProvided, arcHeight, gravityDrop, spinAngle)
    return targetProvided == true
        or type(arcHeight) == "number" and arcHeight > 0
        or type(gravityDrop) == "number" and gravityDrop > 0
        or type(spinAngle) == "number" and spinAngle ~= 0
end

function Pool.progress(slot, now, visible)
    if type(slot) ~= "table" or not visible or not finite(now)
        or not finite(slot.startedAt) or not finite(slot.expiresAt)
        or now < slot.startedAt or now >= slot.expiresAt then return nil end
    local duration = slot.expiresAt - slot.startedAt
    if duration <= 0 then return nil end
    return math.clamp((now - slot.startedAt) / duration, 0, 1)
end

return Pool
