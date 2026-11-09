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

return Policy
