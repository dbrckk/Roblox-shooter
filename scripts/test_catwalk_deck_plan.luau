local Plan = require("../src/shared/CatwalkDeckPlan")

local inventory = {}
for _, side in ipairs({ -1, 1 }) do
    local deck = Plan.forCollider(
        "CATWALK / loading platform " .. side, 64, 3, 52)
    assert(deck and deck.kind == "DECK" and deck.side == side,
        "Both authoritative 64x3x52 catwalk platforms are recognized")
    assert(deck.number == (side == -1 and 1 or 2),
        "Catwalk numeric signage remains deterministic")
    inventory[side] = 0
    for index = 1, 5 do
        local stair = Plan.forCollider(
            "CATWALK / access stair " .. side .. ":" .. index,
            18, index * 2, 5)
        assert(stair and stair.kind == "STEP" and stair.step == index,
            "Five physical access steps per side, height-matched")
        inventory[side] += 1
    end
end
assert(inventory[-1] == 5 and inventory[1] == 5)

local offsets = Plan.deckStrips()
assert(#offsets == 6, "Six deck sheets per catwalk is the texture budget")
for index, x in ipairs(offsets) do
    assert(x + 9.3 * 0.5 < 32 and x - 9.3 * 0.5 > -32,
        "Metal floor sheets cannot protrude past game collider footprint")
    if index > 1 then
        assert(x - offsets[index - 1] > 9.3,
            "Deck plates must retain a drainage gap")
    end
end
for _, sample in ipairs({
    { "CATWALK / loading platform 0", 64, 3, 52 },
    { "CATWALK / loading platform -1", 65, 3, 52 },
    { "CATWALK / loading platform 1", 64, 3, 0/0 },
    { "CATWALK / loading platform 1", math.huge, 3, 52 },
    { "CATWALK / access stair -1:0", 18, 2, 5 },
    { "CATWALK / access stair -1:1", 18, 4, 5 },
    { "CATWALK / access stair 1:6", 18, 12, 5 },
    { "CATWALK / access stair 1:1 / art", 18, 2, 5 },
    { "CATWALK / side bulkhead 1", 2.5, 16, 64 },
}) do
    assert(Plan.forCollider(sample[1], sample[2], sample[3], sample[4]) == nil,
        "Reject unexpected geometry or cosmetic replicas")
end
assert(Plan.forCollider(nil, 64, 3, 52) == nil,
    "Unknown collider names fail closed")

for _, side in ipairs({ -1, 1 }) do
    local landing = Plan.landing(side)
    assert(Plan.forCollider("CATWALK / access landing " .. side,
        landing.width, landing.height, landing.depth).kind == "LANDING")
    local center = side * landing.x
    local near, far = center - landing.width / 2, center + landing.width / 2
    assert(near < 85 and far > 86, "Landing bridges the one-stud seam on either side")
    local top = landing.y + landing.height / 2
    assert(top - 10 == 1.5 and 13 - top == 1.5, "Last rise is split evenly across the landing")
    assert(landing.z - landing.depth / 2 == -7.5 and landing.z + landing.depth / 2 == -2.5,
        "Turn remains aligned with the final tread")
end
assert(Plan.forCollider("CATWALK / access landing 1", 6, 1.5, 5) == nil)

local west = Plan.ramp(-1)
local east = Plan.ramp(1)
assert(west.x == -east.x and west.y == east.y and west.z == east.z
    and west.pitch == east.pitch and west.length == east.length,
    "Both sides get equivalent climbs")

for _, side in ipairs({ -1, 1 }) do
    local ramp = Plan.ramp(side)
    local name = "CATWALK / access ramp " .. side
    local collider = Plan.forCollider(name, ramp.width, ramp.thickness, ramp.length)
    assert(collider and collider.kind == "RAMP" and collider.side == side)
    assert(Plan.forCollider(name, ramp.width, ramp.thickness, ramp.length + 1) == nil)
    assert(ramp.pitch > 0 and ramp.pitch < math.rad(25), "Moderate climb")
    local sin, cos = math.sin(ramp.pitch), math.cos(ramp.pitch)
    local midY = ramp.y + cos * ramp.thickness / 2
    local midZ = ramp.z + sin * ramp.thickness / 2
    local highY, lowY = midY + sin * ramp.length / 2, midY - sin * ramp.length / 2
    local highZ, lowZ = midZ - cos * ramp.length / 2, midZ + cos * ramp.length / 2
    assert(math.abs(highY - 13) < 0.001 and math.abs(lowY) < 0.001,
        "The top face meets the deck and the ground without a step")
    assert(highZ < 26 and highZ > 25.5 and math.abs(lowZ - 57) < 0.001,
        "The deck end overlaps while the base reaches the outer yard")
    local offset = ramp.x - side * 118
    for _, limit in ipairs({ 30.75, 31.35 }) do
        local original = Plan.deckEdgeSegments(side, -1, limit)
        assert(#original == 1 and original[1].width == 2 * limit,
            "The edge opposite the ramp has a continuous warning")
        local segments = Plan.deckEdgeSegments(side, 1, limit)
        assert(#segments == 2)
        assert(segments[1].center + segments[1].width / 2 < offset - ramp.width / 2
            and segments[2].center - segments[2].width / 2 > offset + ramp.width / 2,
            "Rails and safety paint leave the entire ramp entrance open")
    end
end
print("IRON YARD two decks, ten steps, two landings and two symmetric access ramps: OK")
