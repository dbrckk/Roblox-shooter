-- IRON YARD / offline support-hand reload choreography and cancellation.
local Hand = require("../src/shared/WeaponReloadHandPlan")
local Reload = require("../src/shared/ShotgunReloadVisual")

local function sample(id, progress, dip, preset)
    return Hand.sample(id, progress, true, dip, 1.0, preset or "QUALITY")
end
local ax, ay, az = sample("AssaultRifle", 0.45, 1)
assert(ax > 0.2 and ay < -0.4 and az > 1.0,
    "AR glove must reach down to the extracted independent PBR magazine")
local px, py, pz = sample("AssaultRifle", 0, 0)
assert(px == 0 and py == 0 and pz == 0)
local ex, ey, ez = sample("AssaultRifle", 1, 0)
assert(ex == 0 and ey == 0 and ez == 0,
    "Support grip returns to handguard at reload completion")

local sx, sy, sz = sample("Shotgun", 0.38, 0)
local shellX = Reload.sample(0.38, true, "QUALITY")
assert(shellX ~= nil and sx > 0 and sy > 0 and sz > 0.7,
    "B-8 glove must reach the visible loading shell, not the pump")
local lx, ly, lz = sample("Shotgun", 0.70, 0)
assert(lx > sx and lz < sz,
    "Shotgun glove follows the shell as it seats into the loading port")
local hx, hy, hz = sample("Shotgun", 0.5, 0, "ECO")
local qx, qy, qz = sample("Shotgun", 0.5, 0, "QUALITY")
assert(hx > 0 and hx < qx and hy < qy and hz < qz,
    "ECO has no visible shell: avoid full unsupported reach")
local rx, ry, rz = sample("Shotgun", 1, 0)
assert(rx == 0 and ry == 0 and rz == 0)

for _, id in ipairs({"AssaultRifle", "Shotgun", "Sniper", "Pistol", "Knife"}) do
    local x, y, z = Hand.sample(id, 0.50, false, 1, 1, "QUALITY")
    assert(x == 0 and y == 0 and z == 0,
        "Canceled reload must request neutral pose, smoothed by renderer")
    for i = 0, 100 do
        local a, b, c = sample(id, i / 100, 0.8)
        assert(math.abs(a) <= 0.5 and math.abs(b) <= 0.7
            and math.abs(c) <= 1.3, "No extreme or off-screen hand pose")
    end
end
for _, invalid in ipairs({0/0, math.huge, -math.huge, "bad", -1/0}) do
    local x, y, z = Hand.sample("Shotgun", invalid, true, 0, 1, "QUALITY")
    assert(x == 0 and y == 0 and z == 0)
    x, y, z = Hand.sample("Shotgun", 0.5, true, invalid, 1, "QUALITY")
    assert(x == 0 and y == 0 and z == 0)
    x, y, z = Hand.sample("Shotgun", 0.5, true, 0, invalid, "QUALITY")
    assert(x == 0 and y == 0 and z == 0)
end
assert(select(1, Hand.sample("Shotgun", 0.5, true, 0, nil, "QUALITY")) == 0)
print("IRON YARD: PBR/fallback AR magazine and B-8 shell support hands: OK")

// Confirmed pistol reload only; no floating left hand while idle or after cancel.
assert(Hand.pistolVisibility(0.0, true) == 0)
assert(Hand.pistolVisibility(0.40, true) == 1)
assert(Hand.pistolVisibility(1.0, true) == 0)
assert(Hand.pistolVisibility(0.40, false) == 0)
assert(Hand.pistolVisibility(0/0, true) == 0)
assert(Hand.pistolVisibility(math.huge, true) == 0)
local fx, fy, fz = Hand.sample("Pistol", 0.45, true, 1, 1.15, "QUALITY", false)
local ix, iy, iz = Hand.sample("Pistol", 0.45, true, 1, 1.15, "QUALITY", true)
assert(fx > ix and fy < iy and fz ~= iz,
    "Procedural hand follows moving magazine; PBR retains fixed magazine")
assert(fy < -0.3 and iy > -0.15)
assert(select(1, Hand.sample("Pistol", 0.45, false, 1, 1, "QUALITY", true)) == 0)

// Right hand follows the actual timed bolt mechanism, except during ADS
// and a server-confirmed reload. All values remain bounded and finite.
local bx, by, bz = Hand.boltGrip("Sniper", 1, false, false)
assert(bx > 0.25 and by > 0.35 and bz < -0.2)
local hx, hy, hz = Hand.boltGrip("Sniper", 0.5, false, false)
assert(hx > 0 and hx < bx and hy < by and hz > bz)
for _, args in ipairs({
    {"Sniper", 0, false, false},
    {"Sniper", 1, true, false},
    {"Sniper", 1, false, true},
    {"Pistol", 1, false, false},
    {"Sniper", math.huge, false, false},
    {"Sniper", 0/0, false, false},
}) do
    local x, y, z = Hand.boltGrip(args[1], args[2], args[3], args[4])
    assert(x == 0 and y == 0 and z == 0)
end
print("IRON YARD: scoped-safe sniper bolt and PBR/fallback pistol gestures: OK")
