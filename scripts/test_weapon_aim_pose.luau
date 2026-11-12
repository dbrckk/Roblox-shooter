-- Pure Luau test of original iron-sight positions.
local Pose = require("../src/shared/WeaponAimPose")
local Config = require("../src/shared/WeaponConfig")
local positions = {
    AssaultRifle = {0, 0.32, -0.05, 1.28},
    Pistol = {0, 0.30, 0.10, 1.00},
    Shotgun = {0, 0.24, -0.28, 1.34},
}
for id, expected in pairs(positions) do
    local profile = Pose.get(id)
    assert(profile and Config.get(id).aimFov)
    assert(profile.sightX == expected[1] and profile.sightY == expected[2])
    assert(profile.sightZ == expected[3] and profile.eyeRelief == expected[4])
    assert(math.abs(profile.x + profile.sightX) < 1e-7)
    assert(math.abs(profile.y + profile.sightY) < 1e-7)
    assert(math.abs(profile.z + profile.sightZ + profile.eyeRelief) < 1e-7)
end
assert(Pose.get("Sniper") == nil, "Sniper uses optical overlay")
assert(Pose.get("Knife") == nil and Pose.get("Unknown") == nil)
local s, b = Pose.damping(0)
assert(s == 1 and b == 1)
s, b = Pose.damping(1)
assert(math.abs(s - 0.35) < 1e-6 and math.abs(b - 0.22) < 1e-6)
for i = -50, 150 do
    local sway, bob = Pose.damping(i / 100)
    assert(sway >= 0.35 - 1e-10 and sway <= 1 + 1e-10
        and bob >= 0.22 - 1e-10 and bob <= 1 + 1e-10,
        "Damping stays in valid range within floating-point precision")
end
assert(select(1, Pose.damping(0/0)) == 1)
assert(select(2, Pose.damping(math.huge)) == 1)
-- The real weaponforge rear sights differ from the procedural Part sights.
-- Camera-space ADS must center the authored optic independently of LOD.
local importedSights = {
    AssaultRifle = {0, 0.36, 0.40, 1.28},
    Pistol = {0, 0.35, 0.30, 1.00},
    Shotgun = {0, 0.33, 0.31, 1.34},
}
for id, expected in pairs(importedSights) do
    local pbr = Pose.get(id, true)
    local fallback = Pose.get(id, false)
    assert(pbr and fallback and pbr ~= fallback,
        "PBR and primitive weapons require distinct sight alignment")
    assert(pbr.sightX == expected[1] and pbr.sightY == expected[2]
        and pbr.sightZ == expected[3] and pbr.eyeRelief == expected[4])
    assert(math.abs(pbr.sightX + pbr.x) < 1e-7)
    local cosine, sine = math.cos(pbr.pitch), math.sin(pbr.pitch)
    assert(math.abs(pbr.y + cosine * pbr.sightY - sine * pbr.sightZ) < 1e-7)
    assert(math.abs(pbr.z + sine * pbr.sightY + cosine * pbr.sightZ
        + pbr.eyeRelief) < 1e-7)
    assert(Pose.get(id) == fallback,
        "Old fallback ADS must remain fully compatible")
    assert(Pose.get(id, "true") == fallback,
        "Only a validated true imported flag selects the new alignment")
end
assert(Pose.get("Sniper", true) == nil, "Sniper uses optical scope")
assert(Pose.get("Knife", true) == nil, "Knife has no ADS profile")
print("IRON YARD: fallback/PBR sight alignment and ADS damping verified")

-- The authored FRONT and REAR PBR sights are distinct Blender objects:
-- a rear-only translation would leave the front above the reticle.
-- Check both points on the camera's (0, 0, -Z) optical axis, without
-- instantiating Roblox CFrame in an offline Luau test runner.
local sightEnds = {
    AssaultRifle = { frontY = 0.42, frontZ = -1.57 },
    Pistol = { frontY = 0.36, frontZ = -0.50 },
    Shotgun = { frontY = 0.36, frontZ = -2.20 },
}
for id, front in pairs(sightEnds) do
    local p = Pose.get(id, true)
    local c, s = math.cos(p.pitch), math.sin(p.pitch)
    local rearY = p.y + c * p.sightY - s * p.sightZ
    local rearZ = p.z + s * p.sightY + c * p.sightZ
    local frontY = p.y + c * front.frontY - s * front.frontZ
    local frontZ = p.z + s * front.frontY + c * front.frontZ
    assert(p.frontY == front.frontY and p.frontZ == front.frontZ)
    assert(p.x == 0 and math.abs(rearY) < 1e-9)
    assert(math.abs(frontY) < 1e-9,
        "Both PBR sight centers must align vertically with the camera")
    assert(math.abs(rearZ + p.eyeRelief) < 1e-9)
    assert(frontZ < rearZ and p.pitch < 0 and p.pitch > -0.05,
        "Front sight must point forward with restrained model-only pitch")
    local fallback = Pose.get(id, false)
    assert(fallback.pitch == 0 and fallback.frontY == nil,
        "Procedural fallback ADS must remain completely untouched")
end
print("IRON YARD authored front/rear PBR iron sights: centered axis and unchanged fallback OK")
