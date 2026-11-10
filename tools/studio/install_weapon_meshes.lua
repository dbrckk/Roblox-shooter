-- IRON YARD / Roblox Studio Command Bar: install four imported original GLBs.
-- Requires the OWNER to have imported the four GLBs via Studio 3D Importer.
-- Select ALL FOUR top-level imported models in Explorer before running.
-- Never executes scripts from an imported package, never accepts missing PBR.
local Selection=game:GetService("Selection")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local expected={
    Pistol={LOD0={"IRONYARD_Pistol_Static","IRONYARD_Pistol_Slide"},
        LOD1={"IRONYARD_Pistol_Static","IRONYARD_Pistol_Slide"}},
    Knife={LOD0={"IRONYARD_Knife_Static"},LOD1={"IRONYARD_Knife_Static"}},
}
local requiredMaps={"ColorMap","NormalMap","RoughnessMap","MetalnessMap"}
local selected=Selection:Get()
assert(#selected==4,"Select four original GLB roots: Pistol/Knife LOD0 and LOD1")
local function validAppearance(mesh)
    local a=mesh:FindFirstChildOfClass("SurfaceAppearance")
    if not a then return false end
    for _,key in ipairs(requiredMaps) do
        local id=a[key]
        if typeof(id)~="string" or id=="" or id=="rbxassetid://0" then return false end
    end
    return true
end
local function identify(model)
    local n=string.lower(model.Name):gsub("[^a-z0-9]","")
    local weapon=n:find("pistol",1,true) and "Pistol"
        or n:find("knife",1,true) and "Knife" or nil
    local lod=n:find("lod0",1,true) and "LOD0"
        or n:find("lod1",1,true) and "LOD1" or nil
    assert(weapon and lod,"Imported root must include weapon name and LOD0/LOD1")
    return weapon,lod
end
local stage=Instance.new("Folder")
stage.Name="_IronYardWeaponTemplatesStaging"
local used={}
for _,root in ipairs(selected) do
    assert(root:IsA("Model"),"Each source GLB must be a Model")
    local weapon,lod=identify(root)
    local key=weapon.."_"..lod
    assert(not used[key],"Repeated original GLB variant: "..key)
    used[key]=true
    local names=expected[weapon][lod]
    local found={}
    for _,child in ipairs(root:GetDescendants()) do
        if child:IsA("MeshPart") then
            for _,name in ipairs(names) do
                if string.lower(child.Name)==string.lower(name) then
                    assert(not found[name],"Duplicate mesh "..name)
                    assert(child.MeshId~="" and validAppearance(child),
                        "Import an actual MeshId and four PBR textures for "..name)
                    found[name]=child
                end
            end
        end
    end
    for _,name in ipairs(names) do
        assert(found[name],"Missing imported mesh: "..name)
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
    origin.CFrame=root:GetPivot()
    origin.Parent=template
    template.PrimaryPart=origin
    for _,name in ipairs(names) do
        local clone=found[name]:Clone()
        local primary=clone:FindFirstChildOfClass("SurfaceAppearance")
        for _,item in ipairs(clone:GetDescendants()) do
            if item~=primary or item.Parent~=clone then item:Destroy() end
        end
        clone.Name=name
        clone.CanCollide=false
        clone.CanQuery=false
        clone.CanTouch=false
        clone.Anchored=true
        clone.CastShadow=false
        clone.Parent=template
    end
    template:SetAttribute("IronYardStudioApproved",true)
    template.Parent=category
end
for _,category in ipairs({"Pistol","Knife"}) do
    for _,lod in ipairs({"LOD0","LOD1"}) do
        assert(used[category.."_"..lod],"Incomplete source GLB quartet")
    end
end
stage.Parent=ReplicatedStorage
local old=ReplicatedStorage:FindFirstChild("IronYardWeaponTemplates")
if old then old:Destroy() end
stage.Name="IronYardWeaponTemplates"
print("IRON YARD: four PBR weapon templates installed. Save/publish the Studio place.")
print("The existing Part viewmodels remain a safe fallback for any unavailable mesh.")
