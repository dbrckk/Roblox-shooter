-- IRON YARD / confirmed death dust reuses local graphics-budget Parts.
local Pool = require("../src/shared/BotDeathDustPool")
local Plan = require("../src/shared/BotDeathPlan")
assert(Pool.MAX_BOTS == 4 and Pool.MAX_PARTS == 16)
local settings = {
    {"ECO", true, 4},
    {"BALANCED", true, 8},
    {"QUALITY", true, 12},
    {"ECO", false, 4},
    {"BALANCED", false, 12},
    {"QUALITY", false, 16},
}
for _, setting in ipairs(settings) do
    local b = Plan.dustBudget(setting[1], setting[2], 0)
    assert(Pool.cap(setting[1], setting[2]) ==
        b.fragments * Pool.MAX_BOTS)
    assert(Pool.cap(setting[1], setting[2]) == setting[3])
end
local slots = {}
for _, args in ipairs({
    {-1, 0.36, 4}, {0/0, 0.36, 4}, {math.huge, 0.36, 4},
    {0, -1, 4}, {0, math.huge, 4}, {0, 0.36, 0},
    {0, 0.36, 17}, {0, 0.36, 1.5},
}) do
    assert(Pool.claim(slots, args[1], args[2], args[3]) == nil)
end
assert(#slots == 0, "Bad inputs must not create pool entries")
local a, aIndex = Pool.claim(slots, 10, 0.36, 2)
local b, bIndex = Pool.claim(slots, 10, 0.36, 2)
assert(aIndex == 1 and bIndex == 2 and a ~= b)
a.part = "reusable-instance"
assert(not Pool.claim(slots, 10.10, 0.36, 2),
    "At saturation, preserve existing visible dust")
assert(Pool.ease(a, 10, true) == 0)
local mid = Pool.ease(a, 10.18, true)
assert(math.abs(mid - 0.75) < 0.0000001,
    "Dust fade must match original Quad.Out tween")
assert(Pool.ease(a, 10.36, true) == nil)
assert(Pool.ease(a, 10.18, false) == nil)
assert(Pool.ease(a, 9.99, true) == nil)
assert(Pool.ease(a, math.huge, true) == nil)
local reused, reusedIndex = Pool.claim(slots, 10.37, 0.36, 2)
assert(reused == a and reusedIndex == 1
    and reused.part == "reusable-instance")
assert(Pool.claim(slots, 10.35, 0.36, 2) == nil,
    "Clock rollback must never overwrite an active effect")

-- Concurrent four-bot deaths, repeated round resets, live preset
-- downgrades and 50k fragments never create >16 physical Parts.
local all = {}
local peak = 0
for i = 1, 50000 do
    local at = 100 + i * 0.02
    local preset = i % 700 < 200 and "QUALITY"
        or (i % 700 < 400 and "ECO" or "BALANCED")
    local touch = i % 1400 < 700
    local cap = Pool.cap(preset, touch)
    local budget = Plan.dustBudget(preset, touch, 0)
    if i % 5 == 0 then
        for _ = 1, budget.fragments do
            local slot, index = Pool.claim(all, at, budget.duration, cap)
            if slot then
                assert(index <= cap)
                slot.part = slot.part or "same-instance"
            end
        end
    end
    for index, slot in ipairs(all) do
        local v = Pool.ease(slot, at, index <= cap)
        if v then assert(v >= 0 and v <= 1) end
    end
    peak = math.max(peak, #all)
    assert(peak <= Pool.MAX_PARTS)
end
assert(peak >= 12, "Desktop quality should exercise multiple pool slots")
-- Repeated death cycles at identical timestamps cannot reuse live slots.
local burst = {}
for _ = 1, 16 do assert(Pool.claim(burst, 2000, 0.36, 16)) end
assert(Pool.claim(burst, 2000.01, 0.36, 16) == nil)
assert(Pool.claim(burst, 2000.37, 0.36, 4) ~= nil)
assert(#burst == 16, "Quality reduction must not allocate new Parts")
print("IRON YARD death dust: 50k fragments, 4 bots, bounded 4/8/12/16 and Quad.Out: OK")
