local Stats = require("../src/shared/ClientFrameWindow")
local w = Stats.new()
assert(Stats.MAX_GAP_SECONDS == 1.0)
assert(Stats.snapshot(w) == nil)
for _, v in ipairs({0, -0.02, 0/0, math.huge, 11}) do
    assert(not Stats.push(w, v))
end
assert(Stats.snapshot(w) == nil)
for _ = 1, 95 do assert(Stats.push(w, 0.016)) end
for _ = 1, 4 do assert(Stats.push(w, 0.04)) end
assert(Stats.push(w, 0.1))
local s = Stats.snapshot(w)
assert(s.count == 100)
assert(s.p95Ms == 16 and s.p99Ms == 40 and s.peakMs == 100)
assert(s.slow33 == 5 and s.slow50 == 1)
assert(s.meanMs > 17 and s.meanMs < 18)
Stats.clear(w)
assert(Stats.snapshot(w) == nil)
for _ = 1, 240 do assert(Stats.push(w, 0.016)) end
s = Stats.snapshot(w)
assert(s.count == 240 and s.p95Ms == 16 and s.p99Ms == 16)
for _ = 1, 120 do assert(Stats.push(w, 0.05)) end
s = Stats.snapshot(w)
assert(s.count == 240 and s.meanMs > 32 and s.meanMs < 34)
assert(s.p95Ms == 50 and s.p99Ms == 50 and s.slow33 == 120)
for _ = 1, 240 do assert(Stats.push(w, 0.01)) end
s = Stats.snapshot(w)
assert(s.count == 240 and s.slow33 == 0)
assert(s.p95Ms == 10 and s.p99Ms == 10 and s.peakMs == 10)
assert(w.nextIndex == 121, "Circular index must remain bounded")
Stats.clear(w)
assert(Stats.push(w, 0.04))
s = Stats.snapshot(w)
assert(s.count == 1 and s.p95Ms == 40 and s.p99Ms == 40)
assert(s.slow33 == 1 and s.slow50 == 0)

-- Real sub-second stalls remain measurable: they are NOT silently excluded
-- simply because they look poor next to 30/60/120 FPS frame budgets.
assert(Stats.push(w, Stats.MAX_GAP_SECONDS))
s = Stats.snapshot(w)
assert(s.count == 2 and s.p95Ms == 1000 and s.peakMs == 1000)
assert(s.slow50 == 1, "A genuine one-second frame is a slow frame")

-- App suspension for >1s invalidates all old samples and the rolling timer.
local admitted, restarted = Stats.push(w, 1.01)
assert(not admitted and restarted)
assert(Stats.snapshot(w) == nil)
assert(w.count == 0 and w.sumMs == 0 and w.nextIndex == 1)
assert(Stats.push(w, 0.016))
s = Stats.snapshot(w)
assert(s.count == 1 and s.p95Ms == 16 and s.slow33 == 0,
    "New foreground measurements cannot be polluted by old resume gaps")

for _, gap in ipairs({1.001, 3, 9, 11, math.huge, 0/0, -1, 0}) do
    assert(Stats.push(w, 0.016))
    local valid, reset = Stats.push(w, gap)
    assert(not valid and reset, "Bad timing or suspension must signal reset")
    assert(Stats.snapshot(w) == nil, "Stale frame statistics must disappear")
end
print("IRON YARD Android PERF: 240-frame FPS window, true stalls and background resets OK")
