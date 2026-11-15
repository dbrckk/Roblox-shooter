-- IRON YARD / optional owner-controlled PBR asset delivery.
-- The game never downloads or executes scripts from uploaded Model packages:
-- it selects seven bounded component groups of validated PBR MeshParts.
-- Without complete uploaded assets, procedural VANGUARD stays playable.
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local AssetIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VanguardAssetIds"))
local Policy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VanguardMeshPolicy"))
local MeshKit = require(script.Parent:WaitForChild("VanguardMeshKit"))

local VanguardAssetLoader = {}
local started = false
local COLORS = Policy.Palettes
local PIECES = Policy.Pieces
-- Roblox InsertService can intermittently reject delivery before the model
-- is returned. Retry only this network boundary, never invalid mesh content.
local MAX_DELIVERY_ATTEMPTS = 3
local function loadOwnedPackage(assetId)
    local lastError = "unknown"
    for attempt = 1, MAX_DELIVERY_ATTEMPTS do
        local ok, loaded = pcall(function()
            return InsertService:LoadAsset(assetId)
        end)
        if ok then return loaded end
        lastError = tostring(loaded)
        if attempt < MAX_DELIVERY_ATTEMPTS then
            task.wait(0.35 * (2 ^ (attempt - 1)))
        end
    end
    error("VANGUARD_DELIVERY_FAILED: " .. lastError, 0)
end

