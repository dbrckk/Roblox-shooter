-- IRON YARD / four exact gameplay colliders drive the wall art.
local Plan = require("../src/shared/PerimeterWallPlan")
local valid = {
    {"BOUNDARY / east-west -1", 4, 38, 356, "X", -1, "WEST"},
    {"BOUNDARY / east-west 1", 4, 38, 356, "X", 1, "EAST"},
    {"BOUNDARY / north-south -1", 356, 38, 4, "Z", -1, "NORTH"},
    {"BOUNDARY / north-south 1", 356, 38, 4, "Z", 1, "SOUTH"},
}
for _, input in ipairs(valid) do
    local result = Plan.layout(input[1], input[2], input[3], input[4])
    assert(result ~= nil and result.axis == input[5]
        and result.side == input[6] and result.label == input[7],
        "Perimeter art must follow exact collider identity and dimensions")
    assert(#result.panels == 7, "Seven large bays per real wall")
    local signals = 0
    local extras = 0
    for i, panel in ipairs(result.panels) do
        assert(panel.index == i and panel.along == (i - 4) * 50
            and panel.width == 46, "Regular, visually distinct cladding bays")
        assert(math.abs(panel.along) + panel.width / 2 < 356 / 2,
            "Panels must stay within the real boundary collider")
        if panel.signal then signals += 1 end
        if panel.detail then extras += 1 end
    end
    assert(signals == 3 and extras == 3, "Bounded sign and LOD allocation")
end
for _, bad in ipairs({
    {"BOUNDARY / east-west 0", 4, 38, 356},
    {"BOUNDARY / east-west 1", 356, 38, 4},
    {"BOUNDARY / north-south -1", 4, 38, 356},
    {"BOUNDARY / north-south 1", 356, 39, 4},
    {"BOUNDARY / east-west 1", 4, 38, 355},
    {"BOUNDARY / east-west 1", 4, 38, 0/0},
    {"BOUNDARY / east-west 1", math.huge, 38, 356},
    {"COVER / movable roadblock 1", 4, 38, 356},
}) do
    assert(Plan.layout(bad[1], bad[2], bad[3], bad[4]) == nil,
        "Do not render wall art over an invalid or renamed game collider")
end
print("IRON YARD four real perimeter walls, 28 bay panels and LOD/sign budgets: OK")
