-- IRON YARD - competitive match scoreboard.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local remotes = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("PrecisionNet")).getRemotes(false)
local DuelReadout = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("DuelReadout"))
local TouchLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TouchLayout"))
local DuelSpawnPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DuelSpawnPlan"))
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "NeonStrikeMatchHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
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
header.TextTruncate = Enum.TextTruncate.AtEnd
local detail = label("Score", 12, UDim2.new(1, -12, 0, 27), UDim2.fromOffset(6, 34), Color3.fromRGB(248, 248, 241))

detail.TextTruncate = Enum.TextTruncate.AtEnd

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

local function duelButton(parent, name, text, size, position)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(55, 65, 61)
    button.TextColor3 = Color3.fromRGB(247, 223, 177)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.BorderSizePixel = 0
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = button
    button.Parent = parent
    return button
end

local duelToggle = duelButton(gui, "DuelOneVsOne", "1v1",
    UDim2.fromOffset(100, 38), UDim2.fromOffset(10, 136))
if UserInputService.TouchEnabled then
    local rect = TouchLayout.MENU_BUTTONS.Duel
    duelToggle.Size = UDim2.fromOffset(rect.w, rect.h)
    duelToggle.Position = UDim2.fromOffset(rect.x, rect.y)
end
local menu = Instance.new("Frame")
menu.Name = "DuelLobby"
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.54)
menu.Size = UDim2.new(0.84, 0, 0.79, 0)
menu.BackgroundColor3 = Color3.fromRGB(27, 35, 35)
menu.BorderSizePixel = 0
menu.Visible = false
menu.Parent = gui
local menuLimit = Instance.new("UISizeConstraint")
menuLimit.MaxSize = Vector2.new(360, 310)
menuLimit.Parent = menu
local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 12)
menuCorner.Parent = menu

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -62, 0, 38)
status.Position = UDim2.fromOffset(12, 5)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(247, 223, 177)
status.Font = Enum.Font.GothamBold
status.TextSize = 13
status.TextTruncate = Enum.TextTruncate.AtEnd
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = menu
local close = duelButton(menu, "Close", "×", UDim2.fromOffset(35, 32),
    UDim2.new(1, -44, 0, 7))
close.Modal = true
local search = duelButton(menu, "Search", "FIND OPPONENT",
    UDim2.new(1, -24, 0, 38), UDim2.fromOffset(12, 47))
local invite = duelButton(menu, "AcceptInvite", "",
    UDim2.new(1, -124, 0, 38), UDim2.fromOffset(12, 91))
local decline = duelButton(menu, "DeclineInvite", "DECLINE",
    UDim2.fromOffset(94, 38), UDim2.new(1, -106, 0, 91))
decline.Visible = false

local roster = Instance.new("ScrollingFrame")
roster.Name = "LobbyPlayers"
roster.BackgroundTransparency = 1
roster.BorderSizePixel = 0
roster.ScrollBarThickness = 4
roster.CanvasSize = UDim2.fromOffset(0, 0)
roster.AutomaticCanvasSize = Enum.AutomaticSize.Y
roster.Parent = menu
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 5)
list.SortOrder = Enum.SortOrder.Name
list.Parent = roster

local states = {
    SEARCHING = "LOOKING FOR A 1v1",
    INVITED = "WAITING FOR INVITE RESPONSE",
    CONNECTING = "CONNECTING TO DUEL…",
    RETURNING = "RETURNING TO FFA…",
    FAILED = "CONNECTION FAILED · TRY AGAIN",
    UNAVAILABLE = "PLAYER UNAVAILABLE",
    INVITE_EXPIRED = "INVITATION EXPIRED",
    INVITE_DECLINED = "INVITATION DECLINED",
    INVITE_COOLDOWN = "REINVITE BLOCKED · TRY AGAIN LATER",
}

local REINVITE_ATTRIBUTE = "IronYardDuelReinviteDeadlines"
local reinviteDeadlines = {}
local inviteRows = {}
local countdownTask

local function setMenu(visible)
    if menu.Visible == visible then return end
    menu.Visible = visible
    if not visible and countdownTask then
        task.cancel(countdownTask)
        countdownTask = nil
    end
    gui.DisplayOrder = visible and 45 or 20
    playerGui:SetAttribute("IronYardDuelMenuOpen", visible)
end

