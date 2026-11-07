local H = require("../src/shared/BotHearingPlan")
assert(H.radius("Shotgun") > H.radius("Pistol"), "Shotgun must be easier to hear")
assert(H.radius("Sniper") > H.radius("AssaultRifle"), "Sniper report carries further")
assert(H.radius("Knife") < H.radius("Pistol"), "Knife must not sound like gunfire")
assert(H.radius("Unknown") == nil, "Unrecognized sounds are ignored")
local entries = {
    {id=1, own=false, distance=55, age=4, radius=110},
    {id=2, own=false, distance=65, age=0.2, radius=110},
    {id=3, own=true, distance=12, age=0, radius=110},
}
assert(H.choose(entries, 10) == 2, "Investigate recent audible shots")
assert(H.choose({{id=1,own=true,distance=30,age=0,radius=155}}, 10) == nil,
    "Bots cannot investigate their own shots")
assert(H.choose({{id=1,distance=80,age=1,radius=65}}, 10) == nil,
    "Outside actual weapon hearing range")
assert(H.choose({{id=1,distance=50,age=6,radius=155}}, 10) == nil,
    "Old shots must expire")
assert(H.choose({{id=1,distance=4,age=0.1,radius=155}}, 10) == nil,
    "Arrival must not freeze the bot on the noise location")
assert(H.choose({{id=1,distance=0/0,age=0,radius=155}}, 10) == nil)
assert(H.choose({{id=1,distance=10,age=-1,radius=155}}, 10) == nil)
assert(H.choose({{id=1,distance=10,age=0,radius=math.huge}}, 10) == nil)
assert(H.approximateAxis(16.1, 1, "X") ~= 16.1, "Only a coarse area is provided")
assert(H.approximateAxis(20, 2, "Z") ~= H.approximateAxis(20, 2, "X"),
    "Different spatial axes cannot always produce the same exact target")
assert(H.approximateAxis(999, 1, "X") <= 153, "Stay inside known arena envelope")
assert(H.approximateAxis(0/0, 1, "X") == nil)
assert(H.choose({{id=5, distance=33, age=1, radius=125}}, 4, 5) == nil,
    "Already investigated sound cannot start again")
assert(H.choose({{id=6, distance=33, age=1, radius=125}}, 4, 5) == 6,
    "New accepted shot can trigger a later investigation")
print("IRON YARD server-accepted gunshot hearing and bounded audible investigations: OK")
