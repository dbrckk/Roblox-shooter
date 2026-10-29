-- IRON YARD / cinematic but lightweight FFA results card.
-- Every score, personal medal XP and winning identity comes from the server.
-- All frames are client-only and disappear outside RESULTS.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "IronYardRoundResults"
gui.DisplayOrder = 30
gui.IgnoreGuiInset = false
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Name = "ResultsCard"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.49)
root.Size = UDim2.fromOffset(434, 337)
root.BackgroundColor3 = Color3.fromRGB(30, 37, 37)
root.BackgroundTransparency = 0.05
root.BorderSizePixel = 0
root.Visible = false
root.Parent = gui

local scale = Instance.new("UIScale")
scale.Parent = root
local radius = Instance.new("UICorner")
radius.CornerRadius = UDim.new(0, 12)
radius.Parent = root
local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(211, 167, 97)
border.Thickness = 1.7
border.Transparency = 0.10
border.Parent = root

local stripe = Instance.new("Frame")
stripe.Name = "AmberRule"
stripe.BackgroundColor3 = Color3.fromRGB(209, 151, 81)
stripe.BorderSizePixel = 0
stripe.Position = UDim2.fromOffset(18, 61)
stripe.Size = UDim2.new(1, -36, 0, 2)
stripe.Parent = root

local function label(name, textSize, pos, size, color, align)
    local entry = Instance.new("TextLabel")
    entry.Name = name
    entry.Position = pos
    entry.Size = size
    entry.BackgroundTransparency = 1
    entry.Font = Enum.Font.GothamBold
    entry.TextColor3 = color
    entry.TextSize = textSize
    entry.TextTruncate = Enum.TextTruncate.AtEnd
    entry.TextXAlignment = align or Enum.TextXAlignment.Center
    entry.Text = ""
    entry.Parent = root
    return entry
end

local bone = Color3.fromRGB(244, 239, 223)
local muted = Color3.fromRGB(177, 185, 176)
local amber = Color3.fromRGB(233, 185, 104)
local green = Color3.fromRGB(139, 205, 155)

local title = label("ResultTitle", 24, UDim2.fromOffset(14, 14),
    UDim2.new(1, -28, 0, 38), amber)
local winnerLabel = label("Winner", 12, UDim2.fromOffset(16, 68),
    UDim2.new(1, -32, 0, 24), bone)
local personalLabel = label("MyResults", 14, UDim2.fromOffset(16, 99),
    UDim2.new(1, -32, 0, 29), bone)
local xpLabel = label("EarnedXP", 13, UDim2.fromOffset(16, 131),
    UDim2.new(1, -32, 0, 24), amber)
local progressLabel = label("Rank", 11, UDim2.fromOffset(16, 158),
    UDim2.new(1, -32, 0, 22), muted)

local track = Instance.new("Frame")
track.Name = "CareerProgressTrack"
track.Position = UDim2.fromOffset(37, 186)
track.Size = UDim2.new(1, -74, 0, 7)
track.BackgroundColor3 = Color3.fromRGB(68, 77, 74)
track.BorderSizePixel = 0
track.Parent = root
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track
local fill = Instance.new("Frame")
fill.Name = "CareerProgressFill"
fill.Size = UDim2.fromScale(0, 1)
fill.BorderSizePixel = 0
fill.BackgroundColor3 = amber
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local leaderboard = {}
for rank = 1, 3 do
    leaderboard[rank] = label("Leaderboard" .. rank, 12,
        UDim2.fromOffset(27, 200 + rank * 27), UDim2.new(1, -54, 0, 23),
        rank == 1 and amber or muted)
end
local countdown = label("NextRound", 11,
    UDim2.fromOffset(16, 315), UDim2.new(1, -32, 0, 16), muted)

local function safeCount(attr)
    local value = player:GetAttribute(attr)
    return typeof(value) == "number" and math.max(0, math.floor(value)) or 0
end

