-- IRON YARD / original detachable magazine presentation, client-only.
-- PBR and procedural weapon magazines share the same extraction angle.
-- No server ammunition, camera, physics, or per-frame allocations.
local Pose = {}

local function finite(n)
    return type(n) == "number" and n == n
        and n > -math.huge and n < math.huge
end

-- Returns three displacement scalars and a gentle roll angle in radians.
-- The authoritative reload timeline and smoothed magazineDip are computed
-- by WeaponVisuals. We never introduce an independent animation clock.
function Pose.sample(weaponId, dip, travel, imported, hasMagazine)
    if weaponId ~= "Pistol" and weaponId ~= "AssaultRifle" then
        return 0, 0, 0, 0
    end
    if imported == true and weaponId == "Pistol"
        and hasMagazine ~= true then
        -- Older PBR pistol has a magazine welded into its static mesh.
        return 0, 0, 0, 0
    end
    if not finite(dip) or not finite(travel) or travel < 0 then
        return 0, 0, 0, 0
    end
    local amount = math.clamp(dip, 0, 1) * math.clamp(travel, 0, 2)
    local angle = weaponId == "Pistol" and 0.105 or 0.075
    return 0, -0.36 * amount, 0.04 * amount, angle * amount
end

return Pose
