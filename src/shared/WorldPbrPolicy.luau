-- IRON YARD / whitelist and atomic activation policy for world PBR.
-- No untrusted client input is allowed to select texture IDs or materials.
local Policy = {}
Policy.Channels = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
Policy.Materials = {
    { key = "freight_steel", base = "Metal", tile = 7 },
    { key = "warehouse_steel", base = "Metal", tile = 7 },
    { key = "yard_asphalt", base = "Concrete", tile = 11 },
}

function Policy.variantName(key)
    for _, style in ipairs(Policy.Materials) do
        if key == style.key then return "IronYardPbr_" .. key end
    end
    return nil
end

-- Pure client admission: no arbitrary material names, and ECO uses the
-- native base material. nil means the tagged part must not be modified.
function Policy.clientVariant(key, baseName, preset)
    for _, style in ipairs(Policy.Materials) do
        if key == style.key and baseName == style.base then
            if preset == "ECO" then return "" end
            return Policy.variantName(key)
        end
    end
    return nil
end

-- Only names from the signed material whitelist can be cleared on
-- invalidation. Prefix checks could unintentionally reset unrelated parts.
function Policy.isOwnedVariant(name)
    if type(name) ~= "string" then return false end
    for _, style in ipairs(Policy.Materials) do
        if name == Policy.variantName(style.key) then return true end
    end
    return false
end

local function validId(value)
    return type(value) == "number" and value > 0 and value < math.huge
        and value % 1 == 0
end

function Policy.ready(registry, creatorId)
    if type(registry) ~= "table"
        or not validId(creatorId)
        or not validId(registry.ownerUserId)
        or creatorId ~= registry.ownerUserId
        or type(registry.sourceCommit) ~= "string"
        or #registry.sourceCommit ~= 40
        or registry.sourceCommit:find("[^0-9a-f]")
        or type(registry.materials) ~= "table" then return false end
    for _, style in ipairs(Policy.Materials) do
        local maps = registry.materials[style.key]
        if type(maps) ~= "table" then return false end
        for _, channel in ipairs(Policy.Channels) do
            if not validId(maps[channel]) then return false end
        end
    end
    return true
end

return Policy
