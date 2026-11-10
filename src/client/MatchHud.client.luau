-- IRON YARD - competitive match scoreboard.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local remotes = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("PrecisionNet")).getRemotes(false)
local DuelReadout = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("DuelReadout"))
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
top.Size = UDim2.new(0.9, 0, 0, 80)
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(340, 80)
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

-- Ten reusable, non-interactive score indicators (five wins per side).
-- No RenderStepped loop, network events or creation during match updates.
local duelProgress = Instance.new("Frame")
duelProgress.Name = "DuelProgress"
duelProgress.Position = UDim2.new(0, 12, 1, -15)
duelProgress.Size = UDim2.new(1, -24, 0, 7)
duelProgress.BackgroundTransparency = 1
duelProgress.Visible = false
duelProgress.Parent = top

local myRoundBars, rivalRoundBars = {}, {}
local EMPTY_ROUND = Color3.fromRGB(65, 72, 73)
local MY_ROUND = Color3.fromRGB(231, 182, 97)
local RIVAL_ROUND = Color3.fromRGB(118, 158, 169)
for i = 1, 5 do
    for _, side in ipairs({
        { bars = myRoundBars, startX = 0, active = MY_ROUND },
        { bars = rivalRoundBars, startX = 0.54, active = RIVAL_ROUND },
    }) do
        local bar = Instance.new("Frame")
        bar.Name = (side.bars == myRoundBars and "My" or "Rival") .. "Win" .. i
        bar.Position = UDim2.new(side.startX + (i - 1) * 0.46 / 5, 0, 0, 0)
        bar.Size = UDim2.new(0.46 / 5, -3, 1, 0)
        bar.BackgroundColor3 = EMPTY_ROUND
        bar.BorderSizePixel = 0
        bar.Parent = duelProgress
        local roundCorner = Instance.new("UICorner")
        roundCorner.CornerRadius = UDim.new(1, 0)
        roundCorner.Parent = bar
        table.insert(side.bars, { part = bar, active = side.active })
    end
end

local function updateDuelProgress(mode, phase, myWins, rivalWins)
    local shown = mode == "DUEL" and phase ~= "WAITING"
        and phase ~= "COUNTDOWN" and myWins ~= nil and rivalWins ~= nil
    duelProgress.Visible = shown
    if not shown then return end
    for index, entry in ipairs(myRoundBars) do
        local color = index <= myWins and entry.active or EMPTY_ROUND
        if entry.part.BackgroundColor3 ~= color then entry.part.BackgroundColor3 = color end
    end
    for index, entry in ipairs(rivalRoundBars) do
        local color = index <= rivalWins and entry.active or EMPTY_ROUND
        if entry.part.BackgroundColor3 ~= color then entry.part.BackgroundColor3 = color end
    end
end

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
    -- Never overlay the action HUD with an unavailable 1v1 option.
    duelToggle.Visible = humans <= 2
        and (mode ~= "DUEL" or phase == "RESULTS")
        and playerGui:GetAttribute("IronYardBriefingOpen") ~= true
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

-- A single reusable, touch-safe introduction layer. Only state changes
-- schedule a short tween; no per-frame allocations or additional remotes.
local duelIntro = Instance.new("Frame")
duelIntro.Name = "DuelIntro"
duelIntro.AnchorPoint = Vector2.new(0.5, 0.5)
duelIntro.Position = UDim2.fromScale(0.5, 0.36)
duelIntro.Size = UDim2.new(0.72, 0, 0, 162)
duelIntro.BackgroundColor3 = Color3.fromRGB(24, 30, 32)
duelIntro.BackgroundTransparency = 0.1
duelIntro.BorderSizePixel = 0
duelIntro.Active = false
duelIntro.Visible = false
duelIntro.Parent = gui
local introSize = Instance.new("UISizeConstraint")
introSize.MaxSize = Vector2.new(350, 162)
introSize.MinSize = Vector2.new(180, 135)
introSize.Parent = duelIntro
local introCorner = Instance.new("UICorner")
introCorner.CornerRadius = UDim.new(0, 14)
introCorner.Parent = duelIntro
local introStroke = Instance.new("UIStroke")
introStroke.Color = Color3.fromRGB(216, 167, 94)
introStroke.Thickness = 2
introStroke.Transparency = 0.12
introStroke.Parent = duelIntro
local introGradient = Instance.new("UIGradient")
introGradient.Rotation = 110
introGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 52, 52)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(17, 23, 26)),
})
introGradient.Parent = duelIntro
local function introText(name, y, h, size, color)
    local t = Instance.new("TextLabel")
    t.Name = name
    t.Position = UDim2.new(0, 8, 0, y)
    t.Size = UDim2.new(1, -16, 0, h)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBlack
    t.TextColor3 = color
    t.TextSize = size
    t.TextXAlignment = Enum.TextXAlignment.Center
    t.Parent = duelIntro
    return t
