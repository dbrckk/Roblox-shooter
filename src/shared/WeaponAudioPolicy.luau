-- IRON YARD / purely local, performance-budgeted three-dimensional gun audio.
-- Rules never affect authoritative shots, combat detection or damage.
local Audio = {}

local function finite(n)
    return type(n) == "number" and n == n
        and n > -math.huge and n < math.huge
end

local LEVELS = {
    ECO = { mobileDistance = 95, pcDistance = 125, mobileVoices = 8, pcVoices = 12 },
    BALANCED = { mobileDistance = 130, pcDistance = 175, mobileVoices = 12, pcVoices = 18 },
    QUALITY = { mobileDistance = 155, pcDistance = 205, mobileVoices = 16, pcVoices = 24 },
}

-- Acoustic reach differs by weapon, but never increases the device's
-- global maximum audible range or active emitter cap.
local REACH = {
    AssaultRifle = 1.0,
    Pistol = 0.75,
    Shotgun = 0.90,
    Sniper = 1.0,
    Knife = 0.38,
}

function Audio.select(preset, mobile, distance, localShot, activeVoices, weaponId)
    if localShot then
        -- Your weapon sound must never be gated by other players' audio.
        return { layers = 2, volume = 1, maxDistance = 160,
            lifetime = 2, maxVoices = math.huge }
    end
    if not finite(distance) or distance < 0
        or not finite(activeVoices) or activeVoices < 0 then return nil end
    local level = LEVELS[preset] or LEVELS.BALANCED
    local maxDistance = (mobile and level.mobileDistance or level.pcDistance)
        * (REACH[weaponId] or 1)
    local maxVoices = mobile and level.mobileVoices or level.pcVoices
    if distance > maxDistance or activeVoices >= maxVoices then return nil end
    local far = distance > maxDistance * 0.68
    return {
        layers = far and 1 or 2,
        volume = far and 0.75 or 1,
        maxDistance = maxDistance,
        lifetime = 2,
        maxVoices = maxVoices,
    }
end

-- One WORLD geometry probe per admitted remote shot (not per frame).
-- Ignore players/NPCs in the caller so a body between shooter and listener
-- is not mistaken for a concrete wall. Very close shots stay unfiltered.
function Audio.needsOcclusion(distance, localShot)
    return not localShot and finite(distance) and distance >= 12
end

-- Conservative, non-mutating acoustic cover mix. An obstructed gunshot
-- remains audible but has a quieter, less sharp, single-layer sound.
-- The server still owns firing/visibility/damage; this is cosmetic only.
function Audio.occludedMix(mix, blocked)
    if type(mix) ~= "table" or blocked ~= true then return mix end
    return {
        layers = 1,
        volume = mix.volume * 0.40,
        maxDistance = mix.maxDistance,
        lifetime = mix.lifetime,
        maxVoices = mix.maxVoices,
    }
end

return Audio
