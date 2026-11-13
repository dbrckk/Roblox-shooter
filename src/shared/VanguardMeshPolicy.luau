-- IRON YARD / pure validation policy for original PBR rig imports.
-- Model packages are external asset data: names and map references must be
-- validated before any MeshPart is accepted into a server-owned character.
local Policy = {}

Policy.Palettes = { "olive", "sand", "slate", "rust" }
Policy.Pieces = { "torso", "head", "left_arm", "right_arm",
    "left_leg", "right_leg", "rifle" }
Policy.RequiredMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
-- Blender joins five PBR materials per R6 component. Roblox glTF imports
-- can split them into distinct MeshParts; cap total replicated geometry.
Policy.MAX_PRIMITIVES_PER_PIECE = 8

function Policy.primitiveCountValid(count)
    return type(count) == "number" and count % 1 == 0
        and count >= 1 and count <= Policy.MAX_PRIMITIVES_PER_PIECE
end

-- GLB material primitive order is not a reliable silhouette hierarchy.
-- Keep the widest-volume imported surface at long range so a tiny accent,
-- rivet or metallic trim is not the ONLY visible body part on Android.
-- Pass the already-validated MeshParts; this policy is also pure-testable
-- with { Size = {X=..., Y=..., Z=...} } fixtures.
function Policy.dominantIndex(primitives)
    if type(primitives) ~= "table"
        or not Policy.primitiveCountValid(#primitives) then return nil end
    local winningIndex, largestVolume = nil, -1
    for index, primitive in ipairs(primitives) do
        local size = primitive and primitive.Size
        if not size then return nil end
        local x, y, z = size.X, size.Y, size.Z
        if type(x) ~= "number" or type(y) ~= "number"
            or type(z) ~= "number" or x <= 0 or y <= 0 or z <= 0
            or x >= math.huge or y >= math.huge or z >= math.huge
            or x ~= x or y ~= y or z ~= z then return nil end
        local volume = x * y * z
        if volume == math.huge then return nil end
        if volume > largestVolume then
            winningIndex, largestVolume = index, volume
        end
    end
    return winningIndex
end

-- One Core silhouette per R6 piece, independent of glTF material ordering.
-- Legacy Studio/manual packs without a selection still use primitive 1.
-- Invalid declared core indices fail closed instead of multiplying LOD cost.
function Policy.visualTier(piece, primitiveIndex, coreIndex)
    if not Policy.primitiveCountValid(primitiveIndex)
        or not Policy.primitiveCountValid(coreIndex or 1) then return nil end
    local known = false
    for _, name in ipairs(Policy.Pieces) do
        if name == piece then known = true break end
    end
    if not known then return nil end
    return primitiveIndex == (coreIndex or 1) and "Core" or "Detail"
end

function Policy.identifyPiece(name)
    if type(name) ~= "string" then return nil end
    local normalized = string.lower(name):gsub("[^a-z0-9]", "")
    for _, piece in ipairs(Policy.Pieces) do
        local part = piece:gsub("[^a-z0-9]", "")
        local prefixed = "vanguard" .. part
        if normalized == part or normalized == prefixed
            or normalized:match("^" .. prefixed .. "%d+$")
            or normalized:match("^" .. prefixed .. "primitive%d+$") then
            return piece
        end
    end
    return nil
end

function Policy.mapsReady(maps)
    if type(maps) ~= "table" then return false end
    for _, field in ipairs(Policy.RequiredMaps) do
        local value = maps[field]
        if type(value) ~= "string" then return false end
        local normalized = string.lower(value):gsub("%s+", "")
        if normalized == "" or normalized == "rbxassetid://0"
            or normalized == "0" or normalized == "null" then
            return false
        end
    end
    return true
end

-- Cloned MeshParts can carry children such as scripts, remote bindables and
-- sounds. Only one direct SurfaceAppearance may cross the trust boundary.
function Policy.keepChild(className, isDirectChild, isPrimaryAppearance)
    return className == "SurfaceAppearance"
        and isDirectChild == true and isPrimaryAppearance == true
end

return Policy
