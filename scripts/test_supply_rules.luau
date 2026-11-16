local R = require("../src/shared/SupplyRules")
local can = R.canUse
assert(can("LIVE", 35, 100, 5, 200, 200))
assert(can("LIVE", 1, 100, R.SERVER_RANGE, 200, 200))
assert(not can("RESULTS", 10, 100, 5, 200, 100))
assert(not can("COUNTDOWN", 10, 100, 5, 200, 100))
assert(not can("LIVE", 0, 100, 5, 200, 100))
assert(not can("LIVE", 100, 100, 5, 200, 100))
assert(not can("LIVE", 99, 100, 20, 200, 100))
assert(not can("LIVE", 99, 100, -1, 200, 100))
assert(not can("LIVE", 50, 100, 5, 199, 200))
assert(not can("LIVE", 50, 100, 5, 0 / 0, 0))
assert(not can("LIVE", 50, 100, math.huge, 200, 0))
local hp, healed = R.healedHealth(60, 100)
assert(hp == 100 and healed == 40)
hp, healed = R.healedHealth(93, 100)
assert(hp == 100 and healed == 7)
hp, healed = R.healedHealth(10, 250)
assert(hp == 50 and healed == 40)
print("IRON YARD medical station eligibility and healing: OK")

assert(R.botNeedsHeal(48, 100) and R.botNeedsHeal(10, 100))
assert(not R.botNeedsHeal(49, 100) and not R.botNeedsHeal(0, 100))
assert(not R.botNeedsHeal(100, 100) and not R.botNeedsHeal(100, 0))
assert(not R.botNeedsHeal(0 / 0, 100) and not R.botNeedsHeal(10, math.huge))


for _, phase in ipairs({ "WAITING", "COUNTDOWN", "RESULTS", "DUEL_PREP", "DUEL_BREAK", "LIVE" }) do
    assert(R.stationState("DUEL", phase, 100, 0) == "DUEL_CLOSED")
    if phase ~= "LIVE" then
        assert(R.stationState("FFA", phase, 100, 0) == "STANDBY")
        assert(R.stationState("FFA", phase, 100, 120) == "STANDBY")
    end
end
assert(R.stationState("FFA", nil, 100, 0) == "STANDBY")
assert(R.stationState("FFA", "LIVE", 100, 101) == "RECHARGING")
assert(R.stationState("FFA", "LIVE", 101, 101) == "READY")
assert(R.stationState("FFA", "LIVE", 0 / 0, 0) == "STANDBY")
assert(R.stationState("FFA", "LIVE", 100, math.huge) == "STANDBY")
print("IRON YARD medical readiness follows phase, mode and the cooldown: OK")

local deadline = 100 + R.COOLDOWN
assert(R.rechargeSeconds(100, deadline) == 24)
assert(R.rechargeSeconds(100.99, deadline) == 24)
assert(R.rechargeSeconds(101, deadline) == 23)
assert(R.rechargeSeconds(113.2, deadline) == 11, "A delayed update follows the deadline")
assert(R.rechargeSeconds(123.999, deadline) == 1, "Never show zero before readiness")
assert(R.rechargeSeconds(deadline, deadline) == 0 and R.rechargeSeconds(125, deadline) == 0)
assert(R.rechargeSeconds(50, deadline) == R.COOLDOWN)
assert(R.rechargeSeconds(0 / 0, deadline) == 0 and R.rechargeSeconds(100, math.huge) == 0)
print("IRON YARD medical countdown boundaries: OK")
