-- IRON YARD / pure validation policy for original PBR rig imports.
-- Model packages are external asset data: names and map references must be
-- validated before any MeshPart is accepted into a server-owned character.
local Policy = {}

Policy.Palettes = { "olive", "sand", "slate", "rust" }
Policy.Pieces = { "torso", "head", "left_arm", "right_arm",
    "left_leg", "right_leg", "rifle" }
function Policy.paletteFor(index)
    return Policy.Palettes[(index - 1) % #Policy.Palettes + 1]
end

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
local function volume(primitive)
    local size = primitive and primitive.Size
    if not size then return nil end
    local x, y, z = size.X, size.Y, size.Z
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number"
        or not (x > 0 and y > 0 and z > 0) then return nil end
    local value = x * y * z
    if not (value > 0 and value < math.huge) then return nil end
    return value
end

function Policy.dominantIndex(primitives, excluded)
    if type(primitives) ~= "table"
        or not Policy.primitiveCountValid(#primitives) then return nil end
    local winningIndex, largestVolume = nil, -1
    for index, primitive in ipairs(primitives) do
        local size = volume(primitive)
        if not size then return nil end
        if index ~= excluded and size > largestVolume then
            winningIndex, largestVolume = index, size
        end
    end
    return winningIndex
end

-- An optional second piece fills out armor made of broadly distributed
-- material primitives. Limit it to one per component, and skip tiny trim.
function Policy.silhouetteIndex(primitives, coreIndex)
    if not Policy.primitiveCountValid(coreIndex) or type(primitives) ~= "table" then return nil end
    local coreVolume = volume(primitives[coreIndex])
    if not coreVolume then return nil end
    local candidate = Policy.dominantIndex(primitives, coreIndex)
    if candidate and volume(primitives[candidate]) >= coreVolume * 0.28 then
        return candidate
    end
    return nil
end

-- One Core silhouette per R6 piece, independent of glTF material ordering.
-- Legacy Studio/manual packs without a selection still use primitive 1.
-- Invalid declared core indices fail closed instead of multiplying LOD cost.
function Policy.visualTier(piece, primitiveIndex, coreIndex, silhouetteIndex)
    if not Policy.primitiveCountValid(primitiveIndex)
        or not Policy.primitiveCountValid(coreIndex or 1) then return nil end
    local known = false
    for _, name in ipairs(Policy.Pieces) do
        if name == piece then known = true break end
    end
    if not known then return nil end
    if primitiveIndex == (coreIndex or 1) then return "Core" end
    if primitiveIndex == silhouetteIndex then return "Silhouette" end
    return "Detail"
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
