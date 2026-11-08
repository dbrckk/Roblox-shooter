local P = require("../src/shared/PalletVisualPlan")

local expected = {
    "TIMBER_CRATE", "WRAPPED_FREIGHT", "STEEL_CAGE",
    "TIMBER_CRATE", "WRAPPED_FREIGHT",
}
local styles = {}
for index, style in ipairs(expected) do
    local plan = P.forCollider(
        "INDUSTRIAL / pallet stack " .. index, 9, 3.7, 9)
    assert(plan and plan.index == index, "All five real pallets have plans")
    assert(plan.label == string.format("IY-%02d", index),
        "Each cargo unit has stable identification")
    assert(plan.style == style, "Different cargo silos have distinct styling")
    styles[plan.style] = true
end
assert(styles.TIMBER_CRATE and styles.WRAPPED_FREIGHT and styles.STEEL_CAGE,
    "All three distinctive freight silhouettes must be present")

for _, invalid in ipairs({
    "INDUSTRIAL / pallet stack 0",
    "INDUSTRIAL / pallet stack 6",
    "INDUSTRIAL / pallet stack 01",
    "INDUSTRIAL / pallet stack 1 / shell",
    "INDUSTRIAL / forklift body",
    "OTHER / pallet stack 3",
}) do
    assert(P.forCollider(invalid, 9, 3.7, 9) == nil,
        "Only matching gameplay pallet colliders may be decorated")
end
assert(P.forCollider("INDUSTRIAL / pallet stack 1", 10, 3.7, 9) == nil,
    "Must reject pallets with mismatched widths")
assert(P.forCollider("INDUSTRIAL / pallet stack 1", 9, 4.3, 9) == nil,
    "Must reject pallets with mismatched heights")
assert(P.forCollider("INDUSTRIAL / pallet stack 1", 9, 3.7, 0/0) == nil,
    "Must reject invalid dimensions")
assert(P.forCollider("INDUSTRIAL / pallet stack 1", 9, 3.7, math.huge) == nil,
    "Must reject infinite dimensions")
assert(P.forCollider(nil, 9, 3.7, 9) == nil,
    "Must reject unnamed parts")
print("IRON YARD five collider-matched pallets, three visual styles: OK")
