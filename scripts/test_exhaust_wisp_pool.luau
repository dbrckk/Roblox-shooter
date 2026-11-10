local Pool = require("../src/shared/ExhaustWispPool")
local Profile = require("../src/shared/EnvironmentProfile")
assert(Pool.MAX_PARTS == 12 and Pool.DURATION == 1.08)
assert(Pool.cap(Profile.get("ECO", true)) == 0)
assert(Pool.cap(Profile.get("BALANCED", true)) == 2)
assert(Pool.cap(Profile.get("QUALITY", true)) == 5)
assert(Pool.cap(Profile.get("BALANCED", false)) == 5)
assert(Pool.cap(Profile.get("QUALITY", false)) == 11)
assert(Pool.cap(nil) == 0)
assert(Pool.cap({ exhausts = 0, exhaustInterval = 0.8 }) == 0)
assert(Pool.cap({ exhausts = math.huge, exhaustInterval = 0.8 }) == 0)
assert(Pool.cap({ exhausts = 1, exhaustInterval = 0/0 }) == 0)
assert(Pool.cap({ exhausts = 99, exhaustInterval = 0.001 }) == 12)

local slots = {}
assert(not Pool.claim(slots, 1, 0))
assert(not Pool.claim(slots, 1, 13))
assert(not Pool.claim(slots, -1, 2))
assert(not Pool.claim(slots, math.huge, 2))
assert(not Pool.claim(slots, 0/0, 2))
local first, index = Pool.claim(slots, 1, 2)
assert(first and index == 1)
first.part = "same-part"
local second, secondIndex = Pool.claim(slots, 1.1, 2)
assert(second and secondIndex == 2)
assert(Pool.claim(slots, 1.2, 2) == nil,
    "Never replace still-visible vapor under a low quality cap")
assert(Pool.alpha(first, 1, true) == 0)
local middle = Pool.alpha(first, 1.54, true)
assert(middle > 0.74 and middle < 0.76, "Match Quad.Out interpolation")
assert(Pool.alpha(first, 2.08, true) == nil)
assert(Pool.alpha(first, 1.54, false) == nil)
assert(Pool.alpha(first, 0.9, true) == nil)
assert(Pool.alpha(first, math.huge, true) == nil)
local reused, reusedIndex = Pool.claim(slots, 2.1, 2)
assert(reused == first and reusedIndex == 1 and reused.part == "same-part")
assert(not Pool.claim(slots, 2.0, 2), "Time rollback must not overwrite the pool")
assert(Pool.alpha(second, 2.1, true) ~= nil,
    "Other active wisps continue moving when one is reused")

-- Same session: 20000 staggered emissions and ECO/QUALITY transitions
-- cannot allocate beyond its maximum, even if every vent emits.
local live = {}
local peak = 0
for tick = 1, 20000 do
    local at = tick * 0.04
    local preset = tick % 300 < 50 and "ECO"
        or (tick % 300 < 160 and "QUALITY" or "BALANCED")
    local settings = Profile.get(preset, true)
    local cap = Pool.cap(settings)
    if cap > 0 then
        local slot, ix = Pool.claim(live, at, cap)
        if slot then
            assert(ix <= cap and live[ix] == slot)
            slot.part = slot.part or "reused-part"
        end
    end
    peak = math.max(peak, #live)
    assert(peak <= Pool.MAX_PARTS)
    for i, slot in ipairs(live) do
        local eased = Pool.alpha(slot, at, i <= cap)
        if eased then assert(eased >= 0 and eased <= 1) end
    end
end
assert(peak > 1 and peak <= 5, "Mobile quality never exceeds its 5-Part budget")
local oldSlots = #live
assert(Pool.claim(live, 801, 2) ~= nil and #live == oldSlots,
    "Quality downgrade reuses already-created Parts")
assert(Pool.claim(live, 800, 2) == nil)
print("IRON YARD vapor: capped 0/2/5/5/11 Parts, 20k emission cycles and Quad.Out: OK")