end
local introTitle = introText("Title", 12, 25, 16, Color3.fromRGB(219, 170, 102))
introTitle.Text = "IRON YARD  /  DUEL"
local introNumber = introText("Countdown", 35, 94, 78, Color3.fromRGB(250, 244, 229))
introNumber.TextStrokeTransparency = 0.65
local introFooter = introText("Footer", 133, 20, 12, Color3.fromRGB(188, 200, 198))
introFooter.Text = "FIRST TO FIVE  ·  EQUAL START"
local introTween = nil
local lastIntroSecond = nil
local function updateIntro(phase, seconds, duelMode)
    local shown = duelMode == "DUEL" and phase == "DUEL_PREP"
    duelIntro.Visible = shown
    if not shown then
        lastIntroSecond = nil
        if introTween then introTween:Cancel() introTween = nil end
        return
    end
    local nextSecond = math.clamp(math.floor(seconds), 1, 3)
    if nextSecond == lastIntroSecond then return end
    lastIntroSecond = nextSecond
    if introTween then introTween:Cancel() end
    introNumber.Text = tostring(nextSecond)
    introNumber.TextSize = 108
    introNumber.TextTransparency = 0.20
    introTween = TweenService:Create(introNumber,
        TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { TextSize = 78, TextTransparency = 0 })
    introTween:Play()
end

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
    local duelAId = Workspace:GetAttribute("IronYardDuelPlayerA")
    local duelBId = Workspace:GetAttribute("IronYardDuelPlayerB")
    local myWins, rivalWins = DuelReadout.scores(player.UserId,
        duelAId, duelBId, duelScoreA, duelScoreB)
    local lastDuelResult = Workspace:GetAttribute("IronYardDuelLastResult")
    local boutLabel = DuelReadout.boutLabel(lastDuelResult,
        player.UserId, duelAId, duelBId)
    local kills = eliminations and eliminations.Value or 0
    local clock = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)

    local headerText, detailText
    if matchMode == "DUEL" and phase ~= "COUNTDOWN" and phase ~= "WAITING" then
        local score = myWins and string.format("YOU %d : %d RIVAL", myWins, rivalWins)
            or string.format("A %d : %d B", duelScoreA, duelScoreB)
        if phase == "LIVE" then
            headerText = string.format("DUEL %d  |  %s", duelBout, clock)
            detailText = "FIRST TO 5   /   " .. score
        elseif phase == "DUEL_PREP" then
            headerText = string.format("DUEL  |  ROUND %d", duelBout + 1)
            detailText = string.format("PREPARE  /  %ds   ·   %s", seconds, score)
        elseif phase == "DUEL_BREAK" then
            headerText = string.format("%s  |  NEXT IN %ds",
                boutLabel or "DUEL", seconds)
            detailText = score
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
    updateDuelProgress(matchMode, phase, myWins, rivalWins)
    updateIntro(phase, seconds, matchMode)
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

playerGui:GetAttributeChangedSignal("IronYardBriefingOpen"):Connect(function()
    update()
    duelLabel()
end)
for _, name in ipairs({
    "NeonMatchPhase", "NeonMatchRound", "NeonMatchTimeLeft",
    "NeonMatchWinner", "NeonMatchScoreLimit", "NeonBotCount",
    "IronYardMatchMode", "IronYardDuelReadyCount",
    "IronYardDuelBout", "IronYardDuelScoreA", "IronYardDuelScoreB",
    "IronYardDuelPlayerA", "IronYardDuelPlayerB", "IronYardDuelLastResult",
}) do
    Workspace:GetAttributeChangedSignal(name):Connect(function()
        update()
        duelLabel()
    end)
end
duelLabel()
update()
