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
local one = Pool.claim(slots, 10, 0.25, 3, 1)
local two = Pool.claim(slots, 10, 0.25, 3, 2)
local three = Pool.claim(slots, 10, 0.25, 3, 4)
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
print("IRON YARD transient VFX: mobile 24/48/72, priority and 96-Part cap: OK")
