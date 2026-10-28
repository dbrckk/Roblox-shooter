-- Procedural R6 combat animation for NEON STRIKE.
-- Driven by server locomotion and target state; no external animation IDs.
local BotAnimation = {}

local function lerp01(current, goal, factor)
    return current + (goal - current) * factor
end

function BotAnimation.step(bot, now, moved, targeting)
    local dt = math.max(0.02, now - (bot.animationAt or now - 0.2))
    bot.animationAt = now
    local blend = math.clamp(dt * 6, 0, 1)
    local locomotion = moved and 1 or 0
    bot.walkBlend = lerp01(bot.walkBlend or 0, locomotion, blend)
    bot.aimBlend = lerp01(bot.aimBlend or 0, targeting and 1 or 0, blend)
    local stride = math.sin(now * 9 + bot.slot * 0.8) * 0.55 * bot.walkBlend
    local idle = math.sin(now * 1.8 + bot.slot) * 0.025
    local shotAt = bot.lastShotAt or -100
    local recoil = math.max(0, 1 - (now - shotAt) / 0.17) * 0.18
    local aim = bot.aimBlend
    local joints = bot.joints
    if not joints then return end

    local forward = bot.root.CFrame.LookVector
    local facing = bot.aimDirection or forward
    local localAim = bot.root.CFrame:VectorToObjectSpace(facing)
    local yaw = math.clamp(-math.atan2(localAim.X, -localAim.Z), -0.45, 0.45) * aim

    -- Gun stays in right hand while the left hand steadies the receiver.
    joints.leftShoulder.C0 = CFrame.new(-1, 0.5, 0) *
        CFrame.Angles(stride * (1 - aim) - aim * 0.56 + idle, -aim * 0.28, -aim * 0.15)
    joints.rightShoulder.C0 = CFrame.new(1, 0.5, 0) *
        CFrame.Angles(-stride * (1 - aim) - aim * 0.48 - recoil, aim * 0.04, aim * 0.1)
    joints.leftHip.C0 = CFrame.new(-0.5, -1, 0) * CFrame.Angles(-stride, 0, 0)
    joints.rightHip.C0 = CFrame.new(0.5, -1, 0) * CFrame.Angles(stride, 0, 0)
    joints.neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(-idle, yaw, 0)
    joints.root.C0 = CFrame.new(0, idle * 0.3, 0) *
        CFrame.Angles(-bot.walkBlend * 0.045, 0, stride * 0.065)
end

return BotAnimation
