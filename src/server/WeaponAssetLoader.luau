-- IRON YARD / non-blocking, owner-verified PBR weapon template activation.
-- Uploaded GLB Model packages may contain arbitrary Instances. We only ever
-- replicate expected, validated, sanitized MeshParts and their four maps.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("WeaponAssetIds"))
local Policy = require(Shared:WaitForChild("WeaponAssetPolicy"))
local MeshPolicy = require(Shared:WaitForChild("WeaponMeshPolicy"))
local Layout = require(Shared:WaitForChild("WeaponMeshLayout"))

local Loader = {}
local started = false
local ROOT_NAME = "IronYardWeaponTemplates"

local function validMesh(mesh)
    if not mesh or not mesh:IsA("MeshPart") or mesh.MeshId == "" then
        return false
    end
    local size = mesh.Size.Magnitude
    if size ~= size or size < 0.03 or size > 10 then return false end
    local appearance = mesh:FindFirstChildOfClass("SurfaceAppearance")
    return appearance ~= nil and MeshPolicy.mapsReady({
        ColorMap = appearance.ColorMap,
        NormalMap = appearance.NormalMap,
        RoughnessMap = appearance.RoughnessMap,
        MetalnessMap = appearance.MetalnessMap,
    })
end

local function templateIsComplete(model, weaponId)
    if not model or not model:IsA("Model")
        or model:GetAttribute("IronYardStudioApproved") ~= true then
        return false
    end
    local pivot = model:FindFirstChild("WeaponOrigin")
    if not pivot or not pivot:IsA("BasePart") then return false end
    return Layout.collect(model, MeshPolicy.Required[weaponId], validMesh) ~= nil
end

local function cleanClone(mesh)
    local clone = mesh:Clone()
    local appearance = clone:FindFirstChildOfClass("SurfaceAppearance")
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant ~= appearance or descendant.Parent ~= clone then
            descendant:Destroy()
        end
    end
    clone.Anchored = true
    clone.CanCollide = false
    clone.CanTouch = false
    clone.CanQuery = false
    clone.CastShadow = false
    return clone
end

local function importVariant(assetId, weaponId, lod)
    -- Roblox's modern Model loader enforces owner/experience permissions.
    local package = AssetService:LoadAssetAsync(assetId)
    assert(package and package:IsA("Model"), "Asset is not a Roblox Model")
    local success, result = pcall(function()
        -- Roblox glTF imports contain a nested Model for each authored
        -- mesh, with one MeshPart PER material primitive. This is expected
        -- for the four-material original GLBs, not a duplicate weapon.
        local selected = Layout.collect(package,
            MeshPolicy.Required[weaponId], validMesh)
        assert(selected, "Missing, invalid or duplicated PBR mesh primitives")
        local template = Instance.new("Model")
        template.Name = lod
        local origin = Instance.new("Part")
        origin.Name = "WeaponOrigin"
        origin.Size = Vector3.new(0.04, 0.04, 0.04)
        origin.Transparency = 1
        origin.Anchored = true
        origin.CanCollide = false
        origin.CanQuery = false
        origin.CanTouch = false
        origin.CFrame = package:GetPivot()
        origin.Parent = template
        template.PrimaryPart = origin
        for _, name in ipairs(MeshPolicy.Required[weaponId]) do
            local component = Instance.new("Model")
            component.Name = name
            for index, part in ipairs(selected[name]) do
                local clone = cleanClone(part)
                clone.Name = name .. "_Primitive" .. index
                clone.Parent = component
            end
            component.Parent = template
        end
        template:SetAttribute("IronYardStudioApproved", true)
        assert(templateIsComplete(template, weaponId))
        return template
    end)
    package:Destroy()
    if not success then error(result, 0) end
    return result
end

local function loadPair(weaponId, ids)
    local staging = Instance.new("Folder")
    staging.Name = weaponId
    local success, result = pcall(function()
        for _, lod in ipairs(Policy.LODs) do
            local template = importVariant(ids[lod], weaponId, lod)
            template.Parent = staging
        end
    end)
    if not success or not templateIsComplete(staging:FindFirstChild("LOD0"), weaponId)
        or not templateIsComplete(staging:FindFirstChild("LOD1"), weaponId) then
        staging:Destroy()
        warn("[IRON YARD] Weapon mesh not activated: " .. weaponId
            .. " (" .. tostring(result) .. ")")
        return nil
    end
    return staging
end

local function completeCount(root)
    if not root or not root:IsA("Folder") then return 0 end
    local count = 0
    for _, weaponId in ipairs(Policy.Weapons) do
        local folder = root:FindFirstChild(weaponId)
        if folder and templateIsComplete(folder:FindFirstChild("LOD0"), weaponId)
            and templateIsComplete(folder:FindFirstChild("LOD1"), weaponId) then
            count += 1
        end
    end
    return count
end

local function loadConfigured()
    local activated = 0
    for _, weaponId in ipairs(Policy.Weapons) do
        -- Never re-download a manually installed asset pair. Besides
        -- preserving the owner's kit, this avoids ten wasted asset calls
        -- on populated Studio servers.
        local current = ReplicatedStorage:FindFirstChild(ROOT_NAME)
        if current and current:IsA("Folder")
            and current:FindFirstChild(weaponId) then
            continue
        end
        local ids = Policy.pair(Registry, weaponId)
        if ids then
            local folder = loadPair(weaponId, ids)
            if folder then
                -- The Studio importer can install a manual kit at any time.
                local root = ReplicatedStorage:FindFirstChild(ROOT_NAME)
                if root and not root:IsA("Folder") then
                    folder:Destroy()
                else
                    if not root then
                        root = Instance.new("Folder")
                        root.Name = ROOT_NAME
                        root.Parent = ReplicatedStorage
                    end
                    if root:FindFirstChild(weaponId) then
                        folder:Destroy() -- never overwrite owner-approved templates
                    else
                        folder.Parent = root
                        activated += 1
                        Workspace:SetAttribute("IronYardWeaponMeshStatus",
                            completeCount(root) == #Policy.Weapons and "READY"
                                or "PARTIAL")
                    end
                end
            end
        end
    end
    if activated == 0 then
        local manual = ReplicatedStorage:FindFirstChild(ROOT_NAME)
        Workspace:SetAttribute("IronYardWeaponMeshStatus",
            manual and "MANUAL" or "FALLBACK")
    end
end

function Loader.start()
    if started then return end
    started = true
    Workspace:SetAttribute("IronYardWeaponMeshStatus", "DISABLED")
    if not Policy.sameOwner(Registry,
        game.CreatorType == Enum.CreatorType.User and "User" or "Other",
        game.CreatorId) then return end
    local anyConfigured = false
    for _, weaponId in ipairs(Policy.Weapons) do
        if Policy.pair(Registry, weaponId) then anyConfigured = true break end
    end
    if not anyConfigured then return end
    Workspace:SetAttribute("IronYardWeaponMeshStatus", "LOADING")
    -- Never delay spawning, combat or matchmaking for a Roblox network call.
    task.spawn(loadConfigured)
end

return Loader
