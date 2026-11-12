-- A client-only slide/handle rack is allowed only after real server refill.
local R = require("../src/shared/WeaponReloadFinishPolicy")
assert(R.confirmed("Pistol", true, false, 0, 15, 15))
assert(R.confirmed("AssaultRifle", true, false, 7, 30, 30))
assert(not R.confirmed("Shotgun", true, false, 0, 8, 8))
assert(not R.confirmed("Sniper", true, false, 0, 5, 5))
assert(not R.confirmed("Pistol", true, false, 15, 15, 15))
assert(not R.confirmed("Pistol", true, false, 7, 7, 15))
assert(not R.confirmed("Pistol", false, false, 0, 15, 15))
assert(not R.confirmed("Pistol", true, true, 0, 15, 15))
assert(not R.confirmed("Pistol", true, false, nil, 15, 15))
assert(not R.confirmed("Pistol", true, false, 0, nil, 15))
assert(not R.confirmed("Pistol", true, false, 0, 16, 15))
assert(not R.confirmed("Pistol", true, false, -1, 15, 15))
assert(not R.confirmed("Pistol", true, false, 0, 3.5, 15))
assert(not R.confirmed("Pistol", true, false, 0, 15, 15.5))
for _, v in ipairs({0/0, math.huge, -math.huge, "bad"}) do
    assert(not R.confirmed("Pistol", true, false, v, 15, 15))
    assert(not R.confirmed("Pistol", true, false, 0, v, 15))
    assert(not R.confirmed("Pistol", true, false, 0, 15, v))
    assert(R.sample("Pistol", v, false) == 0)
end
assert(R.sample("Pistol", -1, false) == 0)
assert(R.sample("Pistol", 0, false) == 0)
assert(R.sample("Pistol", 0.11, false) > 0.5)
assert(R.sample("Pistol", 0.16, false) > 0.98)
assert(R.sample("Pistol", 0.24, false) > 0.3)
assert(R.sample("Pistol", R.DURATION, false) == 0)
assert(R.sample("Pistol", 0.16, true) == 0)
assert(R.sample("AssaultRifle", 0.16, false) > 0.98)
for _, id in ipairs({"Sniper", "Shotgun", "Knife", "Unknown"}) do
    assert(R.sample(id, 0.16, false) == 0)
end
local prev=0
for i=0,320 do
    local v=R.sample("Pistol", i/1000, false)
    assert(v>=0 and v<=1 and math.abs(v-prev)<0.035)
    prev=v
end
print("IRON YARD server-confirmed AR and pistol rack (320ms), cancel and invalid snapshots OK")
