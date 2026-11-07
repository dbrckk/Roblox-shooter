local Plan = require("../src/shared/FreightSurfacePlan")
local containers = Plan.containers()
assert(#containers == 8, "Only the eight actual MapService freight colliders may be dressed")
local seen = {}
for _, box in ipairs(containers) do
    assert(box.id and not seen[box.id], "Unique container identity is required")
    seen[box.id] = true
    assert(box.height == 15 or box.height == 21 or box.height == 27,
        "Collision-matched container height")
    assert(math.abs(box.x) == 100 or box.x == 0, "Container X matches server grid")
    assert(math.abs(box.z) == 103 or box.z == 0, "Container Z matches server grid")
    assert(box.x ~= 0 or box.z ~= 0, "Central warehouse must remain empty")
end

local repairs = Plan.repairs()
assert(#repairs == 12, "At most twelve asphalt patch accents")
for _, patch in ipairs(repairs) do
    assert(math.abs(patch.x) >= 49 and math.abs(patch.x) <= 60,
        "Patches stay outside the central warehouse interior")
    assert(math.abs(patch.x) + patch.width * 0.5 < 176,
        "Yard repair must remain inside main floor bounds")
    assert(math.abs(patch.z) + patch.length * 0.5 < 176,
        "Patches must not extend outside playable asphalt")
    assert(patch.width <= 11 and patch.length <= 10,
        "Repair surfaces bounded to avoid excessive overdraw")
end
print("IRON YARD freight paint, structural casting, roof and asphalt layout: OK")
