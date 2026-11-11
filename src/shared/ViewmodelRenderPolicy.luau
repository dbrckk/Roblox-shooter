-- IRON YARD / pure first-person viewmodel visibility transition policy.
local Policy = {}

function Policy.hidden(weaponId, scoped)
    return weaponId == "Sniper" and scoped == true
end

function Policy.needsUpdate(previousHidden, hidden)
    return previousHidden == nil or previousHidden ~= hidden
end

function Policy.transparency(base, hidden)
    return hidden and 1 or base
end

-- Only clamp cosmetic interpolation, never physics or absolute time-based FX.
-- A 200 ms Android hitch should not advance one walking-bob step at once.
function Policy.animationDelta(dt)
    if type(dt) ~= "number" or dt ~= dt
        or dt == math.huge or dt == -math.huge then
        return 0
    end
    return math.clamp(dt, 0, 0.05)
end

return Policy
