-- IRON YARD / four tactical brains at 5Hz without same-tick bursts.
local Cadence = require("../src/shared/BotThinkCadence")
local I = 0.2
assert(Cadence.SLOTS == 4)
for slot = 1, 4 do
    local first = Cadence.firstAt(20, I, slot)
    assert(math.abs(first - (20 + (slot - 1) * I / 4)) < 1e-9)
    assert(Cadence.nextAt(20, I, slot) > 20 + I * 0.75)
end
for _, invalid in ipairs({0, 5, 1.5}) do
    assert(Cadence.nextAt(0, I, invalid) == nil)
    assert(Cadence.firstAt(0, I, invalid) == nil)
end
assert(Cadence.nextAt(-1, I, 1) == nil)
assert(Cadence.nextAt(0/0, I, 1) == nil)
assert(Cadence.nextAt(0, 0, 1) == nil)
assert(Cadence.nextAt(0, math.huge, 1) == nil)
local deadlines, counts = {}, {}
for slot = 1, 4 do
    deadlines[slot] = Cadence.firstAt(0, I, slot)
    counts[slot] = 0
end
local maxPerTick = 0
for frame = 0, 200 do
    local now = frame * 0.05
    local active = 0
    for slot = 1, 4 do
        if now + 1e-9 >= deadlines[slot] then
            active += 1
            counts[slot] += 1
            local nextDue = Cadence.nextAt(now, I, slot)
            assert(nextDue >= now + I * 0.75,
                "Decision loop must not burst again on the next server tick")
            deadlines[slot] = nextDue
        end
    end
    maxPerTick = math.max(maxPerTick, active)
end
assert(maxPerTick <= 1,
    "Under a regular 20Hz server loop, four brains must not share a tick")
for slot = 1, 4 do
    assert(counts[slot] >= 49 and counts[slot] <= 51,
        "Each bot still receives roughly 5 tactical decisions per second")
end
-- Under a late frame, do not compress the next decision into a few ms.
local afterLag = Cadence.nextAt(1.391, I, 4)
assert(afterLag > 1.391 + 0.15)
print("IRON YARD 4-bot tactical scheduler: regular 5Hz, staged 20Hz: OK")
