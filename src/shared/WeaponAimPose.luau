-- IRON YARD: camera-only ADS alignment for procedural and original PBR guns.
-- These transforms never change server aim direction, damage or hitboxes.
local Pose = {}

-- Legacy first-person Part geometry. Do not shift the playable fallback when
-- an imported owner-approved mesh is unavailable on a device/server.
local PROFILES = {
    AssaultRifle = { sightX = 0, sightY = 0.32, sightZ = -0.05, eyeRelief = 1.28 },
    Pistol = { sightX = 0, sightY = 0.30, sightZ = 0.10, eyeRelief = 1.00 },
    Shotgun = { sightX = 0, sightY = 0.24, sightZ = -0.28, eyeRelief = 1.34 },
}

-- Blender weaponforge authored REAR and FRONT sight centers. The Y-up glTF
-- export maps Blender Z to Roblox Y, and Blender -Y to Roblox Z. Correcting
-- only the rear position does not align the two sights: an elevation delta
-- of 1–6 cm would float above the camera axis. Keep the existing eye relief,
-- correct a small model-only X pitch, and anchor the rotated rear at (0,0).
-- Independent sources: tools/weaponforge/build_weapons.py / long_guns.py.
-- In-engine Android/Studio visual QA is still required after this calculation.
local IMPORTED_PROFILES = {
    AssaultRifle = {
        sightX = 0, sightY = 0.36, sightZ = 0.40,
        frontY = 0.42, frontZ = -1.57, eyeRelief = 1.28,
    },
    Pistol = {
        sightX = 0, sightY = 0.35, sightZ = 0.30,
        frontY = 0.36, frontZ = -0.50, eyeRelief = 1.00,
    },
    Shotgun = {
        sightX = 0, sightY = 0.33, sightZ = 0.31,
        frontY = 0.36, frontZ = -2.20, eyeRelief = 1.34,
    },
}

-- Compute these once on module load: no trigonometry on RenderStepped.
for _, p in pairs(PROFILES) do
    p.x, p.y, p.z = -p.sightX, -p.sightY, -p.eyeRelief - p.sightZ
    p.pitch = 0
end
for _, p in pairs(IMPORTED_PROFILES) do
    local heightDelta = p.frontY - p.sightY
    local forwardDistance = p.sightZ - p.frontZ
    p.pitch = -math.atan2(heightDelta, forwardDistance)
    local c, s = math.cos(p.pitch), math.sin(p.pitch)
    p.x = -p.sightX
    p.y = -(c * p.sightY - s * p.sightZ)
    p.z = -p.eyeRelief - (s * p.sightY + c * p.sightZ)
end

-- The caller uses the actual viewmodel source selected on equip or LOD swap.
function Pose.get(id, imported)
    if imported == true then
        return IMPORTED_PROFILES[id] or PROFILES[id]
    end
    return PROFILES[id]
end

function Pose.damping(blend)
    if type(blend) ~= "number" or blend ~= blend
        or math.abs(blend) == math.huge then return 1, 1 end
    local t = math.clamp(blend, 0, 1)
    return 1 - 0.65 * t, 1 - 0.78 * t
end
return Pose
