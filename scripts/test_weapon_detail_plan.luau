local Plan = require("../src/shared/WeaponDetailPlan")
local expected = {
    Pistol = {4,10,15},
    Knife = {4,9,14},
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
assert(Plan.tier("ECO",false)==1 and Plan.tier("BALANCED",true)==2)
assert(Plan.tier("BALANCED",false)==3)
for i=1,25000 do
    assert(Plan.get("Pistol","BALANCED",true)==Plan.get("Pistol","BALANCED",true))
end
print("IRON YARD detail plan: Pistol 4/10/15, Knife 4/9/14, cached LOD, 25k lookups OK")
