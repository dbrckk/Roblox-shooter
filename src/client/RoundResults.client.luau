-- IRON YARD / cinematic but lightweight FFA results card.
-- Every score, personal medal XP and winning identity comes from the server.
-- All frames are client-only and disappear outside RESULTS.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildInfo = require(Shared:WaitForChild("BuildInfo"))
local CareerReadout = require(Shared:WaitForChild("CareerReadout"))

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
local progressLabel = label("Rank", 11, UDim2.fromOffset(16, 157),
    UDim2.new(1, -32, 0, 18), muted)
local saveLabel = label("CareerSaveState", 10, UDim2.fromOffset(16, 178),
    UDim2.new(1, -32, 0, 16), muted)

local track = Instance.new("Frame")
track.Name = "CareerProgressTrack"
track.Position = UDim2.fromOffset(37, 200)
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
    return CareerReadout.count(value)
end

local function scoreValue(name)
    local stats = player:FindFirstChild("leaderstats")
    local stat = stats and stats:FindFirstChild(name)
    return stat and stat:IsA("IntValue") and math.max(0, stat.Value) or 0
end

local function finalSnapshot()
    local raw = Workspace:GetAttribute("IronYardFinalStandings")
    if typeof(raw) ~= "string" or raw == "" then return nil end
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and typeof(parsed) == "table" and typeof(parsed.standings) == "table" then
        return parsed
    end
    return nil
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
    local snapshot = finalSnapshot()
    local owner = snapshot and snapshot.winnerUserId
        or Workspace:GetAttribute("IronYardWinnerUserId") or 0
    local isWinner = owner ~= 0 and owner == player.UserId
    local winner = snapshot and snapshot.winner
        or Workspace:GetAttribute("NeonMatchWinner") or "DRAW"
    local round = snapshot and snapshot.round
        or Workspace:GetAttribute("NeonMatchRound") or 0
    local isDuel = snapshot and snapshot.mode == "DUEL"
        or Workspace:GetAttribute("IronYardMatchMode") == "DUEL"
    local seconds = Workspace:GetAttribute("NeonMatchTimeLeft") or 0
    local xp = safeCount("IronYardLifetimeXP")
    local level = math.max(1, safeCount("IronYardProgressLevel"))
    local rankInfo = CareerReadout.rank(xp, level)
    local saveInfo = CareerReadout.save(
        player:GetAttribute("IronYardProgressStatus"), xp,
        safeCount("IronYardSavedXP"))

    title.Text = isDuel and (isWinner and "DUEL VICTORY" or "DUEL COMPLETE")
        or (isWinner and "VICTORY" or ("ROUND " .. tostring(round) .. " COMPLETE"))
    title.TextColor3 = isWinner and green or amber
    winnerLabel.Text = winner == "DRAW" and "MATCH DRAW"
        or ("WINNER  /  " .. string.sub(tostring(winner), 1, 30))
    local myStanding = nil
    local participants = snapshot and #snapshot.standings or 0
    if snapshot then
        for _, entry in ipairs(snapshot.standings) do
            if not entry.bot and entry.userId == player.UserId then
                myStanding = entry
                break
            end
        end
    end
    if myStanding then
        personalLabel.Text = isDuel
            and string.format("YOU  /  #%d OF %d   ·   %d ROUNDS WON",
                myStanding.rank or 0, participants,
                myStanding.eliminations or 0)
            or string.format(
                "YOU  /  #%d OF %d   ·   %d ELIMS   ·   %d DEATHS",
                myStanding.rank or 0, participants,
                myStanding.eliminations or 0, myStanding.deaths or 0)
    elseif snapshot then
        personalLabel.Text = "YOU  /  JOINED BETWEEN ROUNDS"
    else
        personalLabel.Text = string.format("YOU   /   %d ELIMS   ·   %d DEATHS",
            scoreValue("Eliminations"), scoreValue("Deaths"))
    end
    xpLabel.Text = string.format("+%d ROUND XP     /     %d CAREER XP",
        safeCount("IronYardRoundXP"), xp)
    progressLabel.Text = rankInfo.maxed and "RANK 1000  |  MAX RANK"
        or string.format("RANK %d  |  %d XP TO NEXT", rankInfo.rank, rankInfo.toNext)
    saveLabel.Text = saveInfo.label
    saveLabel.TextColor3 = saveInfo.tone == "saved" and green
        or (saveInfo.tone == "pending" and amber or Color3.fromRGB(244, 154, 104))
    fill.Size = UDim2.fromScale(rankInfo.fraction, 1)

    local top = snapshot and snapshot.standings or standings()
    for i = 1, 3 do
        local row = top[i]
        if typeof(row) == "table" then
            local name = string.sub(tostring(row.name or "Operator"), 1, 23)
            local score = math.max(0, math.floor(tonumber(row.eliminations) or 0))
            local placement = math.max(1, math.floor(tonumber(row.rank) or i))
            leaderboard[i].Text = string.format("%d     %s     ·     %d %s",
                placement, name, score, isDuel and "ROUNDS" or "ELIMS")
            leaderboard[i].TextColor3 = not row.bot and row.userId == player.UserId
                and green or (i == 1 and amber or muted)
        else
            leaderboard[i].Text = string.format("%d     ---", i)
            leaderboard[i].TextColor3 = muted
        end
    end
    local build = typeof(BuildInfo.sourceSha) == "string"
        and #BuildInfo.sourceSha == 40 and BuildInfo.short or nil
    countdown.Text = string.format(isDuel and "NEXT MATCH IN %ds"
        or "NEXT ROUND IN %ds", math.max(0, seconds))
        .. (build and ("   /   BUILD " .. build) or "")
    root.Visible = true
