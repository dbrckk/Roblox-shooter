-- IRON YARD - competitive match scoreboard.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "NeonStrikeMatchHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local top = Instance.new("Frame")
top.Name = "MatchPanel"
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 8)
top.Size = UDim2.new(0.9, 0, 0, 70)
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(340, 70)
sizeConstraint.Parent = top
top.BackgroundColor3 = Color3.fromRGB(37, 43, 43)
top.BackgroundTransparency = 0.15
top.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = top

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(214, 164, 82)
stroke.Thickness = 1.4
stroke.Transparency = 0.25
stroke.Parent = top

local function label(name, textSize, size, pos, color)
    local t = Instance.new("TextLabel")
    t.Name = name
    t.Size = size
    t.Position = pos
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = textSize
    t.TextColor3 = color
    t.TextXAlignment = Enum.TextXAlignment.Center
    t.Text = ""
    t.Parent = top
    return t
end

local header = label("Status", 16, UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 5), Color3.fromRGB(244, 217, 170))
local detail = label("Score", 12, UDim2.new(1, -12, 0, 27), UDim2.fromOffset(6, 34), Color3.fromRGB(248, 248, 241))

local eliminations = nil
local function update()
    local phase = Workspace:GetAttribute("NeonMatchPhase") or "WAITING"
    local count = Workspace:GetAttribute("NeonMatchRound") or 0
    local seconds = Workspace:GetAttribute("NeonMatchTimeLeft") or 0
    local target = Workspace:GetAttribute("NeonMatchScoreLimit") or 15
    local botCount = Workspace:GetAttribute("NeonBotCount") or 0
    local kills = eliminations and eliminations.Value or 0
    local clock = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)

    if phase == "WAITING" then
        header.Text = "IRON YARD  |  FREIGHT TERMINAL"
        detail.Text = "WAITING FOR OPERATORS"
    elseif phase == "COUNTDOWN" then
        header.Text = string.format("ROUND %d  |  STARTING", count + 1)
        detail.Text = string.format("FIRST TO %d ELIMINATIONS   /   %ds", target, seconds)
    elseif phase == "LIVE" then
        header.Text = string.format("ROUND %d  |  %s", count, clock)
        local character = player.Character
        local shieldEnd = character and character:GetAttribute("NeonSpawnProtectedUntil") or 0
        local secondsOfShield = math.max(0, math.ceil(shieldEnd - Workspace:GetServerTimeNow()))
        local suffix = secondsOfShield > 0 and ("  |  SHIELD " .. secondsOfShield .. "s") or ""
        detail.Text = string.format("KILLS %d/%d   |   %d BOTS", kills, target, botCount) .. suffix
    else
        header.Text = "ROUND FINISHED"
        local who = Workspace:GetAttribute("NeonMatchWinner") or "DRAW"
        detail.Text = (who == "DRAW" and "DRAW" or "WINNER: " .. who) .. "  |  " .. clock
    end
end

local function connectStats(stats)
    local kills = stats:FindFirstChild("Eliminations") or stats:WaitForChild("Eliminations", 10)
    if kills then
        eliminations = kills
        kills:GetPropertyChangedSignal("Value"):Connect(update)
        update()
    end
end

local existing = player:FindFirstChild("leaderstats")
if existing then task.defer(connectStats, existing) end
player.ChildAdded:Connect(function(child)
    if child.Name == "leaderstats" then
        connectStats(child)
    end
end)

for _, name in ipairs({ "NeonMatchPhase", "NeonMatchRound", "NeonMatchTimeLeft", "NeonMatchWinner", "NeonMatchScoreLimit", "NeonBotCount" }) do
    Workspace:GetAttributeChangedSignal(name):Connect(update)
end
update()
