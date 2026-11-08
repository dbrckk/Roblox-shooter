local Plan = require("../src/shared/YardWayfindingPlan")
local zones = Plan.zones()
assert(#zones == 4, "Four clear lane names, no redundant signage")
local seen = {}
for i, zone in ipairs(zones) do
    assert(zone.id == string.format("%02d", i), "Stable field signage IDs")
    assert(type(zone.label) == "string" and #zone.label <= 18,
        "Large painted names must stay legible at phone resolution")
    assert(math.abs(zone.x) == 52 and math.abs(zone.z) == 112,
        "Marks remain in wide open freight lanes away from warehouse")
    assert(math.abs(zone.x) + 12 < 88,
        "Marks never overlap x=100 container collider footprints")
    assert(math.abs(zone.z) + 3.5 < 174,
        "Marks stay within the main 356x356 playable floor")
    local key = tostring(zone.x) .. ":" .. tostring(zone.z)
    assert(not seen[key], "Distinct non-overlapping zones")
    seen[key] = true
    for _, forklift in ipairs({
        { x = -72, z = -115 }, { x = 72, z = 115 },
    }) do
        assert(math.abs(zone.x - forklift.x) > 16
            or math.abs(zone.z - forklift.z) > 10,
            "Floor identity marks should not hide under a forklift")
    end
end
print("IRON YARD four high-contrast and nonblocking yard sector labels: OK")
