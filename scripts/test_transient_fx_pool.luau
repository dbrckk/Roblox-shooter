-- IRON YARD / pool of all transient impact and flash Parts.
local Pool = require("../src/shared/TransientFxPool")
local function eq(a, b, description)
    assert(a == b, description .. " (" .. tostring(a) .. ")")
end

eq(Pool.cap("ECO", true), 24, "Mobile ECO")
eq(Pool.cap("BALANCED", true), 48, "Mobile balanced")
eq(Pool.cap("QUALITY", true), 72, "Mobile quality")
eq(Pool.cap("BALANCED", false), 80, "PC balanced")
eq(Pool.cap("QUALITY", false), 96, "PC quality")
eq(Pool.cap("ECO", false), 24, "Desktop ECO")

local slots = {}
local one, firstIndex = Pool.claim(slots, 10, 0.25, 3, 1)
local two, secondIndex = Pool.claim(slots, 10, 0.25, 3, 2)
local three, thirdIndex = Pool.claim(slots, 10, 0.25, 3, 4)
eq(firstIndex, 1, "First live slot index")
eq(secondIndex, 2, "Second live slot index")
eq(thirdIndex, 3, "Third live slot index")
one.part = "original-roblox-part"
assert(one and two and three and #slots == 3)
eq(Pool.claim(slots, 10.01, 0.24, 3, 1), one,
    "Debris can replace other debris at saturation")
eq(one.part, "original-roblox-part", "Persistent part identity")
assert(Pool.claim(slots, 10.02, 0.2, 3, 2) == one,
    "Tracer can preempt an old chip")
assert(Pool.claim(slots, 10.03, 0.1, 3, 1) == nil,
    "Debris cannot preempt tracer or local flash")
assert(Pool.claim(slots, 10.04, 0.1, 3, 4) == one,
    "High priority flash takes earliest expiring eligible tracer")
assert(Pool.claim(slots, 10.05, 0.1, 3, 4) == one,
    "High priority may recycle its own earliest expiry slot")
eq(Pool.progress(one, 10.05, true), 0, "Most recent effect begins at zero")
local progress = Pool.progress(one, 10.10, true)
assert(progress and progress > 0 and progress < 1, "Smooth fractional animation")
assert(Pool.progress(one, 10.16, true) == nil, "Expired effect disappears")
assert(Pool.progress(one, 10.05, false) == nil, "Quality switch hides surplus")
assert(Pool.progress(one, 10.01, true) == nil, "Time cannot predate effect")
assert(Pool.progress(one, 0/0, true) == nil, "NaN progress rejected")
assert(Pool.claim(slots, 9.9, 0.1, 3, 4) == nil,
    "Reversed time cannot refill active pool")

local flood = {}
for i = 0, 12000 do
    local priority = (i % 7 == 0) and 4 or 1
    Pool.claim(flood, i * 0.002, 0.29, 48, priority)
end
assert(#flood == 48, "20+ seconds of four-bot fire uses at most 48 Parts")
local samePart = flood[1]
local newSlot = Pool.claim(flood, 30, 0.10, 24, 4)
assert(newSlot == samePart and #flood == 48,
    "Downgrade ECO reuses eligible objects without allocating")
for i = 25, #flood do
    assert(Pool.progress(flood[i], 30, false) == nil,
        "Downgraded quality cannot show surplus effects")
end
local mobile = {}
for i = 0, 20000 do
    Pool.claim(mobile, i * 0.003, 0.29, 96, (i % 6) + 1)
end
assert(#mobile <= 96, "Desktop VFX use at most 96 Parts")
local invalid = {}
for _, bad in ipairs({0/0, math.huge, -1}) do
    assert(Pool.claim(invalid, bad, 0.2, 24, 2) == nil)
    assert(Pool.claim(invalid, 1, bad, 24, 2) == nil)
    assert(Pool.claim(invalid, 1, 0.2, bad, 2) == nil)
    assert(Pool.claim(invalid, 1, 0.2, 24, bad) == nil)
end
assert(Pool.claim(invalid, 1, 0.7, 24, 2) == nil)
assert(Pool.claim(invalid, 1, 0.2, 97, 2) == nil)
assert(Pool.claim(invalid, 1, 0.2, 24, 0) == nil)
assert(Pool.claim(invalid, 1, 0.2, 24, 5) == nil)
assert(Pool.claim(nil, 1, 0.2, 24, 2) == nil)
assert(#invalid == 0, "Invalid data never allocates slots")
-- Simulate RenderStepped's active-index tracking through sustained bot fire,
-- profile downgrades, idle periods, and local muzzle-flash priority.
local renderSlots, active = {}, {}
local function spawn(at, priority, cap)
    local slot, index = Pool.claim(renderSlots, at, 0.12, cap, priority)
    if slot then
        assert(type(index) == "number" and index >= 1 and index <= cap)
        assert(renderSlots[index] == slot, "Exact index must identify the pooled Part")
        active[index] = true
    end
end
local function tick(at, cap)
    local n = 0
    for index in pairs(active) do
        if Pool.progress(renderSlots[index], at, index <= cap) then
            n += 1
        else
            active[index] = nil
        end
    end
    return n
end
for shot = 1, 18000 do
    local now = shot * 0.004
    local cap = shot < 6000 and 72 or shot < 12000 and 24 or 48
    spawn(now, shot % 3 == 0 and 4 or 1, cap)
    if shot % 2 == 0 then tick(now, cap) end
    assert(#renderSlots <= 72)
end
assert(tick(100, 24) == 0 and next(active) == nil,
    "All expired effects must leave the active rendering set")
assert(#renderSlots > 0 and #renderSlots <= 72,
    "Idle rendering must preserve pooled Part storage")
spawn(101, 4, 24)
assert(next(active) ~= nil and tick(101, 24) == 1,
    "Local flash must reawaken an idle pool immediately")
assert(tick(101.13, 24) == 0 and next(active) == nil,
    "A completed flash never triggers perpetual per-frame scanning")
local qualitySlots, qualityActive = {}, {}
for i = 1, 72 do
    local slot, index = Pool.claim(qualitySlots, 102, 0.45, 72, 4)
    assert(slot and index == i)
    qualityActive[index] = true
end
for index in pairs(qualityActive) do
    if not Pool.progress(qualitySlots[index], 102.01, index <= 24) then
        qualityActive[index] = nil
    end
end
local count = 0
for index in pairs(qualityActive) do
    assert(index <= 24, "ECO must retire indices above its VFX cap")
    count += 1
end
assert(count == 24, "Quality downgrade retains only 24 eligible flashes")
print("IRON YARD transient VFX: priorities, 18k shots and idle slot retirement: OK")