local function reportStatus(root, preferred)
    local ready = 0
    for _, palette in ipairs(COLORS) do
        if Kit.paletteReady(root, palette) then ready += 1 end
    end
    Workspace:SetAttribute("IronYardPbrTemplatesLoaded", ready > 0)
    Workspace:SetAttribute("IronYardVanguardReadyCount", ready)
    Workspace:SetAttribute("IronYardPbrStatus",
        preferred or (ready == #COLORS and "READY" or (ready > 0 and "PARTIAL" or "FALLBACK")))
    return ready
end

local function extractPackage(owner, palette)
    local id = AssetIds.paletteModelIds[palette]
    assert(typeof(id) == "number" and id > 0 and id % 1 == 0,
        "Missing uploaded VANGUARD model asset ID: " .. palette)
    local loaded = loadOwnedPackage(id)
    if not loaded or not loaded:IsA("Model") then
        if loaded then loaded:Destroy() end
        error("Roblox asset is not a Model package", 0)
    end
    -- The loaded container stays outside Workspace. Even a creator-owned
    -- package is untrusted: only validated and sanitized meshes cross over.
    local success, extracted = pcall(function()
        local selected = {}
        for _, item in ipairs(loaded:GetDescendants()) do
            if item:IsA("MeshPart") then
                -- Each glTF node can split into one MeshPart per material.
                -- Some Roblox imports name each primitive generically;
                -- the nearest canonical ancestor then supplies its identity.
                local name = Policy.identifyPiece(item.Name)
                local ancestor = item.Parent
                while not name and ancestor and ancestor ~= loaded do
                    name = Policy.identifyPiece(ancestor.Name)
                    ancestor = ancestor.Parent
                end
                if name then
                    assert(MeshKit.isRenderable(item),
                        "Incomplete PBR maps on imported " .. name)
                    local group = selected[name]
                    if not group then
                        group = {}
                        selected[name] = group
                    end
                    assert(#group < Policy.MAX_PRIMITIVES_PER_PIECE,
                        "Excessive material primitives on " .. name)
                    table.insert(group, item)
                end
            end
        end
        for _, name in ipairs(PIECES) do
            local group = selected[name]
            assert(group and Policy.primitiveCountValid(#group),
                "Missing or oversized imported VANGUARD piece " .. name)
        end
        -- Reject malformed geometry before allocating the template hierarchy.
        local coreIndices = {}
        for _, name in ipairs(PIECES) do
            coreIndices[name] = Policy.dominantIndex(selected[name])
            assert(coreIndices[name], "Invalid VANGUARD primitive geometry " .. name)
        end
        local paletteFolder = Instance.new("Folder")
        paletteFolder.Name = palette
        for _, name in ipairs(PIECES) do
            local component = Instance.new("Folder")
            component.Name = name
            local group = selected[name]
            -- The importer may return accent material before armor shell.
            -- Choose the largest validated surface as the ONE Core LOD,
            -- but preserve the original transform basis and primitive order.
            local coreIndex = coreIndices[name]
            local basis = group[1].CFrame
            for index, item in ipairs(group) do
                local clone = MeshKit.cleanClone(item)
                clone.Name = string.format("Primitive%02d", index)
                clone.CFrame = basis:ToObjectSpace(item.CFrame)
                -- Written on the sanitized server-owned template, not
                -- accepted from an uploaded asset's arbitrary attributes.
                clone:SetAttribute("IronYardCoreVisual", index == coreIndex)
                clone.Parent = component
            end
            component.Parent = paletteFolder
        end
        return paletteFolder
    end)
    loaded:Destroy()
    if not success then error(extracted, 0) end
    extracted.Parent = owner
end

-- Uploading/importing a PBR GLB can take seconds. NEVER block game
-- initialization, spawning or matchmaking on remote asset availability.
local function syncManualStatus()
    local root = ServerStorage:FindFirstChild("VanguardTemplates")
    for _, palette in ipairs(COLORS) do
        local status = Kit.paletteReady(root, palette) and "READY" or "UNCONFIGURED"
        Workspace:SetAttribute("IronYardVanguard_" .. palette, status)
    end
    if root then
        reportStatus(root)
    else
        reportStatus(nil, "DISABLED")
    end
end

local function loadConfiguredPbr()
    local root = ServerStorage:FindFirstChild("VanguardTemplates")
    if not root then
        root = Instance.new("Folder")
        root.Name = "VanguardTemplates"
        root.Parent = ServerStorage
    end
    local failure
    for _, palette in ipairs(COLORS) do
        if Kit.paletteReady(root, palette) then
            Workspace:SetAttribute("IronYardVanguard_" .. palette, "READY")
            continue
        end
        local assetId = AssetIds.paletteModelIds[palette]
        if type(assetId) ~= "number" or not (assetId > 0 and assetId < math.huge)
            or assetId % 1 ~= 0 then
            Workspace:SetAttribute("IronYardVanguard_" .. palette, "UNCONFIGURED")
            continue
        end
        Workspace:SetAttribute("IronYardVanguard_" .. palette, "LOADING")
        local staging = Instance.new("Folder")
        local success, message = pcall(extractPackage, staging, palette)
        if ServerStorage:FindFirstChild("VanguardTemplates") ~= root then
            staging:Destroy()
            syncManualStatus()
            return
        end
        if success and Kit.paletteReady(staging, palette) and not Kit.paletteReady(root, palette) then
            local old = root:FindFirstChild(palette)
            if old then old:Destroy() end
            staging:FindFirstChild(palette).Parent = root
        end
        -- An operator may finish a manual import while the asset call yields.
        if Kit.paletteReady(root, palette) then
            Workspace:SetAttribute("IronYardVanguard_" .. palette, "READY")
            reportStatus(root, "LOADING")
        else
            local code = not success and type(message) == "string"
                and message:find("VANGUARD_DELIVERY_FAILED", 1, true)
                and "DELIVERY_FAILED" or "VALIDATION_FAILED"
            failure = failure or code
            Workspace:SetAttribute("IronYardVanguard_" .. palette, code)
            warn("[IRON YARD] VANGUARD " .. palette .. " could not load: " .. tostring(message))
        end
        staging:Destroy()
    end
    if reportStatus(root) == 0 and failure then
        Workspace:SetAttribute("IronYardPbrStatus", failure)
    end
end

function VanguardAssetLoader.start()
    if started then return end
    started = true
    syncManualStatus()
    if Workspace:GetAttribute("IronYardVanguardReadyCount") == #COLORS then return end
    if typeof(AssetIds) ~= "table" or typeof(AssetIds.paletteModelIds) ~= "table" then
        return
    end
    if game.CreatorType ~= Enum.CreatorType.User or game.CreatorId ~= AssetIds.ownerUserId then
        return
    end
    Workspace:SetAttribute("IronYardPbrStatus", "LOADING")
    task.spawn(loadConfiguredPbr)
end

return VanguardAssetLoader
