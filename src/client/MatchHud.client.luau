-- IRON YARD - competitive match scoreboard.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("PrecisionNet")).getRemotes(false)
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "NeonStrikeMatchHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
local playerGui = player:WaitForChild("PlayerGui")
gui.Parent = playerGui

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

-- Public player-facing opt-in. No test or developer controls.
local duelToggle = Instance.new("TextButton")
duelToggle.Name = "DuelOneVsOne"
duelToggle.Position = UDim2.fromOffset(10, 96)
duelToggle.Size = UDim2.fromOffset(140, 36)
duelToggle.BackgroundColor3 = Color3.fromRGB(42, 49, 46)
duelToggle.TextColor3 = Color3.fromRGB(241, 218, 175)
duelToggle.Font = Enum.Font.GothamBold
duelToggle.TextSize = 12
duelToggle.BorderSizePixel = 0
duelToggle.AutoButtonColor = true
duelToggle.Parent = gui
local duelCorner = Instance.new("UICorner")
duelCorner.CornerRadius = UDim.new(0, 9)
duelCorner.Parent = duelToggle
local duelStroke = Instance.new("UIStroke")
duelStroke.Color = Color3.fromRGB(201, 163, 103)
duelStroke.Transparency = 0.35
duelStroke.Thickness = 1
duelStroke.Parent = duelToggle

local function duelLabel()
    local mode = Workspace:GetAttribute("IronYardMatchMode")
    local phase = Workspace:GetAttribute("NeonMatchPhase")
    local humans = #Players:GetPlayers()
    local ready = player:GetAttribute("IronYardDuelReady") == true
    duelToggle.Visible = mode ~= "DUEL" or phase == "RESULTS"
    duelToggle.Active = humans <= 2
    duelToggle.AutoButtonColor = humans <= 2
    duelToggle.Text = humans > 2 and "DUEL / 2 PLAYERS"
        or (ready and "DUEL READY  ✓" or "JOIN 1v1 DUEL")
    duelToggle.BackgroundColor3 = ready
        and Color3.fromRGB(70, 93, 72) or Color3.fromRGB(42, 49, 46)
end
duelToggle.Activated:Connect(function()
    if #Players:GetPlayers() > 2 then return end
    remotes.SetDuelReady:FireServer(player:GetAttribute("IronYardDuelReady") ~= true)
end)
player:GetAttributeChangedSignal("IronYardDuelReady"):Connect(duelLabel)
Players.PlayerAdded:Connect(function() task.defer(duelLabel) end)
Players.PlayerRemoving:Connect(function() task.defer(duelLabel) end)

local eliminations = nil
local statsConnection = nil
local statsGeneration = 0
local function update()
    -- The first-match mission occupies this exact top lane temporarily,
    -- never stack both cards over the mobile weapon selection.
    top.Visible = playerGui:GetAttribute("IronYardBriefingOpen") ~= true
    local phase = Workspace:GetAttribute("NeonMatchPhase") or "WAITING"
    local count = Workspace:GetAttribute("NeonMatchRound") or 0
    local seconds = Workspace:GetAttribute("NeonMatchTimeLeft") or 0
    local target = Workspace:GetAttribute("NeonMatchScoreLimit") or 15
    local botCount = Workspace:GetAttribute("NeonBotCount") or 0
    local matchMode = Workspace:GetAttribute("IronYardMatchMode") or "FFA"
    local readyCount = Workspace:GetAttribute("IronYardDuelReadyCount") or 0
    local duelBout = Workspace:GetAttribute("IronYardDuelBout") or 0
    local duelScoreA = Workspace:GetAttribute("IronYardDuelScoreA") or 0
    local duelScoreB = Workspace:GetAttribute("IronYardDuelScoreB") or 0
    local kills = eliminations and eliminations.Value or 0
    local clock = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)

    local headerText, detailText
    if matchMode == "DUEL" and phase ~= "COUNTDOWN" and phase ~= "WAITING" then
        local score = string.format("%d - %d", duelScoreA, duelScoreB)
        if phase == "LIVE" then
            headerText = string.format("DUEL %d  |  %s", duelBout, clock)
            detailText = "FIRST TO 5 ROUNDS   /   " .. score
        elseif phase == "DUEL_BREAK" then
            headerText = string.format("DUEL  |  NEXT BOUT IN %ds", seconds)
            detailText = "ROUND SCORE   /   " .. score
        else
            headerText = "DUEL FINISHED"
            detailText = (Workspace:GetAttribute("NeonMatchWinner") or "DRAW")
                .. "   /   " .. score
        end
    elseif phase == "WAITING" then
        headerText = "IRON YARD  |  FREIGHT TERMINAL"
        detailText = "WAITING FOR OPERATORS"
    elseif phase == "COUNTDOWN" then
        headerText = string.format("ROUND %d  |  STARTING", count + 1)
        detailText = readyCount == 2 and #Players:GetPlayers() == 2
            and ("1v1 DUEL NEXT  /  " .. seconds .. "s")
            or string.format("FIRST TO %d ELIMINATIONS   /   %ds", target, seconds)
    elseif phase == "LIVE" then
        headerText = string.format("ROUND %d  |  %s", count, clock)
        local character = player.Character
        local shieldEnd = character and character:GetAttribute("NeonSpawnProtectedUntil") or 0
        local secondsOfShield = math.max(0, math.ceil(shieldEnd - Workspace:GetServerTimeNow()))
        local suffix = secondsOfShield > 0 and ("  |  SHIELD " .. secondsOfShield .. "s") or ""
        detailText = string.format("KILLS %d/%d   |   %d BOTS", kills, target, botCount) .. suffix
    else
        headerText = "ROUND FINISHED"
        local who = Workspace:GetAttribute("NeonMatchWinner") or "DRAW"
        detailText = (who == "DRAW" and "DRAW" or "WINNER: " .. who) .. "  |  " .. clock
    end
    -- Server attributes may replicate redundantly. Only dirty text
    -- reaches Roblox UI properties; score/time changes remain immediate.
    if header.Text ~= headerText then header.Text = headerText end
    if detail.Text ~= detailText then detail.Text = detailText end
end

local function connectStats(stats)
    statsGeneration += 1
    local generation = statsGeneration
    if statsConnection then
        statsConnection:Disconnect()
        statsConnection = nil
    end
    eliminations = nil
    local kills = stats:FindFirstChild("Eliminations") or stats:WaitForChild("Eliminations", 10)
    -- A replacement leaderstats may arrive while the old WaitForChild
    -- is yielding. Never bind the obsolete value to the current HUD.
    if generation ~= statsGeneration or stats.Parent ~= player then return end
    if kills then
        eliminations = kills
        statsConnection = kills:GetPropertyChangedSignal("Value"):Connect(update)
    end
    update()
end

local existing = player:FindFirstChild("leaderstats")
if existing then task.defer(connectStats, existing) end
player.ChildAdded:Connect(function(child)
    if child.Name == "leaderstats" then
        connectStats(child)
    end
end)

playerGui:GetAttributeChangedSignal("IronYardBriefingOpen"):Connect(update)
for _, name in ipairs({
    "NeonMatchPhase", "NeonMatchRound", "NeonMatchTimeLeft",
    "NeonMatchWinner", "NeonMatchScoreLimit", "NeonBotCount",
    "IronYardMatchMode", "IronYardDuelReadyCount",
    "IronYardDuelBout", "IronYardDuelScoreA", "IronYardDuelScoreB",
}) do
    Workspace:GetAttributeChangedSignal(name):Connect(function()
        update()
        duelLabel()
    end)
end
duelLabel()
update()
