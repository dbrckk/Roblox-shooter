-- IRON YARD / first-person FX sockets for the ORIGINAL owner-approved GLBs.
-- Weaponforge creates meshes with Blender +Y forward and +Z up.
-- Exported Roblox-facing local positions use (X, Z, -Y).
-- Source: tools/weaponforge/build_weapons.py and long_guns.py.
-- No allocations or network calls per shot; evaluated only when equipping.
local Sockets = {}

local PBR = {
    Pistol = {
        -- Recessed bore (0, 1.048, 0.13), ejection/chamber on the slide.
        Muzzle = {0, 0.13, -1.048},
        EjectionPort = {0.19, 0.342, -0.09},
    },
    AssaultRifle = {
        -- Compensator (0, 2.42, 0.06); receiver port (.223, .08, .13).
        FlashHider = {0, 0.06, -2.42},
        EjectionPort = {0.223, 0.13, -0.08},
    },
    Shotgun = {
        -- Muzzle crown (0, 2.39, .19); ejection gate (.274, .18, .08).
        MuzzleRing = {0, 0.19, -2.39},
        ShotgunEjectionPort = {0.274, 0.08, -0.18},
    },
    Sniper = {
        -- Muzzle brake (0, 3.12, -.005); bolt (.20, .13, .07).
        MuzzleBrake = {0, -0.005, -3.12},
        SniperEjectionPort = {0.20, 0.07, -0.13},
    },
}

function Sockets.get(weaponId, socketName)
    if type(weaponId) ~= "string" or type(socketName) ~= "string" then
        return nil
    end
    local weapon = PBR[weaponId]
    local pos = weapon and weapon[socketName]
    if not pos then return nil end
    return pos[1], pos[2], pos[3]
end

-- The PBR anchors are already at the physical muzzle; procedural Parts use
-- their historical offset. Do not advance PBR muzzle flashes 25 cm ahead.
function Sockets.muzzleAdvance(isImported)
    return isImported == true and 0.10 or 0.25
end

return Sockets
