-- Short positional contacts from streamed opponent rigs, budgeted per listener.
local Players = game:GetService("Players")
local DuelReadout = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DuelReadout"))
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ContactAudio = require(script.Parent:WaitForChild("MovementContactAudio"))

local player = Players.LocalPlayer
local mobile = UserInputService.TouchEnabled
local MAX_VOICES = mobile and 4 or 6
local SAMPLE_SECONDS = 0.08
local VOICE_SECONDS = 0.38
local FOOT_LIFT = Vector3.new(0, 0.35, 0)
local FOOTSTEP_VOLUME_ATTRIBUTE = "IronYardOpponentFootstepVolume"

local mix = Instance.new("SoundGroup")
mix.Name = "IronYardOpponentFootsteps"
mix.Archivable = false
mix.Parent = SoundService

local tracks, due, exclude, voices = {}, {}, {}, {}
local rays = RaycastParams.new()
rays.FilterType = Enum.RaycastFilterType.Exclude
rays.RespectCanCollide = true

local function sample(character, eye, range, now, elapsed)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return end
    local position = root.Position
    local distance = (position - eye).Magnitude
    if distance >= range then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 or humanoid.Sit then return end

    local track = tracks[character]
    if not track or track.root ~= root or elapsed > 0.22 then
        tracks[character] = {
            root = root, position = position, seenAt = now,
            lastMovingAt = now, progress = 0.60, right = false,
        }
        return
    end

    local delta = position - track.position
    track.position = position
    track.seenAt = now
    local travelled = Vector3.new(delta.X, 0, delta.Z).Magnitude
    local speed = travelled / elapsed
    -- Suppress teleports and velocities associated with boosts and slides.
    if delta.Magnitude > 9 or speed > 44 then
        track.progress = 0.60
        return
    end
    if speed < 4 then
        if now - track.lastMovingAt > 0.20 then track.progress = 0.60 end
        return
    end
    track.lastMovingAt = now
    local pace, strideLength = ContactAudio.stepPace(speed)
    track.progress += travelled / strideLength
    if track.progress < 1 then return end
    track.progress %= 1
    track.right = not track.right
    track.humanoid = humanoid
    track.pace = pace
    track.distance = distance
    table.insert(due, track)
end

local function reserveVoice(now)
    for _, voice in ipairs(voices) do
        if voice.busyUntil <= now then return voice end
    end
    if #voices >= MAX_VOICES then return nil end
    local emitter = Instance.new("Attachment")
    emitter.Name = "IronYardOpponentFootstep"
    emitter.Parent = workspace.Terrain
    local voice = ContactAudio.createVoice("Footstep", emitter, mix)
    voice.emitter = emitter
    voice.sound.RollOffMode = Enum.RollOffMode.Linear
    voice.sound.RollOffMinDistance = 6
    table.insert(voices, voice)
    return voice
end

local function emit(track, eye, range, now)
    local root, humanoid = track.root, track.humanoid
    local groundReach = root.Size.Y * 0.5 + humanoid.HipHeight + 0.65
    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        local leg = root.Parent:FindFirstChild("Left Leg")
        groundReach += leg and leg:IsA("BasePart") and leg.Size.Y or 2
    end
    local side = track.right and 0.35 or -0.35
    local foot = track.position + root.CFrame.RightVector * side
    local floor = workspace:Raycast(foot, Vector3.new(0, -groundReach, 0), rays)
    if not floor or floor.Material == Enum.Material.Water or floor.Normal.Y < 0.55 then return end

    local voice = reserveVoice(now)
    if not voice then return end
    local position = floor.Position + FOOT_LIFT
    local cover = workspace:Raycast(eye, position - eye, rays)
    local muffled = cover ~= nil
    voice.emitter.WorldPosition = position
    voice.sound.RollOffMaxDistance = range
    voice.busyUntil = now + VOICE_SECONDS
    local volume = (0.19 + 0.13 * track.pace) * (muffled and 0.28 or 1)
    ContactAudio.play(voice, floor.Material.Name, volume,
        track.right and 1.03 or 0.97, muffled and -16 or 0)
end

local lastSampleAt = -math.huge
local lastHumanoid, lastEpoch
local function reset()
    table.clear(tracks)
    table.clear(due)
    table.clear(exclude)
    rays.FilterDescendantsInstances = exclude
    for _, voice in ipairs(voices) do
        voice.sound:Stop()
        voice.busyUntil = -math.huge
    end
end

local function updateVolume()
    local percent = player:GetAttribute(FOOTSTEP_VOLUME_ATTRIBUTE)
    local gain = type(percent) == "number" and percent == percent and math.clamp(percent / 100, 0, 1) or 1
    mix.Volume = gain
    if gain == 0 then reset() end
end

player:GetAttributeChangedSignal(FOOTSTEP_VOLUME_ATTRIBUTE):Connect(updateVolume)
updateVolume()

local function closer(a, b)
    return a.distance < b.distance
end

RunService.Heartbeat:Connect(function()
    if mix.Volume == 0 then return end
    local now = os.clock()
    local elapsed = now - lastSampleAt
    if elapsed < SAMPLE_SECONDS then return end
    lastSampleAt = now

    local camera = workspace.CurrentCamera
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local duel = workspace:GetAttribute("IronYardMatchMode") == "DUEL"
    local side = duel and DuelReadout.sideIn(workspace, player.UserId)
    local fireEpoch = workspace:GetAttribute("IronYardFireEpoch")
    local listening = workspace:GetAttribute("NeonMatchPhase") == "LIVE"
        and humanoid and humanoid.Health > 0 and camera
        and camera.CameraType == Enum.CameraType.Custom and camera.CameraSubject == humanoid
        and (not duel or side and character:GetAttribute("IronYardLiveDuelEpoch") == fireEpoch)
    local listener = listening and humanoid or nil
    local epoch = fireEpoch
    if listener ~= lastHumanoid or epoch ~= lastEpoch then
        reset()
        lastHumanoid, lastEpoch = listener, epoch
    end
    if not listener then return end

    local eco = player:GetAttribute("IronYardGraphicsPreset") == "ECO"
    local range = eco and 34 or (mobile and 44 or 54)
    local eye = camera.CFrame.Position
    table.clear(due)
    table.clear(exclude)
    table.insert(exclude, camera)
    for _, participant in ipairs(Players:GetPlayers()) do
        local rig = participant.Character
        if rig then
            table.insert(exclude, rig)
            local opponentSide = duel and DuelReadout.sideIn(workspace, participant.UserId)
            if participant ~= player and (not duel or opponentSide and opponentSide ~= side
                and rig:GetAttribute("IronYardLiveDuelEpoch") == fireEpoch) then
                sample(rig, eye, range, now, elapsed)
            end
        end
    end
    local bots = workspace:FindFirstChild("NeonStrikeBots")
    if bots then
        table.insert(exclude, bots)
        if not duel then
            for _, rig in ipairs(bots:GetChildren()) do
                if rig:IsA("Model") then sample(rig, eye, range, now, elapsed) end
            end
        end
    end
    for rig, track in pairs(tracks) do
        if track.seenAt ~= now then tracks[rig] = nil end
    end
    if #due == 0 then return end
    table.sort(due, closer)
    rays.FilterDescendantsInstances = exclude
    local stepBudget = eco and 1 or 2
    for i = 1, math.min(#due, stepBudget) do
        emit(due[i], eye, range, now)
    end
end)
