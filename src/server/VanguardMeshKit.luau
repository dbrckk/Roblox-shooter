-- IRON YARD / single server trust boundary for imported GLB MeshParts.
-- External Model packages must never bring arbitrary descendant Instances
-- into Workspace, even if the asset is owned by the experience creator.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Policy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VanguardMeshPolicy"))

local Kit = {}

local function maps(appearance)
    return {
        ColorMap = appearance.ColorMap,
        NormalMap = appearance.NormalMap,
        RoughnessMap = appearance.RoughnessMap,
        MetalnessMap = appearance.MetalnessMap,
    }
end

function Kit.isRenderable(mesh)
    if not mesh or not mesh:IsA("MeshPart") or mesh.MeshId == "" then
        return false
    end
    local appearance = mesh:FindFirstChildOfClass("SurfaceAppearance")
    return appearance ~= nil and Policy.mapsReady(maps(appearance))
end

-- A Studio template may contain one MeshPart per body piece. A glTF
-- upload can have several independent MeshParts (one per PBR material).
-- Require a bounded, direct-child-only, fully renderable component.
function Kit.primitives(component)
    if not component then return nil end
    if component:IsA("MeshPart") then
        if Kit.isRenderable(component) then return { component } end
        return nil
    end
    if not component:IsA("Folder") and not component:IsA("Model") then
        return nil
    end
    local children = component:GetChildren()
    if not Policy.primitiveCountValid(#children) then return nil end
    for _, child in ipairs(children) do
        if not Kit.isRenderable(child) then return nil end
    end
    return children
end

function Kit.cleanClone(source)
    assert(Kit.isRenderable(source), "Imported rig part lacks a full PBR material")
    local clone = source:Clone()
    assert(clone ~= nil, "Unclonable imported mesh cannot enter Workspace")
    -- Keep exactly ONE direct SurfaceAppearance, never descendants of
    -- imported models. This protects the live rig against embedded Scripts,
    -- Bindables, particle emitters and attachments in external assets.
    local first = clone:FindFirstChildOfClass("SurfaceAppearance")
    for _, child in ipairs(clone:GetDescendants()) do
        if not Policy.keepChild(child.ClassName, child.Parent == clone,
            child == first) then
            child:Destroy()
        end
    end
    assert(Kit.isRenderable(clone), "Sanitized part lost its material maps")
    clone.Anchored = false
    clone.Massless = true
    clone.CanCollide = false
    clone.CanTouch = false
    clone.CanQuery = false
    return clone
end

return Kit
