-- IRON YARD / offline correctness of server-owned shot FX audience.
local Audience = require("../src/shared/CombatFxAudience")
local p = function(x, y, z) return { X = x, Y = y, Z = z } end
local origin = p(0, 10, 0)
assert(Audience.MAX_DISTANCE == 256)
assert(Audience.MAX_DISTANCE_SQUARED == 65536)
assert(Audience.wants(origin, p(0, 10, 0), false, true))
assert(Audience.wants(origin, p(256, 10, 0), false, true),
    "Boundary is included to avoid audio pop")
assert(not Audience.wants(origin, p(256.1, 10, 0), false, true))
assert(not Audience.wants(origin, p(0, 10, -500), false, true))
assert(not Audience.wants(origin, p(0, 300, 0), false, true),
    "Filtering uses full 3D distance, not a horizontal-only shortcut")
assert(Audience.wants(origin, p(9999, 10, 0), true, true),
    "The firing client must retain their authoritative pellet impacts")
assert(Audience.wants(origin, p(9999, 10, 0), false, false),
    "Spectators/dead clients may have detached cameras")
assert(Audience.wants(origin, nil, false, true),
    "Respawn races must not make a player permanently miss effects")
assert(Audience.wants(nil, p(900, 0, 0), false, true),
    "Bad server origin must fail open instead of hiding an event")
assert(Audience.wants(origin, p(math.huge, 0, 0), false, true))
assert(Audience.wants(origin, p(0/0, 0, 0), false, true))
assert(Audience.wants(origin, p(9999, 10, 0), false, nil),
    "Unknown character health must fail open")
assert(Audience.deliveryMode(0, 10) == "NONE")
assert(Audience.deliveryMode(10, 10) == "ALL")
assert(Audience.deliveryMode(5, 10) == "SOME")
assert(Audience.deliveryMode(0, 0) == "NONE")
assert(Audience.deliveryMode(11, 10) == "NONE")
assert(Audience.deliveryMode(-1, 10) == "NONE")
assert(Audience.deliveryMode(3.5, 10) == "NONE")
assert(Audience.deliveryMode(1, math.huge) == "NONE" or
    Audience.deliveryMode(1, math.huge) == "SOME")

-- 1000 shots in a lobby: 4 players near the action and 46 active remote.
-- Count the recipients, not invented/assumed bandwidth savings.
local totalBroadcast = 0
local filteredDeliveries = 0
local playerPositions = {}
for i = 1, 50 do
    playerPositions[i] = p(i <= 4 and i * 10 or 500 + i, 10, 0)
end
for shot = 1, 1000 do
    for i = 1, 50 do
        totalBroadcast += 1
        if Audience.wants(origin, playerPositions[i], i == 1, true) then
            filteredDeliveries += 1
        end
    end
end
assert(totalBroadcast == 50000 and filteredDeliveries == 4000)
assert(filteredDeliveries < totalBroadcast,
    "Distant active players must no longer receive every gunshot packet")

-- If all players are near, the router should keep one broadcast rather
-- than call FireClient many times (deliveryMode = ALL).
for _, n in ipairs({1, 2, 8, 50}) do
    assert(Audience.deliveryMode(n, n) == "ALL")
end
print("IRON YARD shot FX audience: 50k candidate recipients, conservative 256-stud cull: OK")
