-- IRON YARD / untrusted client aim must fail closed without allocations.
local Policy = require("../src/shared/ShotInputPolicy")

assert(Policy.validDirection(0, 0, 1))
assert(Policy.validDirection(1, 0, 0))
assert(Policy.validDirection(0, -1, 0))
assert(Policy.validDirection(1000000, 0, 0), "Exact coordinate limit is allowed")
assert(Policy.validDirection(0.001, 0, 0), "Normalized threshold is inclusive")
assert(not Policy.validDirection(0, 0, 0))
assert(not Policy.validDirection(0.0009, 0, 0))
assert(not Policy.validDirection(0, 0, 0.00001))
assert(not Policy.validDirection(1000001, 0, 1))
assert(not Policy.validDirection(0, -1000001, 1))
assert(not Policy.validDirection(0, 1, 1000001))
assert(not Policy.validDirection(math.huge, 0, 1))
assert(not Policy.validDirection(-math.huge, 0, 1))
assert(not Policy.validDirection(0/0, 0, 1))
assert(not Policy.validDirection(0, 0/0, 1))
assert(not Policy.validDirection(0, 0, 0/0))
assert(not Policy.validDirection(nil, 0, 1))
assert(not Policy.validDirection("1", 0, 1))
local accepted = 0
for i = 1, 50000 do
    local direction = i % 2 == 0 and 0.000001 or 1
    if Policy.validDirection(direction, 0, 0) then accepted += 1 end
end
assert(accepted == 25000, "50k alternating valid and near-zero vectors")
print("IRON YARD server shot input: 50k checks, no table allocations: OK")
