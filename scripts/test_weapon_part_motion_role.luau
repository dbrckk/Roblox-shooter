-- Regression: the cached equip-time role must match the original
-- per-frame branches for procedural Parts AND imported PBR material primitives.
local Role = require("../src/shared/WeaponPartMotionRole")

local names = {
    "LeftForearm", "LeftGlove", "LeftSleeveHem", "LeftWristStrap",
    "RightForearm", "RightGlove", "RightKnucklePanel",
    "LoadingShellBody", "LoadingShellBrass", "Magazine", "MagazineBase",
    "ChargingHandle", "Slide", "EjectionPort", "Extractor",
    "SlideDetailRear1L", "SlideDetailFront2R", "SlideDetailChamberIndicator",
    "PumpAction", "PumpGrooveA", "PumpGrooveB",
    "Bolt", "BoltHandle", "BoltHandleKnob",
    "Muzzle", "MuzzleBrake", "MuzzleRing", "SniperEjectionPort",
    "ScopeRingFront", "Stock", "RailTooth3", "ARMagazineFollower",
    "IRONYARD_WeaponOrigin", "Receiver",
}
local ids = {"AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife"}

local function legacy(weapon, name)
    if string.sub(name, 1, 4) == "Left" then return Role.LEFT_HAND end
    if string.sub(name, 1, 5) == "Right" and weapon == "Sniper" then
        return Role.SNIPER_RIGHT_HAND
    end
    if (name == "LoadingShellBody" or name == "LoadingShellBrass")
        and weapon == "Shotgun" then return Role.SHOTGUN_LOADING_SHELL end
    if (name == "Magazine" or name == "MagazineBase")
        and weapon ~= "Shotgun" then return Role.MAGAZINE end
    if name == "ChargingHandle" and weapon == "AssaultRifle" then
        return Role.RIFLE_CHARGING_HANDLE
    end
    if (name == "Slide" or name == "EjectionPort" or name == "Extractor"
        or string.sub(name, 1, 11) == "SlideDetail")
        and weapon == "Pistol" then return Role.PISTOL_SLIDE end
    if (name == "PumpAction" or name == "PumpGrooveA" or name == "PumpGrooveB")
        and weapon == "Shotgun" then return Role.SHOTGUN_PUMP end
    if (name == "Bolt" or name == "BoltHandle" or name == "BoltHandleKnob")
        and weapon == "Sniper" then return Role.SNIPER_BOLT end
    return Role.STATIC
end

local mechanical = 0
for _, weapon in ipairs(ids) do
    for _, name in ipairs(names) do
        local actual = Role.classify(weapon, name)
        local expected = legacy(weapon, name)
        assert(actual == expected, weapon .. "/" .. name .. ": cached role diverged")
        if actual ~= Role.STATIC then mechanical += 1 end
    end
    -- Stress long sessions with lots of stable non-mechanical PBR primitive
    -- names. They must never become gloved hands or an animated bolt.
    for i = 1, 250 do
        assert(Role.classify(weapon, "PBRMaterialPrimitive" .. i) == Role.STATIC)
    end
end
assert(mechanical > 20, "Fixture must cover moving components")
assert(Role.classify("Sniper", "LeftMissing") == Role.LEFT_HAND)
assert(Role.classify("Pistol", "RightGlove") == Role.STATIC)
assert(Role.classify("Sniper", "RightGlove") == Role.SNIPER_RIGHT_HAND)
assert(Role.classify("Shotgun", "EjectionPort") == Role.STATIC)
assert(Role.classify("AssaultRifle", "Magazine") == Role.MAGAZINE)
assert(Role.classify("Shotgun", "Magazine") == Role.STATIC)
assert(Role.classify("Pistol", nil) == Role.STATIC)
assert(Role.classify("Pistol", 123) == Role.STATIC)
assert(Role.classify(nil, "ChargingHandle") == Role.STATIC)
print("IRON YARD: all procedural/PBR weapon roles cached with exact legacy motion: OK")
