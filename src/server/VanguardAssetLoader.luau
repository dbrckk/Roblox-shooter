-- IRON YARD / optional owner-controlled PBR asset delivery.
-- The game never downloads or executes scripts from uploaded Model packages:
-- it selects only seven MeshParts with expected names from each package.
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

local function hasCompleteTemplateSet(folder)
    for _, palette in ipairs(COLORS) do
        local variant = folder:FindFirstChild(palette)
        if not variant then return false end
        for _, piece in ipairs(PIECES) do
            local mesh = variant:FindFirstChild(piece)
            if not MeshKit.isRenderable(mesh) then
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
    local loaded = InsertService:LoadAsset(id)
    assert(loaded and loaded:IsA("Model"), "Roblox asset is not a Model package")
    -- The loaded container stays outside Workspace. Even a creator-owned
    -- package is untrusted: only validated and sanitized meshes cross over.
    local success, extracted = pcall(function()
        local selected = {}
        for _, item in ipairs(loaded:GetDescendants()) do
            if item:IsA("MeshPart") then
                local name = Policy.identifyPiece(item.Name)
                if name then
                    assert(selected[name] == nil, "Duplicate imported mesh " .. name)
                    assert(MeshKit.isRenderable(item),
                        "Missing one or more PBR maps on " .. name)
                    selected[name] = item
                end
            end
        end
        for _, name in ipairs(PIECES) do
            assert(selected[name] ~= nil, "Missing imported VANGUARD mesh " .. name)
        end
        local paletteFolder = Instance.new("Folder")
        paletteFolder.Name = palette
        for _, name in ipairs(PIECES) do
            local clone = MeshKit.cleanClone(selected[name])
            clone.Name = name
            clone.Parent = paletteFolder
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
        Workspace:SetAttribute("IronYardPbrStatus", "FALLBACK")
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
