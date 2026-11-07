-- IRON YARD / procedural R6 combat motion using travelled distance, not wall-clock skating.
-- No external AnimationIds or per-frame remote events; at most four server-owned AI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Motion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotMotionProfile"))
local BotAnimation = {}

function BotAnimation.step(bot, now, targeting)
    local dt = math.clamp(now - (bot.animationAt or now - 0.08), 0.01, 0.35)
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
    -- Sample the ACTUAL velocity relative to the rig's aim-facing chassis.
    -- A bot can run backwards or strafe while facing its opponent; neither
    -- motion should look like a forward sprint. Travel distance also gates
    -- the cycle, so a bot pushing into a wall cannot keep running in place.
    local physicalVelocity = bot.root.AssemblyLinearVelocity
    local previousVelocity = bot.lastAnimationVelocity or physicalVelocity
    bot.lastAnimationVelocity = physicalVelocity
    local facingNow = bot.root.CFrame.LookVector
    local previousFacing = bot.lastAnimationFacing or facingNow
    bot.lastAnimationFacing = facingNow
    local turnGoal = Motion.turnSignal(previousFacing.X, previousFacing.Z,
        facingNow.X, facingNow.Z, dt)
    local reverseGoal = Motion.reversalSignal(previousVelocity.X, previousVelocity.Z,
        physicalVelocity.X, physicalVelocity.Z)
    bot.turnBlend = Motion.smooth(bot.turnBlend or 0, turnGoal, dt, 12)
    bot.reversalBlend = Motion.smooth(bot.reversalBlend or 0, reverseGoal, dt, 13)
    local planar = bot.root.CFrame:VectorToObjectSpace(physicalVelocity)
    local moveGoal, forward, lateral = Motion.weights(planar.X, planar.Z,
        horizontalDistance / dt, bot.skill.speed, not airborne)
    bot.walkBlend = Motion.smooth(bot.walkBlend or 0, moveGoal, dt, 8)
    bot.forwardBlend = Motion.smooth(bot.forwardBlend or 0, forward, dt, 10)
    bot.lateralBlend = Motion.smooth(bot.lateralBlend or 0, lateral, dt, 10)
    bot.aimBlend = Motion.smooth(bot.aimBlend or 0, targeting and 1 or 0, dt, 11)
    local reloading = bot.reloadUntil > now
    bot.reloadBlend = Motion.smooth(bot.reloadBlend or 0, reloading and 1 or 0, dt, 10)
    bot.airBlend = Motion.smooth(bot.airBlend or 0, airborne and 1 or 0, dt, 8)
    -- Each landing gets a short weighted compression rather than an instant
    -- return to the standing pose. A hit adds torso and shoulder flinch.
    if bot.wasAirborne and not airborne then bot.landedAt = now end
    bot.wasAirborne = airborne
    local landing = math.max(0, 1 - (now - (bot.landedAt or -100)) / 0.32)
    landing = landing * landing
    local hit = math.max(0, 1 - (now - (bot.lastDamageAt or -100)) / 0.28)
    hit = hit * hit
    -- Impact side comes from a verified server ray, not an arbitrary
    -- per-slot alternating lean. Preserve locomotion and reload blending.
    local hitSide = math.clamp(bot.hitSide or 0, -1, 1)
    local hitFront = math.clamp(bot.hitFront or 0, -1, 1)
    local hitRoll = hit * hitSide * 0.14
    local hitPitch = hit * hitFront * 0.09
    local defensive = (bot.coverGoal and (bot.ammoRemaining <= 0 or reloading))
        or now < (bot.suppressedUntil or 0)
    bot.defensiveBlend = Motion.smooth(bot.defensiveBlend or 0,
        defensive and 1 or 0, dt, 6)
    local strafeLean = (bot.lateralBlend or 0) * bot.walkBlend
    local forwardStride = (bot.forwardBlend or 0)
    local lateralStride = (bot.lateralBlend or 0)
    local braking = math.clamp((bot.walkBlend or 0) - moveGoal
        + bot.reversalBlend * 0.30, 0, 0.8)
    -- Rotating on the spot uses small planted-foot pivots, not a fake running
    -- gait. Opposite-facing legs absorb actual direction reversals.
    local pivot = (bot.turnBlend or 0) * (1 - bot.walkBlend * 0.65)

    bot.gaitPhase = Motion.gaitPhase(bot.gaitPhase or bot.slot * 0.33, horizontalDistance)
    local gait = math.sin(bot.gaitPhase)
    local step = gait * 0.62 * bot.walkBlend
    local stridePitch = step * (math.abs(forwardStride) * 0.7 + 0.3)
        * (forwardStride < -0.2 and -1 or 1)
        * (1 - bot.reversalBlend * 0.30)
    local sideStep = math.cos(bot.gaitPhase) * lateralStride * bot.walkBlend * 0.26
    local sway = math.cos(bot.gaitPhase) * 0.06 * bot.walkBlend
    local breath = math.sin(now * 1.8 + bot.slot) * 0.022
    local recoil = math.max(0, 1 - (now - (bot.lastShotAt or -100)) / 0.17) * 0.20
    -- Distinct pre-fire brace and short follow-through prevent a robotic
    -- single-frame weapon kick, while remaining procedural and asset-free.
    local fireAge = now - (bot.lastShotAt or -100)
    local fireBrace = math.max(0, 1 - math.abs(fireAge - 0.11) / 0.18) * 0.085
    local reloadPhase = bot.reloadUntil > now
        and math.clamp(1 - (bot.reloadUntil - now) / 1.85, 0, 1) or 0
    local magazineReach = math.sin(reloadPhase * math.pi) * bot.reloadBlend * 0.26
    local aim = bot.aimBlend
    local reload = bot.reloadBlend
    local air = bot.airBlend
    local joints = bot.joints
    if not joints then return end

    -- The skeleton looks toward the real server aim vector while its lower
    -- body keeps moving. Angle limits avoid neck snapping during strafes.
    local forward = facingNow
    local facing = bot.aimDirection or forward
    local localAim = bot.root.CFrame:VectorToObjectSpace(facing)
    local yaw = math.clamp(-math.atan2(localAim.X, -localAim.Z), -0.48, 0.48) * aim

    -- Firing shoulder, supporting hand, reload dip and airborne recovery.
    joints.leftShoulder.C0 = CFrame.new(-1, 0.5, 0) *
        CFrame.Angles(stridePitch * (1 - aim) - aim * 0.55 + breath
            + reload * 0.8 + magazineReach - air * 0.24 + hit * 0.34,
            -aim * 0.28 + reload * 0.16 + pivot * 0.07, -aim * 0.15)
    joints.rightShoulder.C0 = CFrame.new(1, 0.5, 0) *
        CFrame.Angles(-stridePitch * (1 - aim) - aim * 0.48 - recoil + fireBrace
            + reload * 0.17 - air * 0.2 + hit * 0.29,
            aim * 0.04 - pivot * 0.065, aim * 0.1)
    joints.leftHip.C0 = CFrame.new(-0.5, -1, 0) *
        CFrame.Angles(-stridePitch - air * 0.38 - braking * 0.14
            + bot.reversalBlend * 0.11,
            -sideStep * 0.75 + pivot * 0.15,
            sway + sideStep * 0.30 - pivot * 0.07)
    joints.rightHip.C0 = CFrame.new(0.5, -1, 0) *
        CFrame.Angles(stridePitch + air * 0.28 - braking * 0.14
            + bot.reversalBlend * 0.11,
            sideStep * 0.75 - pivot * 0.15,
            -sway + sideStep * 0.30 + pivot * 0.07)
    joints.neck.C0 = CFrame.new(0, 1, 0) *
        CFrame.Angles(-breath + air * 0.05 - hit * 0.13,
            yaw + hitSide * hit * 0.065 - pivot * 0.085,
            strafeLean * -0.055 - hitRoll * 0.3)
    joints.root.C0 = CFrame.new(0,
        breath * 0.25 + math.abs(step) * 0.032 - landing * 0.12
            - bot.defensiveBlend * 0.12, 0) *
        CFrame.Angles(-forwardStride * bot.walkBlend * 0.075 - air * 0.055
            + landing * 0.09 + hit * 0.11 + hitPitch
            + bot.defensiveBlend * 0.095 + braking * 0.045,
            strafeLean * -0.035 + pivot * 0.09,
            sway * 0.35 - strafeLean * 0.10 + hitRoll
                - pivot * 0.10)
end

return BotAnimation
