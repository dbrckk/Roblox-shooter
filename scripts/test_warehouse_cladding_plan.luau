local P = require("../src/shared/WarehouseCladdingPlan")
local side = P.sidePanels()
assert(#side == 8, "Four wall panels per side, no procedural overgrowth")
local seen = {}
for _, bay in ipairs(side) do
    assert(bay.x * bay.side > 0 and math.abs(bay.x) < 28.5,
        "Wall skin stays inside actual collision wall surface")
    assert(bay.y - bay.height * 0.5 > 0,
        "Decorative panels cannot protrude under ground level")
    assert(bay.y + bay.height * 0.5 < 16,
        "Wall panels stay inside the physical warehouse silhouette")
    assert(bay.z - bay.length * 0.5 >= -25
        and bay.z + bay.length * 0.5 <= 47,
        "Metal finish must not extend beyond the warehouse bulk")
    local key = tostring(bay.side) .. ":" .. tostring(bay.bay)
    assert(not seen[key], "Each wall bay must have unique identity")
    seen[key] = true
end
local doors = P.bulkheadPanels()
assert(#doors == 3, "Three visibly sealed berths")
for _, bay in ipairs(doors) do
    assert(bay.z < P.BULKHEAD_FACE_Z,
        "Bulkhead skin faces the playable approach, not the outside")
    assert(math.abs(bay.x) + bay.length * 0.5 < 32,
        "No false doorway or protrusion beyond the bulkhead collider")
    assert(bay.y - bay.height * 0.5 > 0
        and bay.y + bay.height * 0.5 < 16,
        "Bulkhead metal stays within collider silhouette")
end
print("IRON YARD warehouse metal cladding layouts and sealed berths: OK")

local shutters, plaques, vents = 0, 0, 0
for _, input in ipairs({
    { "WAREHOUSE / west wall", 3, 16, 72, -1, 0 },
    { "WAREHOUSE / east wall", 3, 16, 72, 1, 0 },
    { "WAREHOUSE / north bulkhead", 64, 16, 3, 0, 1 },
}) do
    local face = assert(P.exteriorFace(input[1], input[2], input[3], input[4]))
    assert(face.normalX == input[5] and face.normalZ == input[6])
    local pieces = P.exteriorPanels(face)
    assert(#pieces <= 35)
    for _, piece in ipairs(pieces) do
        assert(P.withinExterior(face, piece), "Panel protrudes: " .. piece.name)
        if piece.name:match("^closed loading shutter") then shutters += 1 end
        if piece.name:match("^vent surround") then vents += 1 end
        if piece.text then plaques += 1 end
    end
end
assert(shutters == 3 and plaques == 5 and vents == 8)
assert(P.exteriorFace("WAREHOUSE / north bulkhead", 63, 16, 3) == nil)
assert(P.exteriorFace("WAREHOUSE / west wall", 3, 0/0, 72) == nil)
assert(P.exteriorFace("WAREHOUSE / cover 1", 3, 16, 72) == nil)
