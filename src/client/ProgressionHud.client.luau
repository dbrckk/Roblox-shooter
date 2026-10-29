-- IRON YARD / unobtrusive lifetime-rank presentation.
-- Only replicated server attributes are read; no client stat mutations.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OperatorFinishes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OperatorFinishes"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local existing = playerGui:FindFirstChild("IronYardProgression")
if existing then existing:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "IronYardProgression"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 15
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Career"
panel.Size = UDim2.fromOffset(205, 96)
panel.Position = UDim2.fromOffset(12, 291)
panel.BackgroundColor3 = Color3.fromRGB(37, 43, 43)
panel.BackgroundTransparency = 0.10
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 7)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(78, 86, 81)
stroke.Thickness = 1
stroke.Transparency = 0.25
stroke.Parent = panel

local scale = Instance.new("UIScale")
scale.Parent = panel

local function label(name, offset, size, fontSize, color)
    local text = Instance.new("TextLabel")
    text.Name = name
    text.Position = offset
    text.Size = size
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextSize = fontSize
    text.TextTruncate = Enum.TextTruncate.AtEnd
    text.TextColor3 = color
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Text = ""
    text.Parent = panel
    return text
end

local title = label("Rank", UDim2.fromOffset(10, 5), UDim2.fromOffset(185, 20),
    12, Color3.fromRGB(231, 209, 162))
local details = label("Stats", UDim2.fromOffset(10, 27), UDim2.fromOffset(185, 19),
    10, Color3.fromRGB(233, 231, 217))
local statusLabel = label("Status", UDim2.fromOffset(10, 48), UDim2.fromOffset(185, 13),
    9, Color3.fromRGB(173, 182, 170))

local finishLabel = label("CareerFinish", UDim2.fromOffset(10, 63),
    UDim2.fromOffset(185, 15), 10, Color3.fromRGB(230, 199, 144))

local track = Instance.new("Frame")
track.Name = "RankXPTrack"
track.Position = UDim2.fromOffset(10, 83)
track.Size = UDim2.fromOffset(185, 6)
track.BorderSizePixel = 0
track.BackgroundColor3 = Color3.fromRGB(68, 75, 69)
track.Parent = panel
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track
local fill = Instance.new("Frame")
fill.Name = "RankXPFill"
fill.Size = UDim2.fromScale(0, 1)
fill.BorderSizePixel = 0
fill.BackgroundColor3 = Color3.fromRGB(219, 176, 95)
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local function safeCount(attribute)
    local value = player:GetAttribute(attribute)
    if typeof(value) ~= "number" then return 0 end
    return math.max(0, math.floor(value))
end

local function update()
    local status = player:GetAttribute("IronYardProgressStatus") or "LOADING"
    local xp = safeCount("IronYardLifetimeXP")
    local level = math.max(1, safeCount("IronYardProgressLevel"))
    local kills = safeCount("IronYardLifetimeEliminations")
    local wins = safeCount("IronYardLifetimeVictories")
    local finish = OperatorFinishes.forLevel(level)
    local nextFinish = OperatorFinishes.nextUnlock(level)
    finishLabel.Text = nextFinish
        and (finish.name .. "  /  NEXT LV " .. tostring(nextFinish.level))
        or (finish.name .. "  /  MAX FINISH")
    finishLabel.TextColor3 = Color3.fromRGB(
        finish.accent[1], finish.accent[2], finish.accent[3])
    local nextLevel = 250 * level * level
    local currentLevelXP = 250 * (level - 1) * (level - 1)
    fill.Size = UDim2.fromScale(level >= 1000 and 1
        or math.clamp((xp - currentLevelXP) / math.max(1, nextLevel - currentLevelXP), 0, 1), 1)

    title.Text = string.format("RANK %d    |    %d XP", level, xp)
    if level < 1000 then
        details.Text = string.format("%d KILLS   /   %d WINS   /   NEXT %d", kills, wins, nextLevel)
    else
        details.Text = string.format("%d KILLS   /   %d WINS   /   MAX RANK", kills, wins)
    end
    if status == "ONLINE" then
        statusLabel.Text = "CAREER / AUTO-SAVE"
        statusLabel.TextColor3 = Color3.fromRGB(142, 201, 147)
    elseif status == "LOADING" then
        statusLabel.Text = "CAREER / LOADING..."
        statusLabel.TextColor3 = Color3.fromRGB(229, 190, 112)
    elseif status == "STUDIO" then
        statusLabel.Text = "STUDIO / SESSION ONLY"
        statusLabel.TextColor3 = Color3.fromRGB(229, 190, 112)
    elseif status == "LOCKED" then
        statusLabel.Text = "SAVE BUSY / RETRYING"
        statusLabel.TextColor3 = Color3.fromRGB(244, 154, 104)
    else
        statusLabel.Text = "SAVE NOT CONFIRMED / RETRYING"
        statusLabel.TextColor3 = Color3.fromRGB(244, 154, 104)
    end
    panel.Visible = playerGui:GetAttribute("IronYardBriefingOpen") ~= true
end

local function layout()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local factor = math.clamp(math.min(viewport.X / 1000, viewport.Y / 600), 0.73, 1)
    scale.Scale = factor
    panel.Position = UDim2.fromOffset(12, math.floor(94 + 131 * factor + 52 * factor + 10))
end

local cameraConnection
local function connectCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera = Workspace.CurrentCamera
    if camera then
        cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
    end
    layout()
end

for _, name in ipairs({
    "IronYardProgressStatus", "IronYardLifetimeXP", "IronYardLifetimeEliminations",
    "IronYardLifetimeVictories", "IronYardProgressLevel",
}) do
    player:GetAttributeChangedSignal(name):Connect(update)
end
playerGui:GetAttributeChangedSignal("IronYardBriefingOpen"):Connect(update)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)
connectCamera()
update()
