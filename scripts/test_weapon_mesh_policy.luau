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
for _,name in ipairs({"AssaultRifle","Shotgun","Sniper"}) do
    assert(#P.Required[name] >= 2, name .. " must have separate mechanical meshes")
    local complete = {}
    for _,piece in ipairs(P.Required[name]) do
        complete[piece] = true
    end
    assert(P.namesComplete(name, complete))
    local missing = P.Required[name][#P.Required[name]]
    complete[missing] = nil
    assert(not P.namesComplete(name, complete))
end
assert(P.runtimeName("IRONYARD_Pistol_Slide")=="Slide")
assert(P.runtimeName("IRONYARD_AssaultRifle_ChargingHandle")=="ChargingHandle")
assert(P.runtimeName("IRONYARD_AssaultRifle_Magazine")=="Magazine")
assert(P.runtimeName("IRONYARD_Shotgun_PumpAction")=="PumpAction")
assert(P.runtimeName("IRONYARD_Sniper_Bolt")=="Bolt")
assert(P.runtimeName("IRONYARD_Sniper_Static")=="WeaponBody")
assert(P.runtimeName("unexpected")=="WeaponBody")
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
-- PBR weapons keep the exact author-authored mesh/material look on
-- rank/finish upgrades. Only arms, gloves and procedural trim are recolored.
assert(P.canRetint({isPbrMesh=true})==false)
assert(P.canRetint({isPbrMesh=false})==true)
assert(P.canRetint({})==true)
assert(P.canRetint({isDetail=true})==true)
assert(P.canRetint({isPbrMesh=true,finishRole="panel"})==false)
assert(P.canRetint({isPbrMesh=true,finishRole="accent"})==false)
assert(P.canRetint(nil)==false)
assert(P.canRetint("bad")==false)

print("IRON YARD weapon MeshPart import policy: PBR validation, named pieces and mobile LOD OK")
