-- First-person contact layers. Roblox's character sounds supply the base mix.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local SurfaceProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatVfxProfile"))

local MovementAudio = {}
MovementAudio.__index = MovementAudio

local CONTACTS = {
    METAL = { id = "rbxasset://sounds/plasticmetal.mp3", speed = 1.26, gain = 0.92, high = 0 },
    STONE = { id = "rbxasset://sounds/plasticstone.mp3", speed = 1.13, gain = 1, high = -3 },
    EARTH = { id = "rbxasset://sounds/plasticgrass.mp3", speed = 1.06, gain = 0.92, high = -8 },
    WOOD = { id = "rbxasset://sounds/woodplastic.mp3", speed = 1.18, gain = 0.96, high = -4 },
    GLASS = { id = "rbxasset://sounds/plasticice.mp3", speed = 1.21, gain = 0.82, high = -2 },
}

local function createVoice()
    local sound = Instance.new("Sound")
    sound.Name = "IronYardMovementContact"
    sound.Volume = 0
    sound.Archivable = false
    local filter = Instance.new("EqualizerSoundEffect")
    filter.Parent = sound
    sound.Parent = SoundService
    return { sound = sound, filter = filter }
end

local function play(voice, contact, volume, speed, high)
    local sound = voice.sound
    sound:Stop()
    if sound.SoundId ~= contact.id then
        sound.SoundId = contact.id
    end
    sound.Volume = volume * contact.gain
    sound.PlaybackSpeed = speed * contact.speed
    voice.filter.HighGain = contact.high + high
    sound:Play()
end

function MovementAudio.new()
    return setmetatable({
        stepVoices = { createVoice(), createVoice() },
        landingVoice = createVoice(),
        stepIndex = 0,
        strideProgress = 0.65,
        descentSpeed = 0,
    }, MovementAudio)
end

function MovementAudio:update(humanoid, root, sliding, dt)
    if self.humanoid ~= humanoid then
        self.humanoid = humanoid
        self.strideProgress = 0.65
        self.descentSpeed = 0
        for _, voice in ipairs(self.stepVoices) do
            voice.sound:Stop()
        end
        self.landingVoice.sound:Stop()
    end
    if not humanoid then return end

    local floor = humanoid.FloorMaterial
    local velocity = root.AssemblyLinearVelocity
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
        local contact = CONTACTS[SurfaceProfile.surfaceKind(floor.Name)]
        play(self.landingVoice, contact, 0.11 + 0.22 * impact, 0.84 - 0.09 * impact, -2)
        self.strideProgress = 0.2
        return
    end

    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    if sliding or speed < 4 or humanoid.MoveDirection.Magnitude < 0.05 then
        self.strideProgress = 0.65
        return
    end

    -- Distance-based contacts follow walk/sprint cadence without firing a
    -- burst of delayed steps after a background pause or a slow mobile frame.
    local pace = math.clamp((speed - 12) / 24, 0, 1)
    local strideLength = 7.5 + 2.2 * pace
    self.strideProgress += math.min(dt, 0.05) * math.min(speed, 40) / strideLength
    if self.strideProgress < 1 then return end
    self.strideProgress -= 1
    self.stepIndex = self.stepIndex % #self.stepVoices + 1
    local speedVariation = self.stepIndex == 1 and 0.97 or 1.03
    local contact = CONTACTS[SurfaceProfile.surfaceKind(floor.Name)]
    play(self.stepVoices[self.stepIndex], contact, 0.10 + 0.10 * pace, speedVariation, 0)
end

return MovementAudio
