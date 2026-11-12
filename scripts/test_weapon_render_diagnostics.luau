local Diagnostics = require("../src/shared/WeaponRenderDiagnostics")
local d = Diagnostics.new()
assert(Diagnostics.record(d, 0.016, 0.001) == nil)
Diagnostics.clear(d)
for _ = 1, 49 do
    assert(Diagnostics.record(d, 0.02, 0.001) == nil)
end
local s = Diagnostics.record(d, 0.02, 0.004)
assert(s and s.count == 50 and s.meanMs > 1 and s.meanMs < 1.1)
assert(s.peakMs == 4)
assert(d.frames == 0 and d.sumMs == 0 and d.peakMs == 0)
-- A scoped weapon may skip nearly all geometry, but the callback is still
-- measured. Samples never allocate more than one output per 1-second window.
for _ = 1, 60 do
    local v = Diagnostics.record(d, 0.016, 0.0002)
    assert(v == nil)
end
s = Diagnostics.record(d, 0.05, 0.0002)
assert(s and s.count == 61 and s.meanMs > 0.19 and s.meanMs < 0.21)
-- One large Android background gap must not count as a slow CPU sample.
for _ = 1, 20 do assert(Diagnostics.record(d, 0.02, 0.001) == nil) end
assert(Diagnostics.record(d, 12.0, 0.01) == nil)
assert(d.frames == 0 and d.elapsed == 0)
for _ = 1, 19 do assert(Diagnostics.record(d, 0.05, 0.001) == nil) end
assert(Diagnostics.record(d, 0.05, 0.001) ~= nil)
for _, invalid in ipairs({0/0, math.huge, -math.huge, -1, "no"}) do
    assert(Diagnostics.record(d, invalid, 0.001) == nil)
    assert(Diagnostics.record(d, 0.02, invalid) == nil)
    assert(d.frames == 0)
end
assert(Diagnostics.record(nil, 0.02, 0.001) == nil)
assert(Diagnostics.record(d, 0.02, 0.26) == nil)
assert(Diagnostics.record(d, 0.02, -0.01) == nil)
-- Ten minutes of simulated 60 FPS uses bounded O(1) state.
local count = 0
for i = 1, 36000 do
    local result = Diagnostics.record(d, 1/60, 0.0005)
    if result then
        count += 1
        assert(result.meanMs > 0.49 and result.meanMs < 0.51)
        assert(result.peakMs == 0.5)
    end
end
assert(count > 550 and count <= 600)
print("IRON YARD owner weapon profiler: CPU window, Android resume and bounded state OK")
