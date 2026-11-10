-- IRON YARD / pure trust and LOD policy for owner-imported weapon meshes.
-- Imported Roblox assets are optional. Never weaken the playable fallback.
local P={}
P.Required={
    Pistol={"IRONYARD_Pistol_Static","IRONYARD_Pistol_Slide"},
    Knife={"IRONYARD_Knife_Static"},
    AssaultRifle={"IRONYARD_AssaultRifle_Static",
        "IRONYARD_AssaultRifle_ChargingHandle","IRONYARD_AssaultRifle_Magazine"},
    Shotgun={"IRONYARD_Shotgun_Static","IRONYARD_Shotgun_PumpAction"},
    Sniper={"IRONYARD_Sniper_Static","IRONYARD_Sniper_Bolt"},
}
P.Maps={"ColorMap","NormalMap","RoughnessMap","MetalnessMap"}

local RUNTIME_NAMES={
    IRONYARD_Pistol_Slide="Slide",
    IRONYARD_AssaultRifle_ChargingHandle="ChargingHandle",
    IRONYARD_AssaultRifle_Magazine="Magazine",
    IRONYARD_Shotgun_PumpAction="PumpAction",
    IRONYARD_Sniper_Bolt="Bolt",
}
-- Known source names only: no client-authored data or executable descendants.
function P.runtimeName(meshName)
    return RUNTIME_NAMES[meshName] or "WeaponBody"
end

function P.lod(preset,touch)
    return (preset=="ECO" or (touch==true and preset~="QUALITY"))
        and "LOD1" or "LOD0"
end

function P.mapsReady(m)
    if type(m)~="table" then return false end
    for _,k in ipairs(P.Maps) do
        local value=m[k]
        if type(value)~="string" then return false end
        local normalized=string.lower(value):gsub("%s+","")
        if normalized=="" or normalized=="0" or normalized=="rbxassetid://0"
            or normalized=="null" then return false end
    end
    return true
end

function P.namesComplete(weapon,names)
    local required=P.Required[weapon]
    if not required or type(names)~="table" then return false end
    for _,name in ipairs(required) do
        if names[name]~=true then return false end
    end
    return true
end

return P
