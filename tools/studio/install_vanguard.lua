-- IRON YARD / Studio Command Bar importer.
-- Run in Studio Edit mode AFTER importing the four VANGUARD_*_LOD0.glb files.
-- Select exactly four imported root models, named olive, sand, slate, rust.
-- Source meshes remain untouched; a complete, validated ServerStorage kit is staged.
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local palettes = {"olive", "sand", "slate", "rust"}
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
        if n == key or n == "vanguard" .. key then
            return part
        end
    end
    return nil
end

local function completeMaps(appearance)
    if not appearance then return false end
    for _, field in ipairs({ "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }) do
        local id = appearance[field]
        if typeof(id) ~= "string" or id == "" or id == "rbxassetid://0" then
            return false
        end
    end
    return true
end

local function safeClone(mesh)
    local clone = mesh:Clone()
    local primary = clone:FindFirstChildOfClass("SurfaceAppearance")
    for _, item in ipairs(clone:GetDescendants()) do
        -- Keep one direct PBR surface only; no scripts or arbitrary objects
        -- can be attached to server-owned runtime characters.
        if item ~= primary or item.Parent ~= clone then
            item:Destroy()
        end
    end
    clone.Anchored = false
    clone.CanCollide = false
    clone.CanQuery = false
    clone.CanTouch = false
    clone.Massless = true
    return clone
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
                assert(completeMaps(item:FindFirstChildOfClass("SurfaceAppearance")),
                    "Import all four PBR maps (Color, Normal, Roughness, Metalness): "
                        .. root.Name .. "/" .. id)
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
local count = 0
for _, color in ipairs(palettes) do
    local paletteFolder = Instance.new("Folder")
    paletteFolder.Name = color
    paletteFolder.Parent = staging
    for _, name in ipairs(pieces) do
        local clone = safeClone(imports[color][name])
        clone.Name = name
        clone.Parent = paletteFolder
        count += 1
    end
end

assert(count == 28, "Expected 28 uniquely named MeshParts")
staging.Parent = ServerStorage
local previous = ServerStorage:FindFirstChild("VanguardTemplates")
if previous then previous:Destroy() end
staging.Name = "VanguardTemplates"
print("[IRON YARD] Installed " .. count .. " original MeshParts in ServerStorage/VanguardTemplates.")
print("[IRON YARD] All four bot palettes now have seven complete rigid components.")
print("[IRON YARD] Validated all four PBR maps on each imported piece.")
print("[IRON YARD] Existing kit was replaced only after full validation; scripts were stripped.")