local function refreshInviteRows()
    if countdownTask then
        task.cancel(countdownTask)
        countdownTask = nil
    end
    if not menu.Visible then return end

    local now = Workspace:GetServerTimeNow()
    local nextRefresh = math.huge
    for userId, row in pairs(inviteRows) do
        local deadline = reinviteDeadlines[tostring(userId)]
        local remaining = type(deadline) == "number" and deadline - now or 0
        local blocked = remaining > 0
        local seconds = math.ceil(remaining)
        local text = blocked and string.format("WAIT %ds  ·  %s", seconds, row.name)
            or ("INVITE  " .. row.name)
        if row.button.Text ~= text then row.button.Text = text end
        row.button.Interactable = not blocked
        row.button.AutoButtonColor = not blocked
        if blocked then
            nextRefresh = math.min(nextRefresh, remaining - seconds + 1)
        end
    end
    if nextRefresh < math.huge then
        countdownTask = task.delay(math.max(0.02, nextRefresh), function()
            countdownTask = nil
            refreshInviteRows()
        end)
    end
end

local function readReinviteDeadlines()
    local raw = player:GetAttribute(REINVITE_ATTRIBUTE)
    reinviteDeadlines = {}
    if type(raw) == "string" then
        local ok, deadlines = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok and type(deadlines) == "table" then reinviteDeadlines = deadlines end
    end
    refreshInviteRows()
end

