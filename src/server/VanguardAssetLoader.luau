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

local function hasCompleteTemplateSet(folder)
    for _, palette in ipairs(COLORS) do
        local variant = folder:FindFirstChild(palette)
        if not variant then return false end
        for _, piece in ipairs(PIECES) do
            local mesh = variant:FindFirstChild(piece)
            if not MeshKit.primitives(mesh) then
                return false
            end
        end
    end
    return true
end

local function extractPackage(owner, palette)
    local id = AssetIds.paletteModelIds[palette]
    assert(typeof(id) == "number" and id > 0 and id % 1 == 0,
        "Missing uploaded VANGUARD model asset ID: " .. palette)
    local loaded = loadOwnedPackage(id)
    assert(loaded and loaded:IsA("Model"), "Roblox asset is not a Model package")
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
        local paletteFolder = Instance.new("Folder")
        paletteFolder.Name = palette
        for _, name in ipairs(PIECES) do
            local component = Instance.new("Folder")
            component.Name = name
            local group = selected[name]
            -- The importer may return accent material before armor shell.
            -- Choose the largest validated surface as the ONE Core LOD,
            -- but preserve the original transform basis and primitive order.
            local coreIndex = Policy.dominantIndex(group)
            assert(coreIndex, "Invalid VANGUARD primitive geometry " .. name)
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
local function loadConfiguredPbr()
    local staging = Instance.new("Folder")
    staging.Name = "_VanguardTemplatesStaging"
    local success, message = pcall(function()
        for _, palette in ipairs(COLORS) do
            extractPackage(staging, palette)
        end
    end)
    if not success or not hasCompleteTemplateSet(staging) then
        staging:Destroy()
        local code = not success and type(message) == "string"
            and message:find("VANGUARD_DELIVERY_FAILED", 1, true)
            and "DELIVERY_FAILED" or "VALIDATION_FAILED"
        Workspace:SetAttribute("IronYardPbrStatus", code)
        warn("[IRON YARD] PBR package import incomplete; keeping procedural avatars: "
            .. tostring(message))
        return
    end
    if ServerStorage:FindFirstChild("VanguardTemplates") then
        -- A Studio or plugin import may have appeared during asynchronous load.
        staging:Destroy()
        Workspace:SetAttribute("IronYardPbrStatus", "MANUAL")
        return
    end
    staging.Name = "VanguardTemplates"
    staging.Parent = ServerStorage
    Workspace:SetAttribute("IronYardPbrTemplatesLoaded", true)
    Workspace:SetAttribute("IronYardPbrStatus", "READY")
    print("[IRON YARD] Owner-controlled PBR kit ready; new bots use MeshParts.")
end

function VanguardAssetLoader.start()
    if started then return end
    started = true
    Workspace:SetAttribute("IronYardPbrTemplatesLoaded", false)
    Workspace:SetAttribute("IronYardPbrStatus", "DISABLED")

    local manual = ServerStorage:FindFirstChild("VanguardTemplates")
    if manual then
        local valid = hasCompleteTemplateSet(manual)
        Workspace:SetAttribute("IronYardPbrTemplatesLoaded", valid)
        Workspace:SetAttribute("IronYardPbrStatus", valid and "MANUAL" or "FALLBACK")
        return
    end
    if typeof(AssetIds) ~= "table" or typeof(AssetIds.paletteModelIds) ~= "table" then
        warn("[IRON YARD] Missing asset registry; using procedural visuals")
        return
    end
    if game.CreatorType ~= Enum.CreatorType.User or game.CreatorId ~= AssetIds.ownerUserId then
        return -- No cross-creator insertion.
    end
    for _, palette in ipairs(COLORS) do
        local id = AssetIds.paletteModelIds[palette]
        if typeof(id) ~= "number" or id <= 0 or id % 1 ~= 0 then
            return
        end
    end

    Workspace:SetAttribute("IronYardPbrStatus", "LOADING")
    task.spawn(loadConfiguredPbr)
end

return VanguardAssetLoader
