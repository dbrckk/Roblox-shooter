local Plan = require("../src/shared/CoverSurfacePlan")

local seen = {}
local counts = { CAST_CONCRETE = 0, ARMED_ROADBLOCK = 0, CARGO_BARRIER = 0 }
local signs = 0
local function valid(name, x, y, z, kind)
    local plan = Plan.forCollider(name, x, y, z)
    assert(plan and plan.style == kind, "Missing exact real MapService cover: " .. name)
    assert(not seen[name], "Same real collider cannot be dressed twice")
    seen[name] = true
    assert(plan.faceLength < x and plan.faceHeight < y
        and plan.surfaceOffset > z * 0.5,
        "Cosmetic armor may not pretend to extend the physical cover")
    assert(plan.stripeCount >= 2 and plan.stripeCount <= 5,
        "Road and freight warning details must be bounded")
    counts[kind] += 1
    if plan.serial then
        assert(#plan.serial < 32, "Identification must remain legible")
        signs += 1
    end
    return plan
end

for row = -1, 1 do
    for column = -1, 1 do
        if row ~= 0 or column ~= 0 then
            local withSerial = 0
            for _, side in ipairs({ -1, 1 }) do
                local p = valid(string.format(
                    "COVER / concrete barrier %d:%d:%d", row, column, side),
                    13, 5.5, 6, "CAST_CONCRETE")
                if p.serial then withSerial += 1 end
            end
            assert(withSerial == 1, "One freight label per container cluster")
        end
    end
end
local roadblocks = 0
for i = 1, 16 do
    local angle, radius = i * math.pi / 8, 57 + i % 3 * 10
    local x, z = math.cos(angle) * radius, math.sin(angle) * radius
    local plan = Plan.forCollider(
        "COVER / movable roadblock " .. i, 13, 5, 5)
    if z > -46 or math.abs(x) > 35 then
        assert(plan, "Roadblock in the game must be admitted")
        valid("COVER / movable roadblock " .. i, 13, 5, 5, "ARMED_ROADBLOCK")
        roadblocks += 1
    else
        assert(plan == nil, "Never decorate an absent MapService roadblock")
    end
end
assert(roadblocks == 13, "Expected actual roadblock inventory")

for _, side in ipairs({ -1, 1 }) do
    valid("WAREHOUSE / cover " .. side, 9, 4.3, 12, "CARGO_BARRIER")
end
valid("VAULT / packing station", 14, 5, 9, "CARGO_BARRIER")
assert(counts.CAST_CONCRETE == 16 and counts.ARMED_ROADBLOCK == 13
    and counts.CARGO_BARRIER == 3, "Only 32 real cover sources")
assert(signs == 16, "Limit decals to sixteen major wayfinding signs")

for _, name in ipairs({
    "TERMINAL / floor", "CATWALK / side bulkhead 1",
    "INDUSTRIAL / pallet stack 1", "CONTAINER / 1:1",
    "COVER / concrete barrier 1:2:3", "COVER / concrete barrier 0:0:1",
    "COVER / concrete barrier 1:1:0", "COVER / concrete barrier 01:1:1",
    "COVER / concrete barrier 1:1:1 / cosmetic",
    "COVER / movable roadblock 0", "COVER / movable roadblock 17",
    "COVER / movable roadblock 01", "COVER / movable roadblock 12",
    "WAREHOUSE / cover 0", "WAREHOUSE / cover 2",
}) do
    assert(Plan.forCollider(name, 13, 5.5, 6) == nil,
        "Unexpected or non-authoritative collider must fail closed: " .. name)
end
assert(Plan.forCollider("COVER / movable roadblock 1", 2, 5, 5) == nil)
assert(Plan.forCollider("COVER / movable roadblock 1", 13, 0, 5) == nil)
assert(Plan.forCollider("COVER / movable roadblock 1", 13, 5, 0/0) == nil)
assert(Plan.forCollider("COVER / movable roadblock 1", 13, 5, math.huge) == nil)
assert(Plan.forCollider(nil, 13, 5, 5) == nil)
print("IRON YARD 32 collider-verified combat covers, 16 cargo wayfinding signs: OK")
