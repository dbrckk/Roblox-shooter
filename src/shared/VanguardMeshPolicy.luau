-- IRON YARD / pure validation policy for original PBR rig imports.
-- Model packages are external asset data: names and map references must be
-- validated before any MeshPart is accepted into a server-owned character.
local Policy = {}

Policy.Palettes = { "olive", "sand", "slate", "rust" }
Policy.Pieces = { "torso", "head", "left_arm", "right_arm",
    "left_leg", "right_leg", "rifle" }
Policy.RequiredMaps = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }

function Policy.identifyPiece(name)
    if type(name) ~= "string" then return nil end
    local normalized = string.lower(name):gsub("[^a-z0-9]", "")
    for _, piece in ipairs(Policy.Pieces) do
        local part = piece:gsub("[^a-z0-9]", "")
        if normalized == part or normalized == "vanguard" .. part then
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
