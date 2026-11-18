-- First-person contact layers. Roblox's character sounds supply the base mix.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local shared = ReplicatedStorage:WaitForChild("Shared")
local SurfaceProfile = require(shared:WaitForChild("CombatVfxProfile"))
local MovementConfig = require(shared:WaitForChild("MovementConfig"))
local ContactAudio = require(script.Parent:WaitForChild("MovementContactAudio"))

local MovementAudio = {}
MovementAudio.__index = MovementAudio

-- Pro Sound Effects recordings from the Roblox Creator Store.
local SLIDES = {
    METAL = { id = "rbxassetid://9116802497", volume = 0.20, high = -10 },
    STONE = { id = "rbxassetid://9125441154", volume = 0.27, high = -4 },
    EARTH = { id = "rbxassetid://9114658419", volume = 0.30, high = -6 },
    WOOD = { id = "rbxassetid://9118768776", volume = 0.23, high = -5 },
    GLASS = { id = "rbxassetid://9113823112", volume = 0.24, high = -3 },
}

local SHOT_GAIN = {
    AssaultRifle = 0.58,
    Pistol = 0.73,
    Shotgun = 0.43,
    Sniper = 0.40,
}
local SHOT_HOLD_SECONDS = 0.045
local SHOT_RELEASE_SECONDS = 0.20

function MovementAudio.new()
    local group = Instance.new("SoundGroup")
    group.Name = "IronYardLocalMovement"
    group.Volume = 1
    group.Archivable = false
    group.Parent = SoundService

    local slideVoices = {}
    local slideSounds = {}
    for surface, profile in pairs(SLIDES) do
        local voice = ContactAudio.createVoice("IronYardSlide", SoundService, group)
        voice.sound.SoundId = profile.id
        voice.filter.HighGain = profile.high
        slideVoices[surface] = voice
        table.insert(slideSounds, voice.sound)
    end
    -- Prime the short local cue without gating movement on asset loading.
    task.defer(function()
        ContentProvider:PreloadAsync(slideSounds)
    end)

    return setmetatable({
        group = group,
        stepVoices = {
            ContactAudio.createVoice("IronYardMovementContact", SoundService, group),
            ContactAudio.createVoice("IronYardMovementContact", SoundService, group),
        },
        landingVoice = ContactAudio.createVoice("IronYardMovementContact", SoundService, group),
        slideVoices = slideVoices,
        stepIndex = 0,
        strideProgress = 0.65,
        descentSpeed = 0,
        shotGain = 1,
        releaseAt = -math.huge,
    }, MovementAudio)
end

function MovementAudio:duckForShot(weaponId, now)
    local gain = SHOT_GAIN[weaponId]
    if not gain or not self.humanoid then return end
    -- Keep the current attenuation if a quieter shot arrives mid-recovery.
    self.shotGain = math.min(self.group.Volume, gain)
    self.releaseAt = now + SHOT_HOLD_SECONDS
    self.group.Volume = self.shotGain
end

function MovementAudio:_updateSlide(floor, speed, remaining, dt)
    local surface
    local strength = math.clamp((speed - 8) / (MovementConfig.slideSpeed - 8), 0, 1)
    if remaining > 0 and strength > 0 and floor ~= Enum.Material.Air and floor ~= Enum.Material.Water then
        surface = SurfaceProfile.surfaceKind(floor.Name)
    end

    local endFade = math.min(remaining / 0.10, 1)
    local blend = 1 - math.exp(-32 * math.min(dt, 0.05))
    for kind, voice in pairs(self.slideVoices) do
        local active = kind == surface
        if active or voice.active then
            local sound = voice.sound
            local targetVolume = 0
            if active then
                targetVolume = SLIDES[kind].volume * math.sqrt(strength) * endFade
                local targetSpeed = 0.80 + 0.28 * strength
                if not voice.active then
                    voice.active = true
                    sound.PlaybackSpeed = targetSpeed
                    sound:Play()
                else
                    sound.PlaybackSpeed += (targetSpeed - sound.PlaybackSpeed) * blend
                end
            end
            sound.Volume += (targetVolume - sound.Volume) * blend
            if not active and sound.Volume < 0.004 then
                sound:Stop()
                sound.Volume = 0
                voice.active = false
            end
        end
    end
end

function MovementAudio:update(humanoid, root, slideRemaining, dt, now)
    if self.humanoid ~= humanoid then
        self.humanoid = humanoid
        self.strideProgress = 0.65
        self.descentSpeed = 0
        self.shotGain = 1
        self.releaseAt = -math.huge
        self.group.Volume = 1
        for _, voice in ipairs(self.stepVoices) do
            voice.sound:Stop()
        end
        self.landingVoice.sound:Stop()
        for _, voice in pairs(self.slideVoices) do
            if voice.active then
                voice.sound:Stop()
                voice.sound.Volume = 0
                voice.active = false
            end
        end
    end
    if not humanoid then return end

    if self.group.Volume < 1 and now > self.releaseAt then
        -- Absolute elapsed time also clears stale attenuation on mobile resume.
        local t = math.min((now - self.releaseAt) / SHOT_RELEASE_SECONDS, 1)
        local eased = t * t * (3 - 2 * t)
        self.group.Volume = self.shotGain + (1 - self.shotGain) * eased
    end

    local floor = humanoid.FloorMaterial
    local velocity = root.AssemblyLinearVelocity
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    self:_updateSlide(floor, speed, slideRemaining, dt)
    if floor == Enum.Material.Air then
        self.descentSpeed = math.max(0, -velocity.Y)
        self.strideProgress = 0.65
        return
    end

    local descentSpeed = self.descentSpeed
    self.descentSpeed = 0
    if floor == Enum.Material.Water then
        self.strideProgress = 0.65
        return
    end

    if descentSpeed > 18 and dt <= 0.12 then
        local impact = math.clamp((descentSpeed - 18) / 72, 0, 1)
        ContactAudio.play(self.landingVoice, floor.Name, 0.11 + 0.22 * impact, 0.84 - 0.09 * impact, -2)
        self.strideProgress = 0.2
        return
    end

    if slideRemaining > 0 or speed < 4 or humanoid.MoveDirection.Magnitude < 0.05 then
        self.strideProgress = 0.65
        return
    end

    -- Distance-based contacts follow walk/sprint cadence without firing a
    -- burst of delayed steps after a background pause or a slow mobile frame.
    local pace, strideLength = ContactAudio.stepPace(speed)
    self.strideProgress += math.min(dt, 0.05) * math.min(speed, 40) / strideLength
    if self.strideProgress < 1 then return end
    self.strideProgress -= 1
    self.stepIndex = self.stepIndex % #self.stepVoices + 1
    local speedVariation = self.stepIndex == 1 and 0.97 or 1.03
    ContactAudio.play(self.stepVoices[self.stepIndex], floor.Name, 0.10 + 0.10 * pace, speedVariation, 0)
end

return MovementAudio
