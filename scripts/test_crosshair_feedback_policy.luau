-- Pure client cosmetic crosshair response and bounded update cadence.
local P = require("../src/shared/CrosshairFeedbackPolicy")
local ids = {"AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife"}
for _, id in ipairs(ids) do
    local base = P.radius(id, 0, false, 0)
    local moving = P.radius(id, 1, false, 0)
    local running = P.radius(id, 1, true, 0)
    local shot = P.radius(id, 0, false, P.kick(id, 0))
    assert(base >= 10 and base <= 33)
    assert(moving > base and running > moving)
    assert(shot > base, "Every gun shows a visible cosmetic shot impulse")
    local k = P.kick(id, 0)
    local recovered = P.recover(k, 0.1)
    assert(recovered < k and recovered > 0)
    local prev = k
    for _ = 1, 120 do prev = P.recover(prev, 1 / 60) end
    assert(prev < 0.01)
end
assert(P.kick("Shotgun", 12) == 12)
assert(P.kick("Unknown", 0) == 0)
assert(P.radius("Shotgun", 900, true, 100) == 33)
assert(P.radius("Unknown", 0, false, 0) == 15)
assert(P.radius("Unknown", 0/0, false, 1) == 15)
assert(P.recover(math.huge, 0.1) == 0)
assert(P.recover(0/0, 0.1) == 0)
assert(P.shouldDraw(10, -math.huge, nil, 15))
assert(not P.shouldDraw(10.01, 10, 15, 16))
assert(P.shouldDraw(10.06, 10, 15, 16))
assert(not P.shouldDraw(10.06, 10, 16, 16))
assert(not P.shouldDraw(0/0, 0, 10, 15))
local now, lastAt, lastRadius, writes = 0, -math.huge, nil, 0
local kick = 0
for i = 1, 3600 do
    now = i / 60
    if i % 15 == 0 then kick = P.kick("AssaultRifle", kick) end
    kick = P.recover(kick, 1/60)
    local radius = P.radius("AssaultRifle", i % 90 < 45 and 1 or 0, false, kick)
    if P.shouldDraw(now, lastAt, lastRadius, radius) then
        writes += 1
        lastRadius = radius
        lastAt = now
    end
end
assert(writes > 50 and writes < 1200,
    "A full combat minute never rewrites 4 UI Frames on every RenderStepped")
print("IRON YARD responsive cosmetic crosshair: five guns, recoil and UI throttle OK")
