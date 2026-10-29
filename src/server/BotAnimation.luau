-- IRON YARD / procedural R6 combat motion using travelled distance, not wall-clock skating.
-- No external AnimationIds or per-frame remote events; at most four server-owned AI.
local BotAnimation = {}

local function smooth(value, goal, factor)
    return value + (goal - value) * factor
end

function BotAnimation.step(bot, now, moved, targeting)
    local dt = math.clamp(now - (bot.animationAt or now - 0.2), 0.02, 0.35)
    bot.animationAt = now

    local current = bot.root.Position
    local previous = bot.lastAnimationPosition or current
    local delta = current - previous
    bot.lastAnimationPosition = current
    local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
    -- Large position jumps are respawns/teleports, not locomotion frames.
    if horizontalDistance > 10 then horizontalDistance = 0 end

    local floor = bot.humanoid.FloorMaterial
    local airborne = floor == Enum.Material.Air
    local speed = horizontalDistance / dt
    local moveGoal = (moved and not airborne) and math.clamp(speed / math.max(1, bot.skill.speed), 0, 1) or 0
    local smoothing = math.clamp(dt * 7, 0, 1)
    bot.walkBlend = smooth(bot.walkBlend or 0, moveGoal, smoothing)
    bot.aimBlend = smooth(bot.aimBlend or 0, targeting and 1 or 0, smoothing)
    local reloading = bot.reloadUntil > now
    bot.reloadBlend = smooth(bot.reloadBlend or 0, reloading and 1 or 0, smoothing)
    bot.airBlend = smooth(bot.airBlend or 0, airborne and 1 or 0, smoothing)
    -- Each landing gets a short weighted compression rather than an instant
    -- return to the standing pose. A hit adds torso and shoulder flinch.
    if bot.wasAirborne and not airborne then bot.landedAt = now end
    bot.wasAirborne = airborne
    local landing = math.max(0, 1 - (now - (bot.landedAt or -100)) / 0.32)
    landing = landing * landing
    local hit = math.max(0, 1 - (now - (bot.lastDamageAt or -100)) / 0.28)
    hit = hit * hit
    local defensive = (bot.coverGoal and (bot.ammoRemaining <= 0 or bot.reloadUntil > now))
        and 1 or 0
    bot.defensiveBlend = smooth(bot.defensiveBlend or 0, defensive, smoothing * 0.65)
    local sideways = bot.root.CFrame.RightVector:Dot(bot.root.AssemblyLinearVelocity)
    local strafeLean = math.clamp(sideways / math.max(bot.skill.speed, 1), -1, 1)
        * bot.walkBlend

    bot.gaitPhase = ((bot.gaitPhase or bot.slot * 0.33) + horizontalDistance * 0.72) % (math.pi * 2)
    local gait = math.sin(bot.gaitPhase)
    local step = gait * 0.62 * bot.walkBlend
    local sway = math.cos(bot.gaitPhase) * 0.06 * bot.walkBlend
    local breath = math.sin(now * 1.8 + bot.slot) * 0.022
    local recoil = math.max(0, 1 - (now - (bot.lastShotAt or -100)) / 0.17) * 0.20
    local aim = bot.aimBlend
    local reload = bot.reloadBlend
    local air = bot.airBlend
    local joints = bot.joints
    if not joints then return end

    -- The skeleton looks toward the real server aim vector while its lower
    -- body keeps moving. Angle limits avoid neck snapping during strafes.
    local forward = bot.root.CFrame.LookVector
    local facing = bot.aimDirection or forward
    local localAim = bot.root.CFrame:VectorToObjectSpace(facing)
    local yaw = math.clamp(-math.atan2(localAim.X, -localAim.Z), -0.48, 0.48) * aim

    -- Firing shoulder, supporting hand, reload dip and airborne recovery.
    joints.leftShoulder.C0 = CFrame.new(-1, 0.5, 0) *
        CFrame.Angles(step * (1 - aim) - aim * 0.55 + breath
            + reload * 0.8 - air * 0.24 + hit * 0.34,
            -aim * 0.28 + reload * 0.16, -aim * 0.15)
    joints.rightShoulder.C0 = CFrame.new(1, 0.5, 0) *
        CFrame.Angles(-step * (1 - aim) - aim * 0.48 - recoil
            + reload * 0.17 - air * 0.2 + hit * 0.29,
            aim * 0.04, aim * 0.1)
    joints.leftHip.C0 = CFrame.new(-0.5, -1, 0) *
        CFrame.Angles(-step - air * 0.38, 0, sway)
    joints.rightHip.C0 = CFrame.new(0.5, -1, 0) *
        CFrame.Angles(step + air * 0.28, 0, -sway)
    joints.neck.C0 = CFrame.new(0, 1, 0) *
        CFrame.Angles(-breath + air * 0.05 - hit * 0.13, yaw,
            strafeLean * -0.055)
    joints.root.C0 = CFrame.new(0,
        breath * 0.25 + math.abs(step) * 0.032 - landing * 0.12
            - bot.defensiveBlend * 0.10, 0) *
        CFrame.Angles(-bot.walkBlend * 0.055 - air * 0.055
            + landing * 0.09 + hit * 0.11 + bot.defensiveBlend * 0.07,
            0, sway * 0.35 - strafeLean * 0.075 + hit * (bot.slot % 2 == 0 and 0.08 or -0.08))
end

return BotAnimation
