-- IRON YARD / phase-staggered per-bot 5Hz tactical decision clock.
-- This module never modifies combat outcomes or server authority.
local Cadence = {}
Cadence.SLOTS = 4
Cadence.MIN_GAP_FRACTION = 0.75

local function finite(n)
    return type(n) == "number" and n == n
        and n >= 0 and n < math.huge
end

function Cadence.firstAt(now, interval, slot)
    if not finite(now) or not finite(interval) or interval <= 0
        or type(slot) ~= "number" or slot % 1 ~= 0
        or slot < 1 or slot > Cadence.SLOTS then return nil end
    return now + (slot - 1) * interval / Cadence.SLOTS
end

function Cadence.nextAt(now, interval, slot)
    if not finite(now) or not finite(interval) or interval <= 0
        or type(slot) ~= "number" or slot % 1 ~= 0
        or slot < 1 or slot > Cadence.SLOTS then return nil end
    local phase = (slot - 1) * interval / Cadence.SLOTS
    -- The minimum gap avoids extra decisions when a delayed frame lands
    -- immediately before the next absolute phase boundary.
    local floorTime = now + interval * Cadence.MIN_GAP_FRACTION
    return (math.floor((floorTime - phase) / interval + 1e-9) + 1)
        * interval + phase
end

return Cadence
