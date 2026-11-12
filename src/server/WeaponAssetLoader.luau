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
local LoadPlan = require(Shared:WaitForChild("WeaponAssetLoadPlan"))

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
    return Layout.collect(model, MeshPolicy.Required[weaponId], validMesh,
        MeshPolicy.Optional[weaponId]) ~= nil
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
            MeshPolicy.Required[weaponId], validMesh,
            MeshPolicy.Optional[weaponId])
        assert(selected, "Missing, invalid or duplicated PBR mesh primitives")
        local marker = Layout.origin(package, function(mesh)
            if not mesh:IsA("MeshPart") or mesh.MeshId == "" then return false end
            local extent = mesh.Size.Magnitude
            return extent == extent and extent >= 0.025 and extent <= 0.35
        end)
        assert(marker, "Missing, duplicated or badly scaled authored weapon origin")
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
        -- Model:GetPivot() is determined by the imported Model wrapper
        -- and bounding box. Only the Blender-authored marker is stable for
        -- grip, barrel, ADS and recoil offsets between LOD0 and LOD1.
        origin.CFrame = marker.CFrame
        origin.Parent = template
        template.PrimaryPart = origin
        for _, name in ipairs(MeshPolicy.components(weaponId)) do
            if selected[name] then
                local component = Instance.new("Model")
                component.Name = name
                for index, part in ipairs(selected[name]) do
                    local clone = cleanClone(part)
                    clone.Name = name .. "_Primitive" .. index
                    clone.Parent = component
                end
                component.Parent = template
            end
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

local function validPair(category, weaponId)
    return category ~= nil
        and templateIsComplete(category:FindFirstChild("LOD0"), weaponId)
        and templateIsComplete(category:FindFirstChild("LOD1"), weaponId)
end

local function reportStatus(root, pending, authorized)
    local ready = completeCount(root)
    Workspace:SetAttribute("IronYardWeaponMeshReadyCount", ready)
    Workspace:SetAttribute("IronYardWeaponMeshPendingCount", pending)
    Workspace:SetAttribute("IronYardWeaponMeshStatus",
        LoadPlan.status(ready, pending, authorized))
end

local function loadConfigured()
    local root = ReplicatedStorage:FindFirstChild(ROOT_NAME)
    if root and not root:IsA("Folder") then
        -- Never overwrite an unexpected replicated object of the same name.
        warn("[IRON YARD] PBR asset root is not a Folder; keeping existing fallback")
        reportStatus(nil, 0, true)
        return
    end
    if not root then
        root = Instance.new("Folder")
        root.Name = ROOT_NAME
        root.Parent = ReplicatedStorage
    end

    local queue = LoadPlan.queue(Policy.Weapons, function(weaponId)
        return Policy.pair(Registry, weaponId)
    end, function(weaponId)
        return validPair(root:FindFirstChild(weaponId), weaponId)
    end)
    local pending = #queue
    reportStatus(root, pending, true)
    if pending == 0 then return end

    -- Two simultaneous owner-authorized Model loads at most. Each worker
    -- downloads LOD0 and LOD1 sequentially and publishes only full pairs.
    -- The queue index is incremented before any yielding Roblox API call.
    local index = 0
    local function worker()
        while true do
            index += 1
            local job = queue[index]
            if not job then return end

            local replacement = loadPair(job.weaponId, job.ids)
            if replacement then
                local liveRoot = ReplicatedStorage:FindFirstChild(ROOT_NAME)
                if liveRoot == root then
                    local existing = root:FindFirstChild(job.weaponId)
                    if validPair(existing, job.weaponId) then
                        -- Studio may have installed a complete kit during
                        -- the download. Never overwrite its approved work.
                        replacement:Destroy()
                    else
                        -- A malformed/incomplete manual kit previously
                        -- prevented valid owner assets from ever activating.
                        -- Keep it until the replacement has been validated,
                        -- then swap without yielding or losing the fallback.
                        replacement.Parent = root
                        if existing then existing:Destroy() end
                    end
                else
                    -- Studio may replace the entire root during a download.
                    replacement:Destroy()
                end
            end
            pending -= 1
            reportStatus(ReplicatedStorage:FindFirstChild(ROOT_NAME), pending, true)
        end
    end
    for _ = 1, LoadPlan.workers(#queue) do
        task.spawn(worker)
    end
end

function Loader.start()
    if started then return end
    started = true
    local current = ReplicatedStorage:FindFirstChild(ROOT_NAME)
    reportStatus(current, 0, false)
    if not Policy.sameOwner(Registry,
        game.CreatorType == Enum.CreatorType.User and "User" or "Other",
        game.CreatorId) then return end

    local anyConfigured = false
    for _, weaponId in ipairs(Policy.Weapons) do
        if Policy.pair(Registry, weaponId) then
            anyConfigured = true
            break
        end
    end
    if not anyConfigured then return end

    -- All asset network calls run asynchronously; never block spawn,
    -- shooting, damage, bot AI, matchmaking or the first-person fallback.
    task.spawn(loadConfigured)
end

return Loader
