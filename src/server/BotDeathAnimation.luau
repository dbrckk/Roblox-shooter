-- IRON YARD / three-stage, server-authored elimination choreography.
-- Static rig pose, not a simulated ragdoll: all deceased hitboxes remain
-- non-colliding and non-queryable until the 2.5-second despawn.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotDeathPlan"))
local BotDeathAnimation = {}

local function stageTargets(joints, pose)
    return {
        { joints.root, CFrame.new(0, pose.drop, 0)
            * CFrame.Angles(pose.pitch, 0, pose.roll) },
        { joints.leftShoulder, CFrame.new(-1, 0.5, 0)
            * CFrame.Angles(pose.leftArm, 0, -0.20) },
        { joints.rightShoulder, CFrame.new(1, 0.5, 0)
            * CFrame.Angles(pose.rightArm, 0, 0.20) },
        { joints.leftHip, CFrame.new(-0.5, -1, 0)
            * CFrame.Angles(pose.leftHip, -pose.roll * 0.30, -0.12) },
        { joints.rightHip, CFrame.new(0.5, -1, 0)
            * CFrame.Angles(pose.rightHip, pose.roll * 0.30, 0.12) },
        { joints.neck, CFrame.new(0, 1, 0)
            * CFrame.Angles(pose.neck, -pose.roll * 0.22, 0) },
    }
end

function BotDeathAnimation.play(bot)
    if not bot or not bot.model or not bot.joints
        or not bot.root or not bot.root.Parent then return end
    -- Keep a defeated model at the final combat position. It remains
    -- visible for the existing short despawn window, but never blocks fire.
    bot.root.Anchored = true
    bot.root.AssemblyLinearVelocity = Vector3.zero
    bot.root.AssemblyAngularVelocity = Vector3.zero
    local identity = bot.head and bot.head:FindFirstChild("BotIdentity")
    if identity and identity:IsA("BillboardGui") then
        identity.Enabled = false
    end

    local elapsed = 0
    for _, pose in ipairs(Plan.sequence(bot.hitSide, bot.hitFront, bot.slot)) do
        local function animateStage()
            if not bot.model.Parent or not bot.root.Parent
                or bot.humanoid.Health > 0 then return end
            local tweenInfo = TweenInfo.new(pose.duration,
                Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            for _, target in ipairs(stageTargets(bot.joints, pose)) do
                local joint, value = target[1], target[2]
                if joint and joint.Parent then
                    TweenService:Create(joint, tweenInfo, { C0 = value }):Play()
                end
            end
        end
        if elapsed == 0 then
            animateStage()
        else
            task.delay(elapsed, animateStage)
        end
        elapsed += pose.duration
    end
end

return BotDeathAnimation