local function updateRoster()
    table.clear(inviteRows)
    for _, child in ipairs(roster:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    if Workspace:GetAttribute("IronYardDuelLocal") then
        refreshInviteRows()
        return
    end
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other:GetAttribute("IronYardDuelTravel") ~= "CONNECTING" then
            local button = duelButton(roster, other.Name, "INVITE  " .. other.DisplayName,
                UDim2.new(1, -7, 0, 36), UDim2.fromOffset(0, 0))
            inviteRows[other.UserId] = { button = button, name = other.DisplayName }
            button.Activated:Connect(function()
                if not button.Interactable then return end
                remotes.SetDuelReady:FireServer(true, other.UserId)
                setMenu(false)
            end)
        end
    end
    refreshInviteRows()
end

local displayedInvitation
local displayedInviterId
local function duelLabel()
    local phase = Workspace:GetAttribute("NeonMatchPhase")
    local dedicated = Workspace:GetAttribute("IronYardDedicatedDuel") == true
    local state = player:GetAttribute("IronYardDuelTravel")
    local ready = player:GetAttribute("IronYardDuelReady") == true
    local invitation = player:GetAttribute("IronYardDuelInvitation")
    local incomingId = typeof(invitation) == "string" and tonumber(invitation:match("^(%d+):%d+$"))
    local incoming = incomingId and Players:GetPlayerByUserId(incomingId)
    local canQueue = not dedicated
        and Workspace:GetAttribute("IronYardMatchMode") ~= "DUEL" and phase ~= "RESULTS"
    local returnAvailable = dedicated and (phase == "WAITING" or phase == "COUNTDOWN")
    local shown = (canQueue or returnAvailable)
        and playerGui:GetAttribute("IronYardBriefingOpen") ~= true
    duelToggle.Visible = shown
    duelToggle.Interactable = state ~= "RETURNING"
    if not shown or returnAvailable or state == "CONNECTING" then setMenu(false) end

    if returnAvailable then
        duelToggle.Text = state == "RETURNING" and "RETURNING…" or "BACK TO FFA"
    elseif state == "CONNECTING" then
        duelToggle.Text = "CONNECTING…"
    elseif state == "FAILED" or state == "INVITE_COOLDOWN" then
        duelToggle.Text = "1v1 · RETRY"
    elseif incoming then
        duelToggle.Text = "1v1 · INVITE"
    elseif state == "INVITE_DECLINED" then
        duelToggle.Text = "1v1 · DECLINED"
    elseif ready then
        duelToggle.Text = "1v1 · WAITING"
    else
        duelToggle.Text = UserInputService.TouchEnabled and "1v1" or "V  ·  1v1"
    end
    if UserInputService.TouchEnabled then
        if returnAvailable then
            duelToggle.Text = state == "RETURNING" and "…" or "FFA"
        elseif state == "CONNECTING" then
            duelToggle.Text = "…"
        elseif incoming or state == "FAILED" or state == "INVITE_DECLINED" or state == "INVITE_COOLDOWN" then
            duelToggle.Text = "1v1 !"
        elseif ready then
            duelToggle.Text = "1v1 ✓"
        end
    end
    status.Text = states[state] or "1v1 DUEL"
    search.Text = ready and "CANCEL REQUEST" or "FIND OPPONENT"
    local busy = state == "CONNECTING"
    search.Interactable = not busy
    invite.Visible = incoming ~= nil and not busy
    decline.Visible = invite.Visible
    invite.Text = incoming and ("ACCEPT  " .. incoming.DisplayName) or ""
    displayedInvitation = invite.Visible and invitation or nil
    displayedInviterId = invite.Visible and incomingId or nil
    local top = invite.Visible and 135 or 91
    roster.Visible = not busy
    roster.Position = UDim2.fromOffset(12, top)
    roster.Size = UDim2.new(1, -24, 1, -top - 8)
end

local function toggleDuel()
    if not duelToggle.Visible or not duelToggle.Interactable then return end
    if Workspace:GetAttribute("IronYardDedicatedDuel") then
        remotes.ReturnToFfa:FireServer()
        return
    end
    local opening = not menu.Visible
    setMenu(opening)
    if opening then updateRoster() end
end

duelToggle.Activated:Connect(toggleDuel)
close.Activated:Connect(function() setMenu(false) end)
search.Activated:Connect(function()
    remotes.SetDuelReady:FireServer(player:GetAttribute("IronYardDuelReady") ~= true)
    if player:GetAttribute("IronYardDuelReady") ~= true then setMenu(false) end
end)
invite.Activated:Connect(function()
    if displayedInvitation then
        remotes.SetDuelReady:FireServer(true, displayedInviterId, displayedInvitation)
    end
end)
decline.Activated:Connect(function()
    if displayedInvitation then
        remotes.SetDuelReady:FireServer(false, displayedInviterId, displayedInvitation)
    end
end)
UserInputService.InputBegan:Connect(function(input, used)
    if not used and input.KeyCode == Enum.KeyCode.V
        and playerGui:GetAttribute("IronYardSettingsOpen") ~= true then
        toggleDuel()
    end
end)
for _, name in ipairs({ "IronYardDuelReady", "IronYardDuelTravel", "IronYardDuelInvitation" }) do
    player:GetAttributeChangedSignal(name):Connect(duelLabel)
end
player:GetAttributeChangedSignal(REINVITE_ATTRIBUTE):Connect(readReinviteDeadlines)
readReinviteDeadlines()
playerGui:GetAttributeChangedSignal("IronYardSettingsOpen"):Connect(function()
    if playerGui:GetAttribute("IronYardSettingsOpen") then setMenu(false) end
end)
local function rosterChanged()
    task.defer(function()
        if menu.Visible then updateRoster() end
        duelLabel()
    end)
end
Players.PlayerAdded:Connect(rosterChanged)
Players.PlayerRemoving:Connect(rosterChanged)

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
            headerText = string.format("DUEL %d  /  %ds   ·   %s",
                duelBout + 1, math.clamp(seconds, 1, 3), score)
            local character = player.Character
            local pad = character and character:GetAttribute("IronYardDuelPad")
            detailText = DuelSpawnPlan.padLabel(pad) or "PREPARE"
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
        if Workspace:GetAttribute("IronYardDedicatedDuel") then
            local travel = player:GetAttribute("IronYardDuelTravel")
            if travel == "FAILED" then
                detailText = "RETURN FAILED · TRY BACK TO FFA"
            elseif travel == "RETURNING" then
                detailText = states.RETURNING
            else
                detailText = seconds > 0 and string.format("WAITING FOR OPPONENT  /  %ds", seconds)
                    or "WAITING FOR OPPONENT"
            end
        else
            detailText = "WAITING FOR OPERATORS"
        end
    elseif phase == "COUNTDOWN" then
        headerText = string.format("ROUND %d  |  STARTING", count + 1)
        local localDuel = Workspace:GetAttribute("IronYardDuelLocal")
            and readyCount == 2 and #Players:GetPlayers() == 2
        detailText = (Workspace:GetAttribute("IronYardDedicatedDuel") or localDuel)
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
    "IronYardMatchMode", "IronYardDuelReadyCount", "IronYardDedicatedDuel", "IronYardDuelLocal",
    "IronYardDuelBout", "IronYardDuelScoreA", "IronYardDuelScoreB",
    "IronYardDuelPlayerA", "IronYardDuelPlayerB", "IronYardDuelLastResult",
}) do
    Workspace:GetAttributeChangedSignal(name):Connect(function()
        update()
        duelLabel()
    end)
end
local duelPadConnection
local function bindDuelPad(character)
    if duelPadConnection then duelPadConnection:Disconnect() end
    duelPadConnection = character and character:GetAttributeChangedSignal("IronYardDuelPad"):Connect(update)
    update()
end
player.CharacterAdded:Connect(bindDuelPad)
player.CharacterRemoving:Connect(function() bindDuelPad(nil) end)
player:GetAttributeChangedSignal("IronYardDuelTravel"):Connect(update)
bindDuelPad(player.Character)
duelLabel()
