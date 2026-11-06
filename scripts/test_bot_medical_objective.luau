local P = require("../src/shared/BotMedicalObjective")
local choose = P.choose
local options = {
    {id=1, available=true, distance=22},
    {id=2, available=true, distance=28},
    {id=3, available=false, distance=3},
}
assert(choose(options, 10, nil, 0, nil, 0) == 1, "Nearest available station")
assert(choose(options, 10, 2, 11, nil, 0) == 2, "Stick to active valid objective")
assert(choose(options, 12, 2, 11, nil, 0) == 1, "Commitment expires")
assert(choose(options, 10, 1, 13, 1, 23) == 2, "Failed station excluded")
assert(choose(options, 24, 1, 27, 1, 23) == 1, "Failure cooldown expires")
assert(choose({{id=1,available=true,distance=20,dangerDistance=8},
    {id=2,available=true,distance=44,dangerDistance=60}},
    10, nil, 0, nil, 0) == 2, "Avoid enemy guarding known station")
assert(choose({{id=1,available=true,distance=20,dangerDistance=37},
    {id=2,available=true,distance=37,dangerDistance=80}},
    10, nil, 0, nil, 0) == 2, "Prefer observed safer location")
assert(choose({{id=1,available=true,distance=66}}, 10, nil, 0, nil, 0) == nil)
assert(choose({{id=1,available=false,distance=12}}, 10, nil, 0, nil, 0) == nil)
assert(choose({{id=1,available=true,distance=0/0}}, 10, nil, 0, nil, 0) == nil)
assert(choose({{id=1,available=true,distance=15,dangerDistance=12}}, 10, nil, 0, nil, 0) == nil)
print("IRON YARD medical objective commitment, danger and failure recovery: OK")
