local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SurfaceProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatVfxProfile"))

local Audio = {}

local CONTACTS = {
    METAL = { id = "rbxasset://sounds/plasticmetal.mp3", speed = 1.26, gain = 0.92, high = 0 },
    STONE = { id = "rbxasset://sounds/plasticstone.mp3", speed = 1.13, gain = 1, high = -3 },
    EARTH = { id = "rbxasset://sounds/plasticgrass.mp3", speed = 1.06, gain = 0.92, high = -8 },
    WOOD = { id = "rbxasset://sounds/woodplastic.mp3", speed = 1.18, gain = 0.96, high = -4 },
    GLASS = { id = "rbxasset://sounds/plasticice.mp3", speed = 1.21, gain = 0.82, high = -2 },
}

function Audio.createVoice(name, parent, group)
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.Volume = 0
    sound.SoundGroup = group
    sound.Archivable = false
    local filter = Instance.new("EqualizerSoundEffect")
    filter.Parent = sound
    sound.Parent = parent
    return { sound = sound, filter = filter }
end

function Audio.play(voice, materialName, volume, speed, high)
    local contact = CONTACTS[SurfaceProfile.surfaceKind(materialName)]
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

function Audio.stepPace(speed)
    local pace = math.clamp((speed - 12) / 24, 0, 1)
    return pace, 7.5 + 2.2 * pace
end

return Audio
