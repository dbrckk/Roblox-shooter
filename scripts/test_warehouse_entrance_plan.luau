-- IRON YARD / warehouse entrance and movement-safe art layout.
local Plan = require("../src/shared/WarehouseEntrancePlan")
local west = {name = "WAREHOUSE / west wall", x = -30, y = 8, z = 11,
    sx = 3, sy = 16, sz = 72, pitch = 0, yaw = 0, roll = 0}
local east = {name = "WAREHOUSE / east wall", x = 30, y = 8, z = 11,
    sx = 3, sy = 16, sz = 72, pitch = 0, yaw = 0, roll = 0}
local rear = {name = "WAREHOUSE / north bulkhead", x = 0, y = 8, z = 61,
    sx = 64, sy = 16, sz = 3, pitch = 0, yaw = 0, roll = 0}
local function clone(source)
    local t = {}
    for key, value in pairs(source) do t[key] = value end
    return t
end

local layout = Plan.layout(west, east, rear)
assert(layout ~= nil, "Existing physical walls produce entrance layout")
assert(layout.frontZ == -25 and layout.eaveY == 20
    and layout.openingWidth == 60 and layout.centerX == 0,
    "Portal follows real open warehouse approach")
assert(layout.approachZ == -37 and #layout.lanes == 3,
    "Approach remains on unobstructed asphalt ahead of warehouse")
assert(layout.lanes[1].x == -15 and layout.lanes[2].x == 0
    and layout.lanes[3].x == 15,
    "Exactly three centered wayfinding lanes")

for _, variant in ipairs({
    {key = "name", value = "WAREHOUSE / fake wall"},
    {key = "x", value = -29},
    {key = "z", value = 10},
    {key = "sx", value = 4},
    {key = "sy", value = 17},
    {key = "sz", value = 70},
    {key = "pitch", value = 15},
    {key = "yaw", value = math.huge},
    {key = "z", value = 0/0},
}) do
    local bad = clone(west)
    bad[variant.key] = variant.value
    assert(Plan.layout(bad, east, rear) == nil,
        "Invalid west wall must disable decorative portal")
end
local moved = clone(east)
moved.x = 28
assert(Plan.layout(west, moved, rear) == nil,
    "Unexpected side-wall movement must disable visuals")
local missing = clone(rear)
missing.sz = 0
assert(Plan.layout(west, east, missing) == nil,
    "North bulkhead drift invalidates placement")
assert(Plan.layout(nil, east, rear) == nil,
    "Nil physics data fails closed")
print("IRON YARD entrance geometry, 3 approach lanes and collider safety: OK")
