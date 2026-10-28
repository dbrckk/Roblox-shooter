-- NEON STRIKE / Studio Command Bar importer.
-- Run in Studio Edit mode AFTER importing the four VANGUARD_*_LOD0.glb files.
-- Select exactly four imported root models, named cyan, amber, violet, emerald.
-- Source meshes remain untouched; a complete, validated ServerStorage kit is staged.
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local palettes = {"cyan", "amber", "violet", "emerald"}
local pieces = {"torso", "head", "left_arm", "right_arm", "left_leg", "right_leg", "rifle"}
local selected = Selection:Get()
assert(#selected == 4, "Select the FOUR imported color-model roots before running this command.")

local function normalize(text)
    return string.lower(text):gsub("[^a-z0-9]", "")
end

local function identifyPiece(mesh)
    local n = normalize(mesh.Name)
    for _, part in ipairs(pieces) do
        local key = normalize(part)
        if n == key or n == "vanguard" .. key or n:find("vanguard" .. key, 1, true) then
            return part
        end
    end
    return nil
end

local function findMeshes(root)
    local result = {}
    local candidates = root:GetDescendants()
    table.insert(candidates, root)
    for _, item in ipairs(candidates) do
        if item:IsA("MeshPart") then
            local id = identifyPiece(item)
            if id then
                assert(not result[id], "Duplicate mesh for " .. id .. " inside " .. root.Name)
                assert(item.MeshId ~= "", "Import the real mesh before installing " .. root.Name .. "/" .. id)
                result[id] = item
            end
        end
    end
    for _, id in ipairs(pieces) do
        assert(result[id], "Missing mesh: " .. id .. " inside " .. root.Name)
    end
    return result
end

local imports = {}
for _, root in ipairs(selected) do
    local name = normalize(root.Name)
    local matched = nil
    for _, color in ipairs(palettes) do
        if name:find(color, 1, true) then matched = color break end
    end
    assert(matched, "Rename the selected model to include its palette: " .. root.Name)
    assert(not imports[matched], "Duplicate palette in selected models: " .. matched)
    imports[matched] = findMeshes(root)
end
for _, color in ipairs(palettes) do
    assert(imports[color], "Selected models lack palette " .. color)
end

local staging = Instance.new("Folder")
staging.Name = "_VanguardTemplatesStaging"
local untextured = {}
local count = 0
for _, color in ipairs(palettes) do
    local paletteFolder = Instance.new("Folder")
    paletteFolder.Name = color
    paletteFolder.Parent = staging
    for _, name in ipairs(pieces) do
        local clone = imports[color][name]:Clone()
        clone.Name = name
        clone.Anchored = false
        clone.CanCollide = false
        clone.CanQuery = false
        clone.CanTouch = false
        clone.Massless = true
        clone.Parent = paletteFolder
        if not clone:FindFirstChildOfClass("SurfaceAppearance") then
            table.insert(untextured, color .. "/" .. name)
        end
        count += 1
    end
end

assert(count == 28, "Expected 28 uniquely named MeshParts")
staging.Parent = ServerStorage
local previous = ServerStorage:FindFirstChild("VanguardTemplates")
if previous then previous:Destroy() end
staging.Name = "VanguardTemplates"
print("[NEON STRIKE] Installed " .. count .. " original MeshParts in ServerStorage/VanguardTemplates.")
print("[NEON STRIKE] All four bot palettes now have seven complete rigid components.")
if #untextured > 0 then
    warn("[NEON STRIKE] PBR SurfaceAppearance not found for " .. #untextured ..
        " pieces. Mesh geometry will work, but import and assign PBR maps before publication.")
    for _, name in ipairs(untextured) do
        warn("[NEON STRIKE] Missing SurfaceAppearance: " .. name)
    end
else
    print("[NEON STRIKE] All 28 components have SurfaceAppearance. Check actual map IDs in Studio.")
end
