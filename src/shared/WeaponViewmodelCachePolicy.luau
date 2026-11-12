-- IRON YARD / one-slot previous-weapon viewmodel reuse policy.
-- Pure Luau: never owns an Instance, camera, lifecycle loop or gameplay state.
-- Only a REAL weapon switch can cache one already-built cosmetic Model.
local Policy = {}

Policy.TTL = 8
Policy.MAX_PARTS = 80

local function finiteTime(value)
    return type(value) == "number" and value == value
        and value >= 0 and value < math.huge
end

function Policy.shouldStore(previousWeaponId, weaponId, partCount)
    return type(previousWeaponId) == "string" and previousWeaponId ~= ""
        and type(weaponId) == "string" and weaponId ~= ""
        and previousWeaponId ~= weaponId
        and type(partCount) == "number" and partCount == partCount
        and partCount >= 1 and partCount <= Policy.MAX_PARTS
end

-- Invalidate malformed/future timestamps and expired models rather than
-- keeping large PBR meshes after a suspend/resume or a clock discontinuity.
function Policy.expired(entry, now)
    return type(entry) ~= "table" or not finiteTime(entry.stashedAt)
        or not finiteTime(now) or now < entry.stashedAt
        or now - entry.stashedAt > Policy.TTL
end

function Policy.canReuse(entry, weaponId, wantedLod, now)
    if Policy.expired(entry, now) or entry.model == nil
        or type(entry.parts) ~= "table"
        or #entry.parts < 1 or #entry.parts > Policy.MAX_PARTS
        or entry.weaponId ~= weaponId
        or (wantedLod ~= "LOD0" and wantedLod ~= "LOD1") then
        return false
    end
    if entry.imported == true then
        -- A user changing ECO/QUALITY must never reuse a stale imported LOD.
        return entry.lod == wantedLod
    end
    -- Procedural fallback is source-independent: existing idle PBR upgrades
    -- still run when a newly approved replicated mesh arrives.
    return entry.imported == false and entry.lod == nil
end

return Policy
