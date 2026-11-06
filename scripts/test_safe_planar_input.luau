-- Cross-platform regression test for untrusted movement remote vectors.
local Input = require("../src/shared/SafePlanarInput")
local result = Input.normalize(3, 5, 4)
assert(result and math.abs(result.x - 0.6) < 1e-8
    and math.abs(result.z - 0.8) < 1e-8, "Valid planar movement")
local reverse = Input.normalize(-3, 1, -4)
assert(reverse and math.abs(reverse.x + 0.6) < 1e-8
    and math.abs(reverse.z + 0.8) < 1e-8, "Valid backwards movement")
for _, v in ipairs({
    { 0, 0, 0 }, { 0.01, 0, 0.01 }, { math.huge, 0, 1 },
    { -math.huge, 0, 1 }, { 1, math.huge, 1 },
    { 1, 0, -math.huge }, { 1000001, 0, 1 },
    { 1, 0, 1000001 }, { "1", 0, 2 },
}) do
    assert(Input.normalize(v[1], v[2], v[3]) == nil,
        "Reject invalid, near-zero or excessive client directions")
end
assert(Input.normalize(0 / 0, 0, 1) == nil, "Reject NaN X")
assert(Input.normalize(1, 0 / 0, 1) == nil, "Reject NaN Y")
assert(Input.normalize(1, 0, 0 / 0) == nil, "Reject NaN Z")
assert(Input.normalize(0, 1, 1), "Zero X is valid")
assert(Input.normalize(1, 1, 0), "Zero Z is valid")
print("IRON YARD untrusted movement vector validation: OK")
