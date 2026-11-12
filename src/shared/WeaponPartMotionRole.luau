-- IRON YARD / deterministic weapon part animation roles, resolved at equip.
-- A PBR gun can contain dozens of material primitives. Never inspect its
-- instance Name or run string.sub repeatedly inside RenderStepped.
-- Roles are cosmetic only: they do not affect shots, camera, or hitboxes.
local Role = {}

Role.STATIC = 0
Role.LEFT_HAND = 1
Role.SNIPER_RIGHT_HAND = 2
Role.SHOTGUN_LOADING_SHELL = 3
Role.MAGAZINE = 4
Role.RIFLE_CHARGING_HANDLE = 5
Role.PISTOL_SLIDE = 6
Role.SHOTGUN_PUMP = 7
Role.SNIPER_BOLT = 8

function Role.classify(weaponId, name)
    if type(name) ~= "string" then return Role.STATIC end
    -- This precedence matches the old per-frame model dispatcher exactly.
    if string.sub(name, 1, 4) == "Left" then
        return Role.LEFT_HAND
    end
    if weaponId == "Sniper" and string.sub(name, 1, 5) == "Right" then
        return Role.SNIPER_RIGHT_HAND
    end
    if weaponId == "Shotgun"
        and (name == "LoadingShellBody" or name == "LoadingShellBrass") then
        return Role.SHOTGUN_LOADING_SHELL
    end
    if weaponId ~= "Shotgun" and (name == "Magazine" or name == "MagazineBase") then
        return Role.MAGAZINE
    end
    if weaponId == "AssaultRifle" and name == "ChargingHandle" then
        return Role.RIFLE_CHARGING_HANDLE
    end
    if weaponId == "Pistol"
        and (name == "Slide" or name == "EjectionPort" or name == "Extractor"
            or string.sub(name, 1, 11) == "SlideDetail") then
        return Role.PISTOL_SLIDE
    end
    if weaponId == "Shotgun"
        and (name == "PumpAction" or name == "PumpGrooveA" or name == "PumpGrooveB") then
        return Role.SHOTGUN_PUMP
    end
    if weaponId == "Sniper"
        and (name == "Bolt" or name == "BoltHandle" or name == "BoltHandleKnob") then
        return Role.SNIPER_BOLT
    end
    return Role.STATIC
end

return Role
