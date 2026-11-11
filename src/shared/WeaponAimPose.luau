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

-- The imported Blender weaponforge does NOT reuse the Part sights.
-- Authored rear-sight centers in Blender (x, forward Y, height Z):
-- AR: (0,-0.40,0.36), pistol: (0,-0.30,0.35),
-- B-8: (0,-0.31,0.33). glTF's Y-up export maps Blender -Y to Roblox +Z.
-- Keep eye-relief values from the existing weapon profiles to avoid a sudden
-- field-of-view shift. These authored estimates still need in-engine QA.
local IMPORTED_PROFILES = {
    AssaultRifle = { sightX = 0, sightY = 0.36, sightZ = 0.40, eyeRelief = 1.28 },
    Pistol = { sightX = 0, sightY = 0.35, sightZ = 0.30, eyeRelief = 1.00 },
    Shotgun = { sightX = 0, sightY = 0.33, sightZ = 0.31, eyeRelief = 1.34 },
}

-- Precompute transforms at module load, not every RenderStepped.
for _, profiles in ipairs({PROFILES, IMPORTED_PROFILES}) do
    for _, p in pairs(profiles) do
        p.x, p.y, p.z = -p.sightX, -p.sightY, -p.eyeRelief - p.sightZ
    end
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
