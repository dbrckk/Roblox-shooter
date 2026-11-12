local Visual = require("../src/shared/ShotgunReloadVisual")
assert(Visual.sample(0.5, false, "QUALITY") == nil)
assert(Visual.sample(0.5, true, "ECO") == nil)
assert(Visual.sample(0.2, true, "QUALITY") == nil)
assert(Visual.sample(0.8, true, "QUALITY") == nil)
assert(Visual.sample(0/0, true, "QUALITY") == nil)
assert(Visual.sample(math.huge, true, "QUALITY") == nil)
assert(Visual.sample(-0.5, true, "QUALITY") == nil)
local x0, y0, z0, roll0 = Visual.sample(0.27, true, "QUALITY")
local x, y, z, roll = Visual.sample(0.505, true, "BALANCED")
local xf, yf, zf, rollf = Visual.sample(0.74, true, "QUALITY")
assert(x0 ~= nil and x ~= nil and xf ~= nil)
assert(math.abs(x0) < 0.001 and math.abs(z0) < 0.001)
assert(x > 0.10 and x < 0.13 and z < -0.12 and z > -0.14)
assert(math.abs(y - 0.065) < 0.00001)
assert(math.abs(xf - 0.23) < 0.00001)
assert(math.abs(zf + 0.26) < 0.00001)
assert(math.abs(rollf + 0.28) < 0.00001)
assert(type(x) == "number" and type(y) == "number"
    and type(z) == "number" and type(roll) == "number",
    "Per-frame sample returns scalar numbers, not newly allocated tables")
for i = 0, 50000 do
    local px, py, pz, pr = Visual.sample(i / 50000, true, "BALANCED")
    if px then
        assert(px >= 0 and px <= 0.23)
        assert(py >= -0.00001 and py <= 0.065001)
        assert(pz <= 0 and pz >= -0.26)
        assert(pr <= 0 and pr >= -0.28)
    end
end
print("IRON YARD shotgun: 50k allocation-free shell poses, server reload and ECO gating OK")


-- Client-only magazine visualization uses the authoritative missing-rounds
-- snapshot, not predicted ammo. Each beat has a genuine hidden return phase.
for count = 1, 6 do
    for i = 0, count - 1 do
        local mid = 0.18 + 0.70 * (i + 0.5) / count
        local phase = Visual.phase(mid, count)
        assert(phase > 0.51 and phase < 0.52,
            "Each missing B-8 round receives a distinct full shell insertion")
        local sx, sy, sz, sr = Visual.sample(mid, true, "QUALITY", count)
        assert(sx > 0.11 and sy > 0 and sz < -0.12 and sr < -0.12)
        local gap = 0.18 + 0.70 * (i + 0.94) / count
        assert(Visual.phase(gap, count) == -1)
        assert(Visual.sample(gap, true, "QUALITY", count) == nil,
            "The reused shell must be hidden between insertions")
        assert(Visual.sample(mid, false, "QUALITY", count) == nil)
        assert(Visual.sample(mid, true, "ECO", count) == nil)
    end
end
for _, invalid in ipairs({-2, 0, 0/0, math.huge, -math.huge, "6"}) do
    assert(Visual.phase(0.5, invalid) == -1)
    assert(Visual.sample(0.5, true, "QUALITY", invalid) == nil)
end
assert(Visual.phase(math.huge, 6) == -1)
assert(Visual.phase(-math.huge, 6) == -1)
assert(Visual.sample(0.1, true, "QUALITY", 6) == nil)
assert(Visual.sample(0.9, true, "QUALITY", 6) == nil)
print("IRON YARD: 1-6 authoritative B-8 cartridge beats, hidden resets, ECO and cancellation OK")
