-- IRON YARD / zero-allocation, client-only support-hand choreography.
-- Shared by approved Blender PBR meshes and playable procedural fallback.
-- All displacements are relative to the existing left-arm visual rig.
-- NEVER changes weapon reload state, damage, camera, or server ammunition.
local Plan = {}

local function finite(v)
    return type(v) == "number" and v == v
        and v > -math.huge and v < math.huge
end

local function smooth(a, b, v)
    local t = math.clamp((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
end

-- Returns three scalars to avoid allocating a Vector3/table per frame.
-- progress follows the server-confirmed reloadSeconds (0..1);
-- dip is the SAME mid-reload magazine extraction curve used by the mesh.
function Plan.sample(weaponId, progress, active, dip, handTravel, preset)
    if active ~= true or not finite(progress) or not finite(dip)
        or not finite(handTravel) or handTravel < 0 then
        return 0, 0, 0
    end
    local p = math.clamp(progress, 0, 1)
    local mag = math.clamp(dip, 0, 1)
    if weaponId == "AssaultRifle" then
        -- Handguard -> magazine well -> extracted magazine -> fore-end.
        -- Weaponforge's magazine is an independently animated PBR component.
        local reach = smooth(0.08, 0.32, p) * (1 - smooth(0.73, 0.93, p))
        return 0.26 * reach,
            -0.14 * reach - 0.32 * mag,
            1.10 * reach + 0.04 * mag
    elseif weaponId == "Shotgun" then
        -- The B-8's physical loading shell travels +X and -Z toward the
        -- receiver from progress 0.27 to 0.74 (ShotgunReloadVisual).
        -- ECO hides the shell, so keep only a restrained manipulation.
        local reach = smooth(0.12, 0.35, p) * (1 - smooth(0.72, 0.94, p))
        local seated = smooth(0.27, 0.74, p)
        local intensity = preset == "ECO" and 0.32 or 1
        return (0.06 + 0.22 * seated) * reach * intensity,
            (0.06 + 0.04 * math.sin(math.pi * seated)) * reach * intensity,
            (1.16 - 0.26 * seated) * reach * intensity
    elseif weaponId == "Sniper" then
        -- Sniper keeps its left hand on the fore-end; only a modest grip
        -- adjustment accompanies the existing server-confirmed reload pose.
        return 0.13 * mag * handTravel,
            -0.22 * mag * handTravel,
            -0.11 * mag * handTravel
    end
    return 0, 0, 0
end

return Plan
