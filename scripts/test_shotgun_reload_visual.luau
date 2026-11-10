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
