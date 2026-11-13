local Plan = require("../src/shared/WeaponAssetLoadPlan")
assert(Plan.MAX_WORKERS == 2)
assert(Plan.MAX_FETCH_ATTEMPTS == 3)
assert(Plan.retryDelay(1) == 0.35)
assert(Plan.retryDelay(2) == 0.7)
for _, attempt in ipairs({0, -1, 3, 4, math.huge, 1.5, "2"}) do
    assert(Plan.retryDelay(attempt) == 0, "Bound retries to two short delays")
end
assert(Plan.retryDelay(0/0) == 0)
-- Only two concurrent workers, at most six remote attempts per worker.
assert(Plan.workers(9) * Plan.MAX_FETCH_ATTEMPTS == 6)
for _, pair in ipairs({{0,0},{1,1},{2,2},{3,2},{5,2},{100,2}}) do
    assert(Plan.workers(pair[1]) == pair[2], "Bound max parallel load requests")
end
for _, value in ipairs({-4,0/0,math.huge}) do
    assert(Plan.workers(value) == 0)
end
assert(Plan.workers("100") == 0)
assert(Plan.status(0,0,false) == "DISABLED")
assert(Plan.status(1,0,false) == "MANUAL")
assert(Plan.status(0,0,true) == "FALLBACK")
assert(Plan.status(1,0,true) == "PARTIAL")
assert(Plan.status(3,2,true) == "LOADING")
assert(Plan.status(0,5,true) == "LOADING")
assert(Plan.status(5,0,true) == "READY")
assert(Plan.status(5,1,true) == "READY")
assert(Plan.status(5,0,false) == "READY")
assert(Plan.status(0,0/0,true) == "FALLBACK")
assert(Plan.status(0,3,false) == "LOADING")

-- Stable worklist: only full ID pairs of uninstalled or damaged weapons.
local ids = {
    Pistol = {LOD0=1,LOD1=2},
    Knife = {LOD0=3,LOD1=4},
    AssaultRifle = {LOD0=5,LOD1=6},
    Shotgun = {LOD0=7,LOD1=8},
}
local ready = {Pistol=true, Knife=false, AssaultRifle=true, Shotgun=false}
local names = {"Pistol","Knife","AssaultRifle","Shotgun","Sniper"}
local worklist = Plan.queue(names, function(name)
    return ids[name]
end, function(name)
    return ready[name]
end)
assert(#worklist == 2, "Only incomplete authorized pairs are fetched")
assert(worklist[1].weaponId == "Knife" and worklist[1].ids.LOD0 == 3)
assert(worklist[2].weaponId == "Shotgun" and worklist[2].ids.LOD1 == 8)
assert(Plan.workers(#worklist) == 2)

-- Valid kit + absent config => zero network use. Invalid manual pair
-- becomes replaceable only if a full verified owner pair is configured.
ready.Knife = true
ready.Shotgun = true
assert(#Plan.queue(names, function(name) return ids[name] end,
    function(name) return ready[name] end) == 0)
ready.Shotgun = false
assert(#Plan.queue(names, function(name)
    return name ~= "Shotgun" and ids[name] or nil
end, function(name) return ready[name] end) == 0)
assert(#Plan.queue(nil, function() return nil end,
    function() return false end) == 0)
print("IRON YARD server asset scheduler: bounded workers, valid-pair preservation, recovery and fallback OK")
