-- IRON YARD: first-person optic-axis alignment only, never hit authority.
local Pose = {}
local PROFILES = {
    AssaultRifle = { sightX = 0, sightY = 0.32, sightZ = -0.05, eyeRelief = 1.28 },
    Pistol = { sightX = 0, sightY = 0.30, sightZ = 0.10, eyeRelief = 1.00 },
    Shotgun = { sightX = 0, sightY = 0.24, sightZ = -0.28, eyeRelief = 1.34 },
}
-- Precompute a transform that puts the rear iron sight onto the camera axis.
for _, p in pairs(PROFILES) do
    p.x, p.y, p.z = -p.sightX, -p.sightY, -p.eyeRelief - p.sightZ
end

function Pose.get(id)
    return PROFILES[id]
end

function Pose.damping(blend)
    if type(blend) ~= "number" or blend ~= blend
        or math.abs(blend) == math.huge then return 1, 1 end
    local t = math.clamp(blend, 0, 1)
    return 1 - 0.65 * t, 1 - 0.78 * t
end
return Pose
