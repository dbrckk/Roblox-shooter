local Plan = require("../src/shared/WeaponDetailPlan")
local expected = {
    Pistol = {4,10,15},
    Knife = {4,9,14},
    AssaultRifle = {0,6,12},
    Shotgun = {0,5,11},
    Sniper = {0,5,11},
}
for name, counts in pairs(expected) do
    for tier=1,3 do
        local preset = tier==1 and "ECO" or tier==2 and "BALANCED" or "QUALITY"
        local touch = tier <= 2
        local details = Plan.get(name, preset, touch)
        assert(details and #details == counts[tier], name.." detail budget "..tier)
        assert(details == Plan.get(name, preset, touch),
            "Reusing tier must return the exact cached table")
        local ids = {}
        for _, d in ipairs(details) do
            assert(not ids[d.name], "Every detail part needs a unique name")
            ids[d.name] = true
            assert(d.tier<=tier and #d.position==3 and #d.size==3
                and #d.color==3 and #d.angles==3)
            assert(d.shape=="Block" or d.shape=="Ball"
                or d.shape=="Cylinder" or d.shape=="Wedge")
            assert(d.finish=="accent" or d.finish=="panel" or d.finish=="dark")
            for _, length in ipairs(d.size) do
                assert(type(length)=="number" and length>0 and length<1,
                    "Cosmetic parts stay small, not block player sight")
            end
            for _, channel in ipairs(d.color) do
                assert(channel>=0 and channel<=255)
            end
        end
    end
end
assert(Plan.get("Knife","QUALITY",true) == Plan.get("Knife","BALANCED",false))
assert(Plan.get("Pistol","QUALITY",true) == Plan.get("Pistol","QUALITY",false))
assert(Plan.get("Knife","ECO",false) == Plan.get("Knife","ECO",true))
assert(Plan.get("Unknown","QUALITY",false)==nil)
for _, id in ipairs({"AssaultRifle","Shotgun","Sniper"}) do
    assert(#Plan.get(id,"ECO",true)==0,
        "ECO must not add permanent viewmodel Parts on long guns")
    local mobile=Plan.get(id,"BALANCED",true)
    local desktop=Plan.get(id,"QUALITY",false)
    for i=1,#mobile do assert(mobile[i]==desktop[i]) end
    for _=1,10000 do
        assert(Plan.get(id,"BALANCED",true)==mobile,
            "Long-gun cosmetic LOD is cached, not recomputed each shot")
    end
end
assert(Plan.tier("ECO",false)==1 and Plan.tier("BALANCED",true)==2)
assert(Plan.tier("BALANCED",false)==3)
-- Switching ECO <-> BALANCED <-> QUALITY changes only allowed details.
local eco=Plan.get("Pistol","ECO",true)
local balanced=Plan.get("Pistol","BALANCED",true)
local quality=Plan.get("Pistol","QUALITY",true)
for i=1,#eco do assert(eco[i]==balanced[i] and eco[i]==quality[i]) end
for i=1,#balanced do assert(balanced[i]==quality[i]) end
assert(eco~=balanced and balanced~=quality,
    "Tier changes select cached distinct lists without rebuilding data")
for i=1,25000 do
    assert(Plan.get("Pistol","BALANCED",true)==Plan.get("Pistol","BALANCED",true))
end
print("IRON YARD detail plan: all 5 weapons tiered, ECO long-gun zero, cached LOD OK")
