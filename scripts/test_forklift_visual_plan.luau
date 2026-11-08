local Plan = require("../src/shared/ForkliftVisualPlan")

local a = Plan.forCollider("INDUSTRIAL / forklift body", 8, 3.1, 11,
    "12", math.rad(10))
local b = Plan.forCollider("INDUSTRIAL / forklift body", 8, 3.1, 11,
    "27", math.pi)
assert(a and b and a.label == "12" and b.label == "27",
    "Both real forklift bodies have unique stable fleet identities")
assert(a.kind == "FREIGHT_LIFTER" and b.kind == "YARD_HANDLER",
    "Forklift pairs have distinct variants")
assert(math.abs(a.yaw - math.rad(10)) < 0.00001
    and math.abs(b.yaw - math.pi) < 0.00001,
    "Render orientation is explicitly authored on authoritative collider")
for _, name in ipairs({ "INDUSTRIAL / forklift", "INDUSTRIAL / pallet stack 1",
    "FORKLIFT / 12 / engine bonnet" }) do
    assert(not Plan.forCollider(name, 8, 3.1, 11, "12", math.rad(10)),
        "Unrelated geometry is never styled as a forklift")
end
for _, bad in ipairs({ 0, 7, 9, math.huge, -math.huge, 0 / 0 }) do
    assert(not Plan.forCollider("INDUSTRIAL / forklift body",
        bad, 3.1, 11, "12", math.rad(10)),
        "Unexpected/invalid collider widths must be rejected")
end
assert(not Plan.forCollider("INDUSTRIAL / forklift body",
    8, 3.1, 11, "99", 0),
    "Unknown fleet identifiers are rejected")
assert(not Plan.forCollider("INDUSTRIAL / forklift body",
    8, 3.1, 11, "12", math.pi),
    "Wrong pose cannot override an authenticated fleet configuration")
assert(not Plan.forCollider("INDUSTRIAL / forklift body",
    8, 3.1, 11, "12", 0 / 0),
    "Malformed rotation rejects the skin")
assert(not Plan.forCollider("INDUSTRIAL / forklift body",
    8, 3.1, 11, "27", math.huge),
    "Infinite rotation rejects the skin")
print("IRON YARD two authentically marked forklift variants and safe geometry: OK")
