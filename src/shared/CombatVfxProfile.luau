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
        sparks = true, glimmer = true, spread = 0.85,
        markStyle = {widthMin = 0.12, widthMax = 0.19, aspectMin = 0.82,
            aspectMax = 1.10, depth = 0.012, surfaceOffset = 0.023, metallic = true} },
    WOOD = { debris = { 187, 147, 98 }, mark = { 49, 37, 28 },
        sparks = false, glimmer = false, spread = 0.54,
        markStyle = {widthMin = 0.16, widthMax = 0.29, aspectMin = 1.34,
            aspectMax = 1.82, depth = 0.018, surfaceOffset = 0.035, metallic = false} },
    GLASS = { debris = { 184, 213, 216 }, mark = { 89, 108, 113 },
        sparks = false, glimmer = true, spread = 0.65,
        markStyle = {widthMin = 0.16, widthMax = 0.25, aspectMin = 1.04,
            aspectMax = 1.28, depth = 0.012, surfaceOffset = 0.027, metallic = false} },
    EARTH = { debris = { 148, 134, 108 }, mark = { 66, 62, 52 },
        sparks = false, glimmer = false, spread = 0.40,
        markStyle = {widthMin = 0.20, widthMax = 0.34, aspectMin = 0.78,
            aspectMax = 1.12, depth = 0.020, surfaceOffset = 0.036, metallic = false} },
    STONE = { debris = { 182, 181, 169 }, mark = { 55, 54, 51 },
        sparks = false, glimmer = false, spread = 0.48,
        markStyle = {widthMin = 0.15, widthMax = 0.26, aspectMin = 0.86,
            aspectMax = 1.14, depth = 0.019, surfaceOffset = 0.032, metallic = false} },
}

-- Material-specific trajectories stay procedural and share the existing
-- reusable Part pool. These tables never create physics debris or raycasts.
local MOTION = {
    METAL = { gravity = 0.09, spin = 0.25, flicker = 0.32 },
    WOOD = { gravity = 0.58, spin = 2.40, flicker = 0 },
    GLASS = { gravity = 0.37, spin = 1.85, flicker = 0.12 },
    EARTH = { gravity = 0.84, spin = 1.10, flicker = 0 },
    STONE = { gravity = 0.68, spin = 0.95, flicker = 0 },
}

function Profile.fragmentMotion(materialName)
    return MOTION[MATERIALS[materialName] or "STONE"]
end

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

-- Surface-aware bullet scar footprints, static and reused across all shots.
-- Thin/compact metal punctures, longer wooden splinters, wider loose dirt.
-- The same existing ImpactMarkPool still owns at most 10..36 Parts.
function Profile.markStyle(materialName)
    return Profile.surface(materialName).markStyle
end

-- Original weapon-specific thermal flash silhouettes. The existing preset
-- sets the Part count (0/1/2 fins on ECO/mobile/desktop); no extra assets,
-- geometry instances, RemoteEvents or allocations on RenderStepped.
local MUZZLE_SIGNATURES = {
    AssaultRifle = {tint = {251, 212, 145}, coreRadius = 0.23,
        finThickness = 0.07, finWidth = 0.30, finLength = 0.55,
        advance = 0.24, finAlpha = 0.24, duration = 0.075},
    Pistol = {tint = {255, 222, 160}, coreRadius = 0.16,
        finThickness = 0.065, finWidth = 0.22, finLength = 0.31,
        advance = 0.18, finAlpha = 0.26, duration = 0.067},
    Shotgun = {tint = {255, 180, 99}, coreRadius = 0.35,
        finThickness = 0.13, finWidth = 0.48, finLength = 0.72,
        advance = 0.28, finAlpha = 0.18, duration = 0.095},
    Sniper = {tint = {255, 202, 119}, coreRadius = 0.28,
        finThickness = 0.095, finWidth = 0.36, finLength = 0.82,
        advance = 0.34, finAlpha = 0.22, duration = 0.090},
}

function Profile.muzzleSignature(weaponId)
    if weaponId == "Knife" then return nil end
    return MUZZLE_SIGNATURES[weaponId] or MUZZLE_SIGNATURES.AssaultRifle
end

function Profile.budget(preset, touch, distance)
    local level = preset == "ECO" and ECO
        or (preset == "QUALITY" and (touch and MOBILE_QUALITY or DESKTOP_QUALITY))
        or (touch and MOBILE or DESKTOP)
    if type(distance) == "number" and distance > level.maxDistance then return nil end
    return level
end

-- Shooter-side 3D confirmation is only emitted on validated server damage.
function Profile.hitFeedback(preset, touch, distance, headshot, killed)
    if type(distance) ~= "number" or distance ~= distance
        or distance < 0 or distance == math.huge
        or not Profile.budget(preset, touch, distance) then return nil end
    -- Melee-range hits must not obscure the reticle on an Android display.
    local close = distance < 7
    return {
        duration = killed and 0.26 or (headshot and 0.20 or 0.16),
        sparks = close and 1 or ((touch and 1 or 2) + (killed and 1 or 0)),
        -- One extra recycled ring on a confirmed elimination except ECO.
        -- Readable on mobile without ParticleEmitters or new remotes.
        eliminationRing = killed == true and preset ~= "ECO",
        radius = (killed and 0.31 or (headshot and 0.26 or 0.19))
            * (close and 0.62 or 1),
    }
end

function Profile.hitPriority(headshot, killed)
    return killed and 3 or (headshot and 2 or 1)
end

-- A real shotgun kill must override a body-hit glint from the same volley.
function Profile.shouldDisplayHit(now, lastAt, lastPriority, priority)
    if type(now) ~= "number" or now ~= now or math.abs(now) == math.huge
        or type(lastAt) ~= "number" or lastAt ~= lastAt
        or type(priority) ~= "number" or priority < 1 then return false end
    if now < lastAt then return false end
    return now - lastAt >= 0.11 or priority > (lastPriority or 0)
end

function Profile.pelletVisualCount(preset, touch, distance)
    if not Profile.budget(preset, touch, distance) then return 0 end
    if preset == "ECO" then return 1 end
    if touch and preset ~= "QUALITY" then return 2 end
    return 3
end

function Profile.tracer(distance)
    if type(distance) ~= "number" or distance ~= distance
        or math.abs(distance) == math.huge then return nil end
    local d = math.clamp(distance, 0, 1500)
    if d < 0.10 then return nil end
    -- Short tracers now travel: no static laser bar filling the whole ray.
    return { length = math.min(29, d * 0.36),
        duration = math.clamp(d / 2400, 0.045, 0.15) }
end

return Profile
