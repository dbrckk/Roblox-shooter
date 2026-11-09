-- IRON YARD / cosmetic marks recycle under automatic fire without Roblox.
local Pool = require("../src/shared/ImpactMarkPool")

local p = {}
local first = Pool.claim(p, 0, 4.5, 3)
assert(first ~= nil and #p == 1)
first.fakePart = "persistent-instance"
local second = Pool.claim(p, 0.03, 4.5, 3)
local third = Pool.claim(p, 0.06, 4.5, 3)
assert(first ~= second and second ~= third and #p == 3,
    "Distinct marks may coexist within the configured budget")
local recycled = Pool.claim(p, 0.10, 4.5, 3)
assert(recycled == first and recycled.fakePart == "persistent-instance"
    and #p == 3, "Full pool reuses oldest slot without new Part allocation")
assert(Pool.alpha(first, 0.10, true) == Pool.INITIAL_ALPHA,
    "Fresh mark stays visible")
assert(Pool.alpha(first, 3.50, true) == Pool.INITIAL_ALPHA,
    "No premature fade")
local fading = Pool.alpha(first, 4.1, true)
assert(fading and fading > Pool.INITIAL_ALPHA and fading < 1,
    "Last 1.1 seconds fade progressively")
assert(Pool.alpha(first, 4.60, true) == nil, "Expired marks can be unparented")
assert(Pool.alpha(first, 0, true) == nil, "Reused mark cannot run backwards")
assert(Pool.alpha(first, 0.5, false) == nil, "ECO hides excessive active marks")
assert(Pool.alpha(first, 0/0, true) == nil, "Invalid clocks cannot update marks")

-- Long sessions with four bots and automatic weapons allocate a fixed
-- maximum of pooled objects, not one new instance per accepted bullet.
local busy = {}
for i = 0, 5000 do
    assert(Pool.claim(busy, i * 0.012, 8, 36) ~= nil)
end
assert(#busy == 36, "Unlimited impacts must not grow Roblox Part count")
for i = 1, 36 do
    assert(busy[i].startedAt and busy[i].expiresAt, "Slots always initialized")
end
assert(Pool.claim(busy, 61, 3.4, 10) ~= nil
    and #busy == 36, "Preset downgrade keeps reusable cache, not new allocations")
for i = 11, 36 do
    assert(Pool.alpha(busy[i], 61, false) == nil,
        "Previously visible quality marks are culled on mobile ECO")
end
local before = busy[1]
assert(Pool.claim(busy, 200, 3.4, 10) == before,
    "Expired slots are immediately recycled under ECO")

local reject = {}
for _, bad in ipairs({0/0, math.huge, -1}) do
    assert(Pool.claim(reject, bad, 4, 4) == nil, "Reject invalid time")
    assert(Pool.claim(reject, 5, bad, 4) == nil, "Reject invalid lifetime")
    assert(Pool.claim(reject, 5, 4, bad) == nil, "Reject invalid cap")
end
assert(Pool.claim(reject, 5, 1.1, 4) == nil, "Lifetime must exceed fade")
assert(Pool.claim(reject, 5, 4, 0) == nil)
assert(Pool.claim(reject, 5, 4, 37) == nil)
assert(Pool.claim(reject, 5, 4, 4.5) == nil)
assert(#reject == 0, "Bad inputs cannot allocate cached marks")
print("IRON YARD impact marks: 36-Part bound, reuse, fade and mobile LOD: OK")
