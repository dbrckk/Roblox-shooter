-- IRON YARD / local cosmetic spent-cartridge policy.
-- No replicated physics, network, hitbox, paid asset or damage impact.
local Policy = {}

local SHELLS = {
    AssaultRifle = { anchor = "EjectionPort", duration = 0.36,
        delay = 0, size = {0.23, 0.09, 0.09}, tint = {194, 153, 75},
        arc = 0.34, spin = 6.5 },
    Pistol = { anchor = "EjectionPort", duration = 0.40,
        delay = 0, size = {0.19, 0.08, 0.08}, tint = {205, 161, 83},
        arc = 0.28, spin = 7.0 },
    Shotgun = { anchor = "ShotgunEjectionPort", duration = 0.47,
        delay = 0.39, size = {0.33, 0.15, 0.15}, tint = {139, 43, 34},
        arc = 0.44, spin = 5.2 },
    Sniper = { anchor = "Bolt", duration = 0.46,
        delay = 0.43, size = {0.35, 0.105, 0.105}, tint = {201, 165, 98},
        arc = 0.40, spin = 5.9 },
}

-- ECO skips optional casings. On balanced Android, every second AR shot
-- ejects one; heavy weapons and all desktop/QUALITY shots remain visible.
-- Deterministic admission avoids Random allocation on every RenderStepped.
function Policy.plan(weaponId, preset, touch, shotNumber)
    if type(shotNumber) ~= "number" or shotNumber ~= shotNumber
        or shotNumber < 1 or shotNumber >= math.huge
        or shotNumber % 1 ~= 0 or preset == "ECO" then return nil end
    local shell = SHELLS[weaponId]
    if not shell then return nil end
    if weaponId == "AssaultRifle" and touch == true
        and preset ~= "QUALITY" and shotNumber % 2 ~= 0 then
        return nil
    end
    return shell
end

function Policy.arc(progress, height)
    if type(progress) ~= "number" or progress ~= progress
        or progress < 0 or progress > 1
        or type(height) ~= "number" or height ~= height
        or height < 0 or height == math.huge then return 0 end
    return 4 * progress * (1 - progress) * height
end

return Policy