local function scoreValue(name)
    local stats = player:FindFirstChild("leaderstats")
    local stat = stats and stats:FindFirstChild(name)
    return stat and stat:IsA("IntValue") and math.max(0, stat.Value) or 0
end

local function standings()
    local result = {}
    local raw = Workspace:GetAttribute("IronYardStandings")
    if typeof(raw) == "string" then
        local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and typeof(parsed) == "table" then result = parsed end
    end
    return result
end

local function updateLayout()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    scale.Scale = math.clamp(math.min(viewport.X / 470, viewport.Y / 370), 0.54, 1)
end

local function render()
    if Workspace:GetAttribute("NeonMatchPhase") ~= "RESULTS" then
        root.Visible = false
        return
    end
    local owner = Workspace:GetAttribute("IronYardWinnerUserId") or 0
    local isWinner = owner ~= 0 and owner == player.UserId
    local winner = Workspace:GetAttribute("NeonMatchWinner") or "DRAW"
    local round = Workspace:GetAttribute("NeonMatchRound") or 0
    local seconds = Workspace:GetAttribute("NeonMatchTimeLeft") or 0
    local xp = safeCount("IronYardLifetimeXP")
    local level = math.max(1, safeCount("IronYardProgressLevel"))
    local nextXP = 250 * level * level
    local baseXP = 250 * (level - 1) * (level - 1)

    title.Text = isWinner and "VICTORY" or ("ROUND " .. tostring(round) .. " COMPLETE")
    title.TextColor3 = isWinner and green or amber
    winnerLabel.Text = winner == "DRAW" and "MATCH DRAW"
        or ("WINNER  /  " .. string.sub(tostring(winner), 1, 30))
    personalLabel.Text = string.format("YOU   /   %d ELIMS   ·   %d DEATHS",
        scoreValue("Eliminations"), scoreValue("Deaths"))
    xpLabel.Text = string.format("+%d ROUND XP     /     %d CAREER XP",
        safeCount("IronYardRoundXP"), xp)
    progressLabel.Text = string.format("RANK %d  |  NEXT %d XP", level, nextXP)
    fill.Size = UDim2.fromScale(level >= 1000 and 1
        or math.clamp((xp - baseXP) / math.max(1, nextXP - baseXP), 0, 1), 1)

    local top = standings()
    for i = 1, 3 do
        local row = top[i]
        if typeof(row) == "table" then
            local name = string.sub(tostring(row.name or "Operator"), 1, 23)
            local score = math.max(0, math.floor(tonumber(row.eliminations) or 0))
            leaderboard[i].Text = string.format("%d     %s     ·     %d ELIMS", i, name, score)
        else
            leaderboard[i].Text = string.format("%d     ---", i)
        end
    end
    countdown.Text = string.format("NEXT ROUND IN %ds", math.max(0, seconds))
    root.Visible = true
end

local cameraConnection
local function reconnectCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera = Workspace.CurrentCamera
    if camera then
        cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
    end
    updateLayout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(reconnectCamera)
reconnectCamera()

for _, attr in ipairs({
    "NeonMatchPhase", "NeonMatchWinner", "NeonMatchRound",
    "NeonMatchTimeLeft", "IronYardWinnerUserId", "IronYardStandings",
}) do
    Workspace:GetAttributeChangedSignal(attr):Connect(render)
end
for _, attr in ipairs({
    "IronYardLifetimeXP", "IronYardProgressLevel", "IronYardRoundXP",
}) do
    player:GetAttributeChangedSignal(attr):Connect(render)
end

local function bindStats(stats)
    for _, name in ipairs({"Eliminations", "Deaths"}) do
        local value = stats:FindFirstChild(name)
        if value and value:IsA("IntValue") then
            value:GetPropertyChangedSignal("Value"):Connect(render)
        end
    end
end
player.ChildAdded:Connect(function(child)
    if child.Name == "leaderstats" then bindStats(child) end
end)
if player:FindFirstChild("leaderstats") then
    bindStats(player.leaderstats)
end
render()
