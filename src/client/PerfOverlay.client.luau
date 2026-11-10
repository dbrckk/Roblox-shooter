-- IRON YARD / discreet opt-in profiling tool for owner and Studio only.
-- Hidden for the public, including all ordinary Android players.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

if not RunService:IsStudio() and not (
    game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0
    and player.UserId == game.CreatorId) then return end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PrecisionNet = require(Shared:WaitForChild("PrecisionNet"))
local FrameWindow = require(Shared:WaitForChild("ClientFrameWindow"))
local remote = PrecisionNet.getRemotes(false).PerformanceDiagnostics

local gui = Instance.new("ScreenGui")
gui.Name = "IronYardPrivatePerformance"
gui.IgnoreGuiInset = false
gui.DisplayOrder = 80
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local toggle = Instance.new("TextButton")
toggle.Name = "PerfToggle"
toggle.Size = UDim2.fromOffset(57, 28)
toggle.Position = UDim2.fromOffset(12, 66)
toggle.BackgroundColor3 = Color3.fromRGB(35, 45, 47)
toggle.TextColor3 = Color3.fromRGB(245, 225, 170)
toggle.BorderSizePixel = 0
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 13
toggle.Text = "PERF"
toggle.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PerformancePanel"
panel.Visible = false
panel.Size = UDim2.fromOffset(272, 279)
panel.Position = UDim2.fromOffset(12, 100)
panel.BackgroundColor3 = Color3.fromRGB(21, 29, 33)
panel.BackgroundTransparency = 0.07
panel.BorderSizePixel = 0
panel.Parent = gui

local label = Instance.new("TextLabel")
label.Name = "Diagnostics"
label.BackgroundTransparency = 1
label.Position = UDim2.fromOffset(10, 8)
label.Size = UDim2.new(1, -18, 1, -14)
label.TextColor3 = Color3.fromRGB(223, 231, 219)
label.Font = Enum.Font.Code
label.TextSize = 13
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.TextWrapped = false
label.Text = "IRON YARD / DIAGNOSTICS\nActivation en cours..."
label.Parent = panel

local active = false
local lastPacket = nil
local frameWindow = FrameWindow.new()
local frameSeconds = 0
local latestFrameStats = nil

local function updateLabel()
    if not active then return end
    local p = lastPacket
    if not p or not p.rates or not p.timings then
        label.Text = "IRON YARD / DIAGNOSTICS\nCollecte des mesures..."
        return
    end
    local r, t = p.rates, p.timings
    local frames = latestFrameStats
    local fps = frames and frames.fps or 0
    local framePeak = frames and frames.peakMs or 0
    local p95 = frames and frames.p95Ms or 0
    local p99 = frames and frames.p99Ms or 0
    local slow = frames and frames.slow33 or 0
    local samples = frames and frames.count or 0
    local rays = (r.targetRay or 0) + (r.navRay or 0)
        + (r.tacticsRay or 0) + (r.muzzleRay or 0) + (r.shotRay or 0)
    local think = t.thinkMs or {}
    local pose = t.poseMs or {}
    local path = t.pathMs or {}
    label.Text = string.format(
        "IRON YARD / PRIVATE PROFILER\n"
        .. "FPS client: %4.0f   pic: %.0fms\n"
        .. "P95: %.0fms  P99: %.0fms\n"
        .. ">33ms: %d / %d images\n"
        .. "Bots actifs: %d\n"
        .. "Raycasts IA: %.1f/s\n"
        .. "  vision %.1f | nav %.1f\n"
        .. "  tact %.1f | tirs %.1f\n"
        .. "Navmesh: %.1f/s | diff %.1f/s\n"
        .. "Path ms: %.1f avg / %.1f pic\n"
        .. "MoveTo: %.1f/s\n"
        .. "IA ms: %.1f avg / %.1f pic\n"
        .. "Pose ms: %.1f avg / %.1f pic\n"
        .. "Pose: %.1f/s | Feu: %.1f/s",
        fps, framePeak, p95, p99, slow, samples,
        p.bots or 0, rays,
        r.targetRay or 0, r.navRay or 0,
        r.tacticsRay or 0, (r.muzzleRay or 0) + (r.shotRay or 0),
        r.pathStarted or 0, r.pathDeferred or 0,
        path.mean or 0, path.peak or 0,
        r.moveIssued or 0,
        think.mean or 0, think.peak or 0,
        pose.mean or 0, pose.peak or 0,
        r.pose or 0, r.botShot or 0)
end

remote.OnClientEvent:Connect(function(packet)
    if not active or typeof(packet) ~= "table" then return end
    if packet.status == "OFF" then
        active = false
        panel.Visible = false
        toggle.Text = "PERF"
        return
    end
    if packet.status == "ON" and packet.rates then
        lastPacket = packet
        updateLabel()
    end
end)

toggle.Activated:Connect(function()
    active = not active
    panel.Visible = active
    toggle.Text = active and "CLOSE" or "PERF"
    if active then
        lastPacket = nil
        FrameWindow.clear(frameWindow)
        latestFrameStats = nil
        frameSeconds = 0
        updateLabel()
    end
    remote:FireServer(active and "start" or "stop")
end)

RunService.RenderStepped:Connect(function(dt)
    if not active then return end
    if not FrameWindow.push(frameWindow, dt) then return end
    frameSeconds += dt
    if frameSeconds >= 1.0 then
        latestFrameStats = FrameWindow.snapshot(frameWindow)
        frameSeconds %= 1.0
        updateLabel()
    end
end)
