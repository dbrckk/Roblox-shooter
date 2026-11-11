-- IRON YARD / pure fail-closed activation policy for owner-owned weapon GLBs.
-- All client-facing mesh parts are still revalidated when imported.
local Policy = {}
Policy.Weapons = { "Pistol", "Knife", "AssaultRifle", "Shotgun", "Sniper" }
Policy.LODs = { "LOD0", "LOD1" }

local function assetId(id)
    return type(id) == "number" and id == id and id < math.huge
        and id > 0 and id % 1 == 0
end

function Policy.sameOwner(registry, creatorType, creatorId)
    return type(registry) == "table"
        and type(registry.ownerUserId) == "number"
        and registry.ownerUserId == creatorId
        and creatorType == "User"
        and assetId(creatorId)
end

-- No partial pairing: both mesh detail levels must exist for one weapon.
function Policy.pair(registry, weaponId)
    if type(registry) ~= "table" or type(registry.modelIds) ~= "table"
        or type(weaponId) ~= "string" then return nil end
    local known = false
    for _, name in ipairs(Policy.Weapons) do
        if name == weaponId then known = true break end
    end
    if not known then return nil end
    local ids = registry.modelIds[weaponId]
    if type(ids) ~= "table" or not assetId(ids.LOD0)
        or not assetId(ids.LOD1) or ids.LOD0 == ids.LOD1 then
        return nil
    end
    return ids
end

function Policy.isComplete(registry)
    for _, weaponId in ipairs(Policy.Weapons) do
        if not Policy.pair(registry, weaponId) then return false end
    end
    return true
end

return Policy
