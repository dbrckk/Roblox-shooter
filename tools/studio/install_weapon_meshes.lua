-- IRON YARD / Roblox Studio Command Bar: install owner-imported original GLBs.
-- Select matching LOD0 + LOD1 models for any subset of the five weapons.
-- Existing approved categories are preserved through a sanitized clone.
-- Never copy scripts, attachments, unknown objects, or unvalidated meshes.
local Selection=game:GetService("Selection")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local WeaponMeshLayout=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponMeshLayout"))
local expected={
    Pistol={"IRONYARD_Pistol_Static","IRONYARD_Pistol_Slide"},
    Knife={"IRONYARD_Knife_Static"},
    AssaultRifle={"IRONYARD_AssaultRifle_Static",
        "IRONYARD_AssaultRifle_ChargingHandle","IRONYARD_AssaultRifle_Magazine"},
    Shotgun={"IRONYARD_Shotgun_Static","IRONYARD_Shotgun_PumpAction"},
    Sniper={"IRONYARD_Sniper_Static","IRONYARD_Sniper_Bolt"},
}
local requiredMaps={"ColorMap","NormalMap","RoughnessMap","MetalnessMap"}
local selected=Selection:Get()
assert(#selected>=2 and #selected<=10 and #selected%2==0,
    "Select matched LOD0 + LOD1 original GLBs (2, 4, 6, 8 or 10 models)")

local function validAppearance(mesh)
    local a=mesh:FindFirstChildOfClass("SurfaceAppearance")
    if not a then return false end
    for _,key in ipairs(requiredMaps) do
        local id=a[key]
        if typeof(id)~="string" or id=="" or id=="rbxassetid://0"
            or id=="0" then return false end
    end
    return true
end

local function identify(model)
    local n=string.lower(model.Name):gsub("[^a-z0-9]","")
    local weapon=n:find("assaultrifle",1,true) and "AssaultRifle"
        or n:find("shotgun",1,true) and "Shotgun"
        or n:find("sniper",1,true) and "Sniper"
        or n:find("pistol",1,true) and "Pistol"
        or n:find("knife",1,true) and "Knife" or nil
    local lod=n:find("lod0",1,true) and "LOD0"
        or n:find("lod1",1,true) and "LOD1" or nil
    assert(weapon and lod,"Root must include a supported weapon and LOD0/LOD1")
    return weapon,lod
end

local function collectMeshes(root, weapon)
    local groups=WeaponMeshLayout.collect(root, expected[weapon], function(child)
        return child.MeshId~="" and validAppearance(child)
            and child.Size.Magnitude>=0.03 and child.Size.Magnitude<=10
    end)
    assert(groups,"Missing, incomplete or duplicate PBR component in "..weapon)
    -- Source glTF material primitives can be nested MeshParts under a
    -- *_Node Model. Each validated group is retained for local animation.
    return groups
end

local stage=Instance.new("Folder")
stage.Name="_IronYardWeaponTemplatesStaging"
local seen={}
local replaced={}
local function installVariant(source,weapon,lod)
    local found=collectMeshes(source,weapon)
    local rootCFrame
    -- Previously approved Studio kits have a synthetic WeaponOrigin Part.
    -- Retain it exactly when rebuilding a subset, for compatibility.
    local existing=source:GetAttribute("IronYardStudioApproved")==true
        and source:FindFirstChild("WeaponOrigin")
    if existing and existing:IsA("BasePart") then
        rootCFrame=existing.CFrame
    else
        local marker=WeaponMeshLayout.origin(source, function(mesh)
            if mesh.MeshId=="" then return false end
            local extent=mesh.Size.Magnitude
            return extent==extent and extent>=0.025 and extent<=0.35
        end)
        assert(marker,"GLB missing its unique 4cm Blender weapon-origin marker")
        rootCFrame=marker.CFrame
    end
    local category=stage:FindFirstChild(weapon)
    if not category then
        category=Instance.new("Folder")
        category.Name=weapon
        category.Parent=stage
    end
    local template=Instance.new("Model")
    template.Name=lod
    local origin=Instance.new("Part")
    origin.Name="WeaponOrigin"
    origin.Size=Vector3.new(0.04,0.04,0.04)
    origin.Transparency=1
    origin.Anchored=true
    origin.CanCollide=false
    origin.CanQuery=false
    origin.CanTouch=false
    origin.CFrame=rootCFrame
    origin.Parent=template
    template.PrimaryPart=origin
    for _,name in ipairs(expected[weapon]) do
        local component=Instance.new("Model")
        component.Name=name
        for i,sourcePart in ipairs(found[name]) do
            local clone=sourcePart:Clone()
            local appearance=clone:FindFirstChildOfClass("SurfaceAppearance")
            for _,item in ipairs(clone:GetDescendants()) do
                if item~=appearance or item.Parent~=clone then item:Destroy() end
            end
            clone.Name=name.."_Primitive"..i
            clone.Anchored=true
            clone.CanCollide=false
            clone.CanQuery=false
            clone.CanTouch=false
            clone.CastShadow=false
            clone.Parent=component
        end
        component.Parent=template
    end
    template:SetAttribute("IronYardStudioApproved",true)
    template.Parent=category
end

for _,root in ipairs(selected) do
    assert(root:IsA("Model"),"Select each top-level GLB Model")
    local weapon,lod=identify(root)
    local key=weapon.."_"..lod
    assert(not seen[key],"Duplicate original GLB variant: "..key)
    seen[key]=true
    replaced[weapon]=true
    installVariant(root,weapon,lod)
end

for weapon in pairs(replaced) do
    assert(seen[weapon.."_LOD0"] and seen[weapon.."_LOD1"],
        "Both LOD0 and LOD1 are required for "..weapon)
end

-- Preserve unselected categories only if the prior saved kit is COMPLETE.
-- Every retained mesh is reconstructed through the same whitelist.
local previous=ReplicatedStorage:FindFirstChild("IronYardWeaponTemplates")
if previous then
    for weapon in pairs(expected) do
        if not replaced[weapon] then
            local folder=previous:FindFirstChild(weapon)
            local low=folder and folder:FindFirstChild("LOD1")
            local high=folder and folder:FindFirstChild("LOD0")
            if low and high and low:IsA("Model") and high:IsA("Model")
                and low:GetAttribute("IronYardStudioApproved")==true
                and high:GetAttribute("IronYardStudioApproved")==true
                and low:FindFirstChild("WeaponOrigin")
                and high:FindFirstChild("WeaponOrigin") then
                installVariant(high,weapon,"LOD0")
                installVariant(low,weapon,"LOD1")
            end
        end
    end
end

-- Stage all categories before replacing the published replicated kit.
stage.Parent=ReplicatedStorage
if previous then previous:Destroy() end
stage.Name="IronYardWeaponTemplates"
print("IRON YARD: validated weapon PBR kit installed in ReplicatedStorage.")
print("Save/publish the place from the owner account, then test Android + PC.")
print("Weapons missing an approved kit continue using procedural viewmodels.")
