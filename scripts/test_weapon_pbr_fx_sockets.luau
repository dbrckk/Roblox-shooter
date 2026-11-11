-- IRON YARD / source-backed muzzle and cartridge sockets for uploaded PBR guns.
local Sockets = require("../src/shared/WeaponPbrFxSockets")

local authored = {
    Pistol = {Muzzle = {0, 0.13, -1.048}, EjectionPort = {0.19, 0.342, -0.09}},
    AssaultRifle = {FlashHider = {0, 0.06, -2.42}, EjectionPort = {0.223, 0.13, -0.08}},
    Shotgun = {MuzzleRing = {0, 0.19, -2.39}, ShotgunEjectionPort = {0.274, 0.08, -0.18}},
    Sniper = {MuzzleBrake = {0, -0.005, -3.12}, SniperEjectionPort = {0.20, 0.07, -0.13}},
}
for weaponId, names in pairs(authored) do
    for name, expected in pairs(names) do
        local x, y, z = Sockets.get(weaponId, name)
        assert(x and y and z, "Missing " .. weaponId .. " " .. name)
        assert(math.abs(x - expected[1]) < 1e-7
            and math.abs(y - expected[2]) < 1e-7
            and math.abs(z - expected[3]) < 1e-7,
            "Socket must follow authored Blender geometry")
        assert(math.abs(x) <= 4 and math.abs(y) <= 4 and math.abs(z) <= 4,
            "No imported FX socket may appear outside weapon bounds")
    end
end

-- Only the real selected PBR path may use these sockets. No phantom
-- casing from knives, unknown weapons, or a misspelled mechanical part.
for _, weaponId in ipairs({"Knife", "Unknown", "", "Pistol"}) do
    assert(Sockets.get(weaponId, "InvalidAnchor") == nil)
end
assert(Sockets.get("Knife", "Muzzle") == nil)
assert(Sockets.get("Unknown", "Muzzle") == nil)
assert(Sockets.get("Sniper", "Bolt") == nil,
    "Do not spawn spent sniper shells from the glTF model origin")
assert(Sockets.get(nil, "Muzzle") == nil)
assert(Sockets.get("Pistol", nil) == nil)
assert(Sockets.get({}, "Muzzle") == nil)

assert(Sockets.muzzleAdvance(true) == 0.10)
assert(Sockets.muzzleAdvance(false) == 0.25)
assert(Sockets.muzzleAdvance(nil) == 0.25)
assert(Sockets.muzzleAdvance("true") == 0.25)
assert(Sockets.muzzleAdvance(1) == 0.25)

print("IRON YARD: source-authored PBR muzzle/ejection sockets and fallback offsets OK")
