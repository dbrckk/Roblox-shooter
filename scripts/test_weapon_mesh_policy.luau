local P=require("../src/shared/WeaponMeshPolicy")
assert(P.lod("ECO",false)=="LOD1")
assert(P.lod("ECO",true)=="LOD1")
assert(P.lod("BALANCED",true)=="LOD1")
assert(P.lod("QUALITY",true)=="LOD0")
assert(P.lod("BALANCED",false)=="LOD0")
assert(P.namesComplete("Pistol",{IRONYARD_Pistol_Static=true,IRONYARD_Pistol_Slide=true}))
assert(not P.namesComplete("Pistol",{IRONYARD_Pistol_Static=true}))
assert(P.namesComplete("Knife",{IRONYARD_Knife_Static=true}))
assert(not P.namesComplete("Knife",{IRONYARD_Knife_Static="true"}))
assert(not P.namesComplete("Unknown",{}))
local m={ColorMap="rbxassetid://111",NormalMap="rbxassetid://222",
    RoughnessMap="rbxassetid://333",MetalnessMap="rbxassetid://444"}
assert(P.mapsReady(m))
for _,name in ipairs(P.Maps) do
    local tmp=table.clone(m)
    tmp[name]="rbxassetid://0"
    assert(not P.mapsReady(tmp))
    tmp[name]=nil
    assert(not P.mapsReady(tmp))
end
assert(not P.mapsReady(nil) and not P.mapsReady({}))
print("IRON YARD weapon MeshPart import policy: PBR validation, named pieces and mobile LOD OK")
