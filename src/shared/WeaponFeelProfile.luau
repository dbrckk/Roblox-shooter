-- IRON YARD / cosmetic-only first-person handling profiles.
-- All data is pure Luau: no camera, damage, recoil authority or network state.
local Feel = {}

local PROFILES = {
    AssaultRifle = {
        kickCap = 0.16, recovery = 14.5, shotSeconds = 0.13, shotDecay = 2.85,
        back = 0.055, pitch = 5.5, yaw = -1.2, roll = 0.7,
        followUpTilt = 0.76,
        adsBack = 0.74, adsPitch = 0.42, adsLateral = 0.20,
        equipSeconds = 0.20, equipDrop = 0.32, equipBack = 0.27,
        equipPitch = -14, equipYaw = 8,
        reloadX = 0.055, reloadY = -0.15, reloadZ = 0.14,
        reloadPitch = 14, reloadYaw = 12, reloadRoll = 8,
        handTravel = 0.95, magazineTravel = 1.0,
        actionSeconds = 0.12, actionTravel = 0.09,
    },
    Pistol = {
        kickCap = 0.16, recovery = 11.8, shotSeconds = 0.17, shotDecay = 2.45,
        back = 0.078, pitch = 9, yaw = 1.6, roll = -1.5,
        adsBack = 0.80, adsPitch = 0.49, adsLateral = 0.24,
        equipSeconds = 0.15, equipDrop = 0.24, equipBack = 0.19,
        equipPitch = -10, equipYaw = 11,
        reloadX = 0.13, reloadY = -0.18, reloadZ = 0.13,
        reloadPitch = 20, reloadYaw = -13, reloadRoll = -17,
        handTravel = 0.9, magazineTravel = 1.15,
        actionSeconds = 0.14, actionTravel = 0.16,
    },
    Shotgun = {
        kickCap = 0.30, recovery = 5.8, shotSeconds = 0.31, shotDecay = 1.65,
        back = 0.14, pitch = 15, yaw = -2.7, roll = 2.4,
        adsBack = 0.87, adsPitch = 0.55, adsLateral = 0.27,
        equipSeconds = 0.25, equipDrop = 0.43, equipBack = 0.32,
        equipPitch = -18, equipYaw = 7,
        reloadX = 0.09, reloadY = -0.24, reloadZ = 0.21,
        reloadPitch = 27, reloadYaw = 17, reloadRoll = 12,
        handTravel = 1.3, magazineTravel = 0,
        actionDelay = 0.39, actionWindow = 0.25, actionTravel = 0.32,
    },
    Sniper = {
        kickCap = 0.29, recovery = 5.3, shotSeconds = 0.29,
        back = 0.13, pitch = 12.5, yaw = -0.6, roll = 0.8,
        equipSeconds = 0.27, equipDrop = 0.47, equipBack = 0.32,
        equipPitch = -17, equipYaw = 5,
        reloadX = 0.08, reloadY = -0.21, reloadZ = 0.19,
        reloadPitch = 23, reloadYaw = 11, reloadRoll = 13,
        handTravel = 1.1, magazineTravel = 1.1,
        actionDelay = 0.43, actionWindow = 0.23, actionTravel = 0.15,
    },
    Knife = {
        kickCap = 0.11, recovery = 12.5, shotSeconds = 0.23,
        back = 0.03, pitch = -13, yaw = 10, roll = -12,
        equipSeconds = 0.15, equipDrop = 0.30, equipBack = 0.13,
        equipPitch = -18, equipYaw = 14,
        reloadX = 0, reloadY = 0, reloadZ = 0,
        reloadPitch = 0, reloadYaw = 0, reloadRoll = 0,
        handTravel = 0, magazineTravel = 0,
    },
}

local function finite(n)
    return type(n) == "number" and n == n
        and n > -math.huge and n < math.huge
end

function Feel.get(id)
    return PROFILES[id]
end

function Feel.kick(id, current, added)
    local profile = PROFILES[id]
    if not profile or not finite(current) or not finite(added) then return 0 end
    return math.clamp(math.max(0, current) + math.max(0, added), 0, profile.kickCap)
end

function Feel.recover(id, current, dt)
    local profile = PROFILES[id]
    if not profile or not finite(current) or not finite(dt) then return 0 end
    if dt <= 0 then return math.max(0, current) end
    -- Use actual elapsed time, not a one-second cap. A mobile client may
    -- suspend rendering while backgrounded: old recoil must be fully gone
    -- when the app resumes. Clamp only the exponent to prevent underflow
    -- work for multi-hour hitches; ordinary 30/60/120 FPS is unchanged.
    return math.max(0, current) * math.exp(-profile.recovery * math.min(dt, 20))
end

function Feel.shotEnvelope(id, age)
    local profile = PROFILES[id]
    if not profile or not finite(age) or age < 0 then return 0 end
    local fraction = math.clamp(1 - age / profile.shotSeconds, 0, 1)
    return fraction ^ (profile.shotDecay or 2)
end

function Feel.shotTiltScale(id, followUp)
    local profile = PROFILES[id]
    return followUp == true and profile and profile.followUpTilt or 1
end

-- Retain more rearward travel than tilt as the gun enters the sight line.
function Feel.aimRecoilScale(profile, aimBlend)
    local blend = math.clamp(aimBlend, 0, 1)
    return 1 - (1 - (profile.adsBack or 1)) * blend,
        1 - (1 - (profile.adsPitch or 1)) * blend,
        1 - (1 - (profile.adsLateral or 1)) * blend
end

function Feel.mechanism(id, age)
    local profile = PROFILES[id]
    if not profile or not finite(age) or age < 0 then return 0 end
    if profile.actionDelay then
        return math.max(0, 1 - math.abs(age - profile.actionDelay) / profile.actionWindow)
    end
    if profile.actionSeconds then
        return math.clamp(1 - age / profile.actionSeconds, 0, 1)
    end
    return 0
end

return Feel
