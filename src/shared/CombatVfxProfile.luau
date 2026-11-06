-- IRON YARD / deterministic local-only combat VFX budget and surface identity.
-- No Roblox instances or services: used by the client and executable in Luau CI.
local Profile = {}

local MATERIALS = {
    Metal = "METAL", DiamondPlate = "METAL", CorrodedMetal = "METAL",
    Foil = "METAL",
    Wood = "WOOD", WoodPlanks = "WOOD",
    Glass = "GLASS",
    Grass = "EARTH", Ground = "EARTH", Sand = "EARTH",
    Mud = "EARTH", Snow = "EARTH", LeafyGrass = "EARTH",
    Slate = "STONE", Concrete = "STONE", Rock = "STONE",
    Cobblestone = "STONE", Brick = "STONE", Granite = "STONE",
    Marble = "STONE", Basalt = "STONE", Asphalt = "STONE",
}

local SURFACES = {
    METAL = { debris = { 246, 188, 103 }, mark = { 36, 30, 25 },
        sparks = true, glimmer = true, spread = 0.85 },
    WOOD = { debris = { 187, 147, 98 }, mark = { 49, 37, 28 },
        sparks = false, glimmer = false, spread = 0.54 },
    GLASS = { debris = { 184, 213, 216 }, mark = { 89, 108, 113 },
        sparks = false, glimmer = true, spread = 0.65 },
    EARTH = { debris = { 148, 134, 108 }, mark = { 66, 62, 52 },
        sparks = false, glimmer = false, spread = 0.40 },
    STONE = { debris = { 182, 181, 169 }, mark = { 55, 54, 51 },
        sparks = false, glimmer = false, spread = 0.48 },
}

local ECO = { maxDistance = 70, cooldown = 0.16, fragments = 1,
    marks = 10, markSeconds = 3.4, muzzleFins = 0, muzzleLight = false }
local MOBILE = { maxDistance = 115, cooldown = 0.10, fragments = 2,
    marks = 16, markSeconds = 4.5, muzzleFins = 1, muzzleLight = false }
local MOBILE_QUALITY = { maxDistance = 145, cooldown = 0.075, fragments = 3,
    marks = 22, markSeconds = 5.6, muzzleFins = 2, muzzleLight = false }
local DESKTOP = { maxDistance = 160, cooldown = 0.06, fragments = 3,
    marks = 26, markSeconds = 6.5, muzzleFins = 2, muzzleLight = false }
local DESKTOP_QUALITY = { maxDistance = 195, cooldown = 0.045, fragments = 4,
    marks = 36, markSeconds = 8, muzzleFins = 2, muzzleLight = true }

function Profile.surface(materialName)
    return SURFACES[MATERIALS[materialName] or "STONE"]
end

function Profile.budget(preset, touch, distance)
    local level = preset == "ECO" and ECO
        or (preset == "QUALITY" and (touch and MOBILE_QUALITY or DESKTOP_QUALITY))
        or (touch and MOBILE or DESKTOP)
    if type(distance) == "number" and distance > level.maxDistance then return nil end
    return level
end

function Profile.tracer(distance)
    local d = math.clamp(tonumber(distance) or 0, 0, 1500)
    if d < 0.10 then return nil end
    return { length = math.min(29, d), duration = math.clamp(d / 2400, 0.045, 0.15) }
end

return Profile
