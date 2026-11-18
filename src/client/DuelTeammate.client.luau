-- 2v2 presentation only. The server owns teams, original rigs and damage.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local highlight = Instance.new("Highlight")
highlight.Name = "DuelTeammate"
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.FillColor = Color3.fromRGB(120, 221, 205)
highlight.FillTransparency = 0.82
highlight.OutlineColor = highlight.FillColor
highlight.OutlineTransparency = 0.18
highlight.Enabled = false
highlight.Parent = Workspace

local SIDES = {"A", "B"}
local spectated
local ownsCamera = false
local elapsed = 0
local function liveRig(operator, epoch)
    local character = operator and operator.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if type(epoch) == "number" and humanoid and humanoid.Health > 0
        and character:GetAttribute("IronYardLiveDuelEpoch") == epoch then
        return character, humanoid
    end
    return nil, nil
end

RunService.Heartbeat:Connect(function(delta)
    elapsed += delta
    if elapsed < 0.12 then return end
    elapsed = 0

    local active = Workspace:GetAttribute("IronYardDuelSize") == 4
        and Workspace:GetAttribute("NeonMatchPhase") == "LIVE"
    if not active and not ownsCamera and not highlight.Enabled then return end
    local camera = Workspace.CurrentCamera
    local myHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local allyRig, allyHumanoid
    local ownRig
    if active then
        local allyId
        for _, side in ipairs(SIDES) do
            local captain = Workspace:GetAttribute("IronYardDuelPlayer" .. side)
            local partner = Workspace:GetAttribute("IronYardDuelPlayer" .. side .. "2")
            if player.UserId == captain then allyId = partner
            elseif player.UserId == partner then allyId = captain end
        end
        local epoch = Workspace:GetAttribute("IronYardFireEpoch")
        ownRig = liveRig(player, epoch)
        local ally = type(allyId) == "number" and allyId > 0 and Players:GetPlayerByUserId(allyId)
        allyRig, allyHumanoid = liveRig(ally, epoch)
    end
    local visibleRig = ownRig and allyRig or nil
    if highlight.Adornee ~= visibleRig then
        highlight.Adornee = visibleRig
        highlight.Enabled = visibleRig ~= nil
    end

    local follow = not ownRig and allyHumanoid or nil
    if follow and camera and camera.CameraType == Enum.CameraType.Custom then
        if camera.CameraSubject ~= follow then camera.CameraSubject = follow end
        spectated = follow
        if not ownsCamera then
            ownsCamera = true
            playerGui:SetAttribute("IronYardSpectating", true)
        end
    elseif ownsCamera then
        if camera and camera.CameraSubject == spectated and myHumanoid then
            camera.CameraSubject = myHumanoid
        end
        spectated = nil
        ownsCamera = false
        playerGui:SetAttribute("IronYardSpectating", false)
    end
end)
