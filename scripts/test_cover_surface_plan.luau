local Profile = require("../src/shared/CoverSurfacePlan")

local concrete = Profile.forCollider("COVER / concrete barrier 1:2:3", 13, 5.5, 6)
assert(concrete and concrete.style == "CAST_CONCRETE", "Freight barriers retain cast concrete")
assert(concrete.length == 13 and concrete.height == 5.5
    and concrete.surfaceOffset > 3, "All cover dimensions come from existing colliders")
assert(concrete.faceLength < concrete.length and concrete.faceHeight < concrete.height,
    "Facade is smaller than real wall, never fake larger cover")
assert(concrete.stripeCount == 3, "Three bands for 13-stud barrier")

local block = Profile.forCollider("COVER / movable roadblock 7", 13, 5, 5)
assert(block.style == "ARMED_ROADBLOCK", "Roadblocks gain reinforced panel dressing")
assert(block.stripeCount <= 5, "Bounded stripe instances")

local warehouse = Profile.forCollider("WAREHOUSE / cover -1", 9, 4.3, 12)
assert(warehouse.style == "CARGO_BARRIER", "Warehouse cover eligible")
assert(Profile.forCollider("VAULT / packing station", 14, 5, 9).style == "CARGO_BARRIER",
    "Existing vault desk eligible")

for _, name in ipairs({
    "TERMINAL / floor", "CATWALK / side bulkhead 1",
    "INDUSTRIAL / pallet stack 1", "CONTAINER / 1:1", "BOUNDARY / north-south",
}) do
    assert(Profile.forCollider(name, 13, 5, 6) == nil,
        "No extra geometry on unrelated world: " .. name)
end
assert(Profile.forCollider("COVER / movable roadblock 1", 2, 5, 5) == nil,
    "Refuse unexpectedly tiny obstacle")
assert(Profile.forCollider("COVER / movable roadblock 1", 13, 0, 5) == nil,
    "Refuse invalid collider dimensions")
assert(Profile.forCollider("COVER / movable roadblock 1", 13, 5, 0/0) == nil,
    "Refuse nonfinite dimensions")
print("IRON YARD premium freighter cover facades preserve authoritative geometry: OK")
