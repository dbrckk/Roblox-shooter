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
print("IRON YARD two fully cladded decks, ten physical access steps: OK")

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