end

local cameraConnection
local function reconnectCamera()
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
    local camera = Workspace.CurrentCamera
    if camera then
        cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
    end
    updateLayout()
end
local cameraChangedConnection =
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(reconnectCamera)
reconnectCamera()

local attributeConnections = {}
for _, attr in ipairs({
    "NeonMatchPhase", "NeonMatchWinner", "NeonMatchRound",
    "NeonMatchTimeLeft", "IronYardWinnerUserId", "IronYardStandings",
    "IronYardFinalStandings",
}) do
    table.insert(attributeConnections,
        Workspace:GetAttributeChangedSignal(attr):Connect(render))
end
for _, attr in ipairs({
    "IronYardLifetimeXP", "IronYardProgressLevel", "IronYardRoundXP",
    "IronYardSavedXP", "IronYardProgressStatus",
}) do
    table.insert(attributeConnections,
        player:GetAttributeChangedSignal(attr):Connect(render))
end

-- leaderstats and their values can arrive late or be replaced between
-- rounds. A new container must not leave old Value listeners subscribed.
local activeStats = nil
local statsAddedConnection = nil
local statsRemovedConnection = nil
local statConnections = {}
local statValues = {}

local function releaseStats()
    if statsAddedConnection then
        statsAddedConnection:Disconnect()
        statsAddedConnection = nil
    end
    if statsRemovedConnection then
        statsRemovedConnection:Disconnect()
        statsRemovedConnection = nil
    end
    for name, connection in pairs(statConnections) do
        connection:Disconnect()
        statConnections[name] = nil
    end
    table.clear(statValues)
    activeStats = nil
end

local function bindValue(value)
    if not activeStats or value.Parent ~= activeStats
        or not value:IsA("IntValue")
        or (value.Name ~= "Eliminations" and value.Name ~= "Deaths") then
        return
    end
    local name = value.Name
    if statValues[name] == value then return end
    if statConnections[name] then
        statConnections[name]:Disconnect()
        statConnections[name] = nil
    end
    statValues[name] = value
    statConnections[name] = value:GetPropertyChangedSignal("Value"):Connect(function()
        if activeStats == value.Parent and statValues[name] == value then
            render()
        end
    end)
    render()
end

local function bindStats(stats)
    if activeStats == stats then return end
    releaseStats()
    if stats.Parent ~= player then
        render()
        return
    end
    activeStats = stats
    statsAddedConnection = stats.ChildAdded:Connect(bindValue)
    statsRemovedConnection = stats.ChildRemoved:Connect(function(child)
        local name = child.Name
        if statValues[name] ~= child then return end
        if statConnections[name] then
            statConnections[name]:Disconnect()
            statConnections[name] = nil
        end
        statValues[name] = nil
        render()
    end)
    for _, value in ipairs(stats:GetChildren()) do
        bindValue(value)
    end
    render()
end

local playerStatsAdded = player.ChildAdded:Connect(function(child)
    if child.Name == "leaderstats" then bindStats(child) end
end)
local playerStatsRemoved = player.ChildRemoved:Connect(function(child)
    if child == activeStats then
        releaseStats()
        render()
    end
end)
local existingStats = player:FindFirstChild("leaderstats")
if existingStats then bindStats(existingStats) end

script.Destroying:Connect(function()
    playerStatsAdded:Disconnect()
    playerStatsRemoved:Disconnect()
    releaseStats()
    cameraChangedConnection:Disconnect()
    if cameraConnection then cameraConnection:Disconnect() end
    for _, connection in ipairs(attributeConnections) do
        connection:Disconnect()
    end
    table.clear(attributeConnections)
    gui:Destroy()
end)
render()
