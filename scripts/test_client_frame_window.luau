local Stats = require("../src/shared/ClientFrameWindow")
local w = Stats.new()
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
print("IRON YARD client FPS: bounded 240-frame window, P95/P99 and stutter counts OK")
