-- IRON YARD / pure first-person viewmodel visibility transition policy.
local Policy = {}

function Policy.hidden(weaponId, scoped)
    return weaponId == "Sniper" and scoped == true
end

function Policy.needsUpdate(previousHidden, hidden)
    return previousHidden == nil or previousHidden ~= hidden
end

-- The optical overlay hides every sniper MeshPart. Skip transform work
-- until a scheduled casing is ACTUALLY due, instead of rendering dozens of
-- invisible frames during its 0.43s delay. The due frame must update the
-- socket against the final camera pose before ejecting the casing.
-- Pending flash and confirmed reload always force a complete render.
-- A missing/invalid clock or casing timestamp fails closed (no skip).
function Policy.skipHiddenSniper(weaponId, scoped, hidden, reloading,
    pendingFlash, pendingCartridge, now)
    if weaponId ~= "Sniper" or scoped ~= true or hidden ~= true
        or reloading ~= false or pendingFlash ~= nil then
        return false
    end
    if pendingCartridge == nil then return true end
    if type(pendingCartridge) ~= "table"
        or type(pendingCartridge.at) ~= "number"
        or pendingCartridge.at ~= pendingCartridge.at
        or pendingCartridge.at < 0
        or pendingCartridge.at == math.huge
        or type(now) ~= "number" or now ~= now
        or now < 0 or now == math.huge then
        return false
    end
    return now < pendingCartridge.at
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

-- Stable interpolation at 30/60/120 FPS; same fraction of a second gives
-- the same pose even when a mobile frame is delayed. No Tween/task allocation.
function Policy.blendAlpha(dt, rate)
    if type(dt) ~= "number" or dt ~= dt or dt < 0
        or dt == math.huge or dt == -math.huge
        or type(rate) ~= "number" or rate ~= rate or rate < 0
        or rate == math.huge or rate == -math.huge then return 0 end
    return math.clamp(1 - math.exp(-Policy.animationDelta(dt) * rate), 0, 1)
end

return Policy
