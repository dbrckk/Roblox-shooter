local Plan = require("../src/shared/WeaponAssetLoadPlan")
assert(Plan.MAX_WORKERS == 2)
for _, pair in ipairs({{0,0},{1,1},{2,2},{3,2},{5,2},{100,2}}) do
    assert(Plan.workers(pair[1]) == pair[2], "Bound max parallel load requests")
end
for _, value in ipairs({-4,0/0,math.huge}) do
    assert(Plan.workers(value) == 0 or Plan.workers(value) == 2)
end
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
print("IRON YARD server asset scheduler: 2 workers, terminal/fallback status OK")
