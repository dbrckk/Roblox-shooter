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

local Deck = require("../src/shared/LoadingDeckPlan")
local ramp, underpass, yardExit = table.unpack(Plan.transferRoutes())
assert(ramp.id == "RAMP" and underpass.id == "UNDERPASS")
assert(ramp.z == underpass.z and ramp.x == Deck.ramp().x and underpass.x < -14.1,
    "Read both choices on the same approach, west of the container or in line with the ramp")
local previousZ = ramp.z
for _, arrow in ipairs(ramp.arrows) do
    assert(arrow.x == ramp.x and arrow.z < previousZ and arrow.yaw == 0,
        "Ramp arrows stay on the uphill centerline")
    previousZ = arrow.z
end
local turn = underpass.arrows[4]
assert(turn.z < 90 - 0.25 and turn.yaw == -math.pi / 2,
    "Turn east only beyond the center container")
local entry = underpass.arrows[#underpass.arrows - 1]
assert(entry.x > Deck.support(-1).x + Deck.support(-1).width / 2 + 2.1
    and entry.x < Deck.ramp().x - Deck.ramp().width / 2 - 2.1,
    "Point down the clear valley between the ramp and the west support")
assert(entry.z == turn.z and entry.yaw == 0
    and underpass.arrows[#underpass.arrows].z == Deck.z)
print("IRON YARD separated ramp and underpass directions: OK")

assert(yardExit.id == "YARD_EXIT" and yardExit.label == "YARD EXIT")
assert(yardExit.x == entry.x and yardExit.z + 1.9 < Deck.z - Deck.depth / 2,
    "The exit label is visible from the passage and is outside the deck shadow line")
local eastEdge = Deck.x + Deck.width / 2
local rampEdge = Deck.ramp().x + Deck.ramp().width / 2
local lastX, lastZ = yardExit.x, yardExit.z
for i, arrow in ipairs(yardExit.arrows) do
    if i <= 2 then
        assert(arrow.x > lastX and arrow.z == lastZ and arrow.yaw == -math.pi / 2,
            "Clear the deck to the east after leaving the passage")
    else
        assert(arrow.x > math.max(eastEdge, rampEdge) + 2.1 and arrow.yaw == math.pi,
            "The path returns to the yard on the far side of the ramp")
        assert(i == 3 and arrow.z == lastZ or i > 3 and arrow.z > lastZ)
    end
    lastX, lastZ = arrow.x, arrow.z
end
assert(lastZ > ramp.arrows[#ramp.arrows].z - 0.001, "The return signs lead out into the yard")
print("IRON YARD underpass exit and clear return lane: OK")
