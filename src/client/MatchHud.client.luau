-- IRON YARD - competitive match scoreboard.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
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
local GamepadCombatPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamepadCombatPolicy"))
local PracticeMode = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PracticeMode"))
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

local duelToggle = duelButton(gui, "DuelOneVsOne", "DUELS",
    UDim2.fromOffset(100, 38), UDim2.fromOffset(10, 136))
local quickCancel = duelButton(gui, "CancelDuelSearch", "CANCEL",
    UDim2.fromOffset(100, 28), UDim2.fromOffset(10, 178))
quickCancel.Visible = false
if UserInputService.TouchEnabled then
    local rect = TouchLayout.MENU_BUTTONS.Duel
    duelToggle.Size = UDim2.fromOffset(rect.w, rect.h)
    duelToggle.Position = UDim2.fromOffset(rect.x, rect.y)
    local cancelRect = TouchLayout.MENU_BUTTONS.CancelDuelSearch
    quickCancel.Size = UDim2.fromOffset(cancelRect.w, cancelRect.h)
    quickCancel.Position = UDim2.fromOffset(cancelRect.x, cancelRect.y)
    quickCancel.TextSize = 10
end
local menu = Instance.new("Frame")
menu.Name = "DuelLobby"
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.5)
menu.Size = UDim2.new(0.84, 0, 0.90, 0)
menu.BackgroundColor3 = Color3.fromRGB(27, 35, 35)
menu.BorderSizePixel = 0
menu.Visible = false
menu.SelectionGroup = true
menu.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
menu.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
menu.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
menu.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
menu.Parent = gui
local menuLimit = Instance.new("UISizeConstraint")
menuLimit.MaxSize = Vector2.new(360, 350)
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
local soloTab = duelButton(menu, "SoloDuels", "1v1",
    UDim2.new(0.5, -16, 0, 36), UDim2.fromOffset(12, 47))
local teamTab = duelButton(menu, "TeamDuels", "2v2",
    UDim2.new(0.5, -16, 0, 36), UDim2.new(0.5, 4, 0, 47))
local search = duelButton(menu, "Search", "FIND OPPONENT",
    UDim2.new(1, -24, 0, 38), UDim2.fromOffset(12, 91))
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

local emptyRoster = Instance.new("TextLabel")
emptyRoster.Name = "NoInviteTargets"
emptyRoster.Size = UDim2.new(1, -24, 0, 34)
emptyRoster.Position = UDim2.fromOffset(12, 91)
emptyRoster.BackgroundTransparency = 1
emptyRoster.Font = Enum.Font.GothamMedium
emptyRoster.TextSize = 13
emptyRoster.TextWrapped = true
emptyRoster.TextXAlignment = Enum.TextXAlignment.Left
emptyRoster.TextYAlignment = Enum.TextYAlignment.Top
emptyRoster.TextColor3 = Color3.fromRGB(190, 203, 198)
emptyRoster.Text = "No players available to invite in this server."
emptyRoster.Visible = false
emptyRoster.Parent = menu

local currentTab = Color3.fromRGB(94, 81, 50)
local availableTab = Color3.fromRGB(55, 65, 61)
local teammateAttribute = "IronYardDuelTeammate"
local selectedTeamFormat = false
local states = {
    TEAM_CANCELLED = "TEAMMATE CANCELLED THE SEARCH",
    TEAM_PARTNER_LEFT = "TEAMMATE LEFT THE SERVER",
    SEARCHING = "LOOKING FOR A 1v1",
    INVITED = "WAITING FOR INVITE RESPONSE",
    CONNECTING = "CONNECTING TO DUEL…",
    RETURNING = "RETURNING TO FFA…",
    FAILED = "CONNECTION FAILED · TRY AGAIN",
    DUEL_PARTNER_LEFT = "OPPONENT LEFT BEFORE TRANSFER",
    UNAVAILABLE = "PLAYER UNAVAILABLE",
    INVITE_EXPIRED = "INVITATION EXPIRED",
    INVITE_TARGET_LEFT = "INVITED PLAYER LEFT THE SERVER",
    INVITE_TARGET_BUSY = "PLAYER JOINING ANOTHER DUEL",
    INVITE_DECLINED = "INVITATION DECLINED",
    INVITE_COOLDOWN = "REINVITE BLOCKED · TRY AGAIN LATER",
}

local REINVITE_ATTRIBUTE = "IronYardDuelReinviteDeadlines"
local reinviteDeadlines = {}
local inviteRows = {}
local countdownTask
local REQUEST_CONFIRMATION_SECONDS = 3
local readyRequest
local requestPending = false
local activeOutgoingRecipient

local function gamepadActive()
    return GamepadCombatPolicy.isGamepad(UserInputService:GetLastInputType().Name)
end

local function syncMenuSelection()
    local selected = GuiService.SelectedObject
    local ownsSelection = selected and selected:IsDescendantOf(menu)
    if not menu.Visible or GuiService.MenuIsOpen or not gamepadActive() then
        if ownsSelection then GuiService.SelectedObject = nil end
        return
    end
    if requestPending and readyRequest.targetId and not readyRequest.invitation then
        if ownsSelection then GuiService.SelectedObject = nil end
        return
    end
    if ownsSelection and selected.Visible and selected.Interactable and selected.Selectable then return end
    GuiService.SelectedObject = (invite.Selectable and invite)
        or (search.Selectable and search)
        or (teamTab.Selectable and teamTab)
        or close
end

local function updateQuickCancel()
    quickCancel.Visible = duelToggle.Visible and not menu.Visible
        and not requestPending
        and playerGui:GetAttribute("IronYardSettingsOpen") ~= true
        and (player:GetAttribute("IronYardDuelTravel") == "SEARCHING"
            or player:GetAttribute("IronYardDuelTravel") == "TEAM_SEARCHING")
        and player:GetAttribute("IronYardDuelReady") == true
end

local function setMenu(visible)
    if menu.Visible == visible then return end
    menu.Visible = visible
    if not visible and countdownTask then
        task.cancel(countdownTask)
        countdownTask = nil
    end
    gui.DisplayOrder = visible and 45 or 20
    playerGui:SetAttribute("IronYardDuelMenuOpen", visible)
    updateQuickCancel()
    syncMenuSelection()
end

local function refreshInviteRows()
    if countdownTask then
        task.cancel(countdownTask)
        countdownTask = nil
    end
    if not menu.Visible then return end
    emptyRoster.Visible = roster.Visible and next(inviteRows) == nil
    emptyRoster.Text = selectedTeamFormat
        and "No teammates available. 2v2 needs four players in this lobby."
        or "No players available to invite in this server."

    local now = Workspace:GetServerTimeNow()
    local nextRefresh = math.huge
    for userId, row in pairs(inviteRows) do
        local deadline = reinviteDeadlines[tostring(userId)]
        local remaining = type(deadline) == "number" and deadline - now or 0
        local blocked = remaining > 0
        local seconds = math.ceil(remaining)
        local invited = userId == activeOutgoingRecipient
        local text = invited and ("INVITED  " .. row.name)
            or (blocked and string.format("WAIT %ds  ·  %s", seconds, row.name))
            or ((selectedTeamFormat and "TEAM UP  " or "INVITE  ") .. row.name)
        if row.button.Text ~= text then row.button.Text = text end
        local available = roster.Visible and not invited and not blocked and not requestPending
        row.button.Interactable = available
        row.button.Selectable = available
        row.button.AutoButtonColor = available
        if blocked then
            nextRefresh = math.min(nextRefresh, remaining - seconds + 1)
        end
    end
    syncMenuSelection()
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

local function removeInviteRow(other)
    local row = inviteRows[other.UserId]
    if not row or row.player ~= other then return false end
    inviteRows[other.UserId] = nil
    if GuiService.SelectedObject == row.button then GuiService.SelectedObject = nil end
    row.button:Destroy()
    return true
end

local function canInvite(other)
    local travel = other:GetAttribute("IronYardDuelTravel")
    return other.Parent == Players and other ~= player and not PracticeMode.active(other)
        and not Workspace:GetAttribute("IronYardDuelLocal")
        and travel ~= "CONNECTING" and travel ~= "RETURNING" and travel ~= "TEAM_SEARCHING"
end

local displayedInvitation
local displayedInviterId
local displayedInviteExpiry
local SEARCH_STARTED_ATTRIBUTE = "IronYardDuelSearchStartedAt"
local OUTGOING_INVITE_ATTRIBUTE = "IronYardDuelOutgoingInvite"
local duelClockTask
local returnPhase, returnRound
local function duelLabel()
    if duelClockTask then
        task.cancel(duelClockTask)
        duelClockTask = nil
    end

    local phase = Workspace:GetAttribute("NeonMatchPhase")
    local dedicated = Workspace:GetAttribute("IronYardDedicatedDuel") == true
    local state = player:GetAttribute("IronYardDuelTravel")
    local ready = player:GetAttribute("IronYardDuelReady") == true
    local invitation = player:GetAttribute("IronYardDuelInvitation")
    local canQueue = not dedicated and not PracticeMode.active(player)
        and Workspace:GetAttribute("IronYardMatchMode") ~= "DUEL" and phase ~= "RESULTS"
    local returnAvailable = dedicated and (phase == "WAITING" or phase == "COUNTDOWN")
    returnPhase = returnAvailable and phase or nil
    returnRound = returnAvailable and Workspace:GetAttribute("NeonMatchRound") or nil
    local shown = (canQueue or returnAvailable)
        and playerGui:GetAttribute("IronYardSettingsOpen") ~= true
    local teamSearching = state == "TEAM_SEARCHING"
    if teamSearching then selectedTeamFormat = true end
    local searching = canQueue and (state == "SEARCHING" or teamSearching) and ready
    local invited = canQueue and state == "INVITED" and ready
    local now = (shown and canQueue or readyRequest ~= nil) and Workspace:GetServerTimeNow() or 0
    local outgoing = player:GetAttribute(OUTGOING_INVITE_ATTRIBUTE)
    local outgoingId, outgoingExpiry, outgoingTeam
    if type(outgoing) == "string" then
        local recipient, expiry = outgoing:match("^(%d+):(%d+)$")
        if not recipient then
            recipient, expiry = outgoing:match("^(%d+):(%d+):2$")
            if recipient then outgoingTeam = true end
        end
        if recipient then
            outgoingId = tonumber(recipient)
            outgoingExpiry = tonumber(expiry) / 1000
        end
    end
    local incoming, incomingId, inviteExpiry, inviteSeconds, teamIncoming
    local nextRefresh = math.huge
    local busy = state == "CONNECTING"
    local wasPending = requestPending
    requestPending = false
    if readyRequest then
        local resolved
        if readyRequest.invitation then
            resolved = invitation ~= readyRequest.invitation or now >= readyRequest.inviteExpiry
        elseif readyRequest.targetId then
            resolved = (state == "INVITED" and outgoingId == readyRequest.targetId
                    and outgoingExpiry > now and outgoingTeam == readyRequest.teamInvite)
                or (teamSearching and readyRequest.teamInvite
                    and player:GetAttribute(teammateAttribute) == readyRequest.targetId)
                or (state ~= readyRequest.previousState and (state == "UNAVAILABLE" or state == "INVITE_COOLDOWN"))
        else
            resolved = ready == readyRequest.enabled
        end
        if resolved or busy or dedicated or Workspace:GetAttribute("IronYardMatchMode") == "DUEL"
            or now >= readyRequest.deadline + REQUEST_CONFIRMATION_SECONDS then
            readyRequest = nil
        elseif now < readyRequest.deadline then
            requestPending = true
            nextRefresh = readyRequest.deadline - now
        else
            nextRefresh = readyRequest.deadline + REQUEST_CONFIRMATION_SECONDS - now
        end
        if readyRequest and readyRequest.inviteExpiry then
            nextRefresh = math.min(nextRefresh, readyRequest.inviteExpiry - now)
        end
    end
    if shown and canQueue and not busy and type(invitation) == "string" then
        local sender, expiryMillis = invitation:match("^(%d+):%d+:(%d+)$")
        if not sender then
            sender, expiryMillis = invitation:match("^(%d+):%d+:(%d+):2$")
            teamIncoming = sender ~= nil
        end
        if sender then
            incomingId = tonumber(sender)
            inviteExpiry = tonumber(expiryMillis) / 1000
            local remaining = inviteExpiry - now
            if remaining > 0 then
                incoming = Players:GetPlayerByUserId(incomingId)
                if incoming then
                    inviteSeconds = math.ceil(remaining)
                    nextRefresh = math.min(nextRefresh, remaining - inviteSeconds + 1)
                end
            end
        end
    end
    local elapsedText
    local startedAt = player:GetAttribute(SEARCH_STARTED_ATTRIBUTE)
    if searching and shown and type(startedAt) == "number" then
        local elapsed = math.max(0, now - startedAt)
        local seconds = math.floor(elapsed)
        if seconds >= 6000 then
            elapsedText = "99m+"
        else
            elapsedText = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
            nextRefresh = math.min(nextRefresh, seconds + 1 - elapsed)
        end
    end
    local outgoingSeconds, outgoingRecipient, teamOutgoing
    activeOutgoingRecipient = nil
    if invited and shown and outgoingExpiry and outgoingExpiry > now then
        local remaining = outgoingExpiry - now
        outgoingSeconds = math.ceil(remaining)
        outgoingRecipient = Players:GetPlayerByUserId(outgoingId)
        activeOutgoingRecipient = outgoingId
        teamOutgoing = outgoingTeam
        nextRefresh = math.min(nextRefresh, remaining - outgoingSeconds + 1)
    end
    if teamOutgoing then selectedTeamFormat = true end
    local opponentLeft = state == "INVITE_TARGET_LEFT" or state == "DUEL_PARTNER_LEFT"
    local controller = gamepadActive()
    duelToggle.Visible = shown
    duelToggle.Interactable = state ~= "RETURNING" and not busy
    close.Text = controller and "R3" or "×"
    if not shown or returnAvailable or state == "CONNECTING" then setMenu(false) end

    local touch = UserInputService.TouchEnabled
    local format = (teamSearching or teamOutgoing) and "2v2" or "1v1"
    if returnAvailable then
        duelToggle.Text = state == "RETURNING" and (touch and "…" or "RETURNING…")
            or (controller and (touch and "R3\nFFA" or "R3 · FFA") or (touch and "FFA" or "BACK TO FFA"))
    elseif busy then
        duelToggle.Text = touch and "…" or "CONNECTING…"
    elseif requestPending then
        duelToggle.Text = touch and "DUELS\n…" or "DUELS · SENDING"
    elseif incoming then
        duelToggle.Text = (teamIncoming and "2v2" or "1v1") .. (touch and " !" or " · INVITE")
    elseif readyRequest or state == "FAILED" or state == "INVITE_DECLINED" or opponentLeft
        or state == "TEAM_PARTNER_LEFT" or state == "TEAM_CANCELLED" or state == "INVITE_COOLDOWN"
        or state == "INVITE_TARGET_BUSY" or state == "UNAVAILABLE" or state == "INVITE_EXPIRED" then
        duelToggle.Text = touch and "DUELS !" or "DUELS · STATUS"
    elseif searching then
        duelToggle.Text = format .. (touch and "" or " · SEARCHING")
    elseif invited then
        duelToggle.Text = touch and "SENT" or (format .. " · SENT")
    else
        duelToggle.Text = controller and (touch and "R3\nDUELS" or "R3 · DUELS") or (touch and "DUELS" or "V · DUELS")
    end
    if not requestPending then
        local seconds = inviteSeconds or (not readyRequest and outgoingSeconds)
        if seconds then
            duelToggle.Text ..= string.format("\n%ds", seconds)
        elseif not readyRequest and elapsedText then
            duelToggle.Text ..= "\n" .. elapsedText
        end
    end
    local currentStatus = outgoingSeconds and string.format("%s · %ds · %s",
        teamOutgoing and "2v2 INVITE" or "1v1 INVITE", outgoingSeconds,
        outgoingRecipient and outgoingRecipient.DisplayName or "SENT")
        or (elapsedText and not teamSearching and ("1v1 SEARCH  ·  " .. elapsedText))
        or (states[state] or (selectedTeamFormat and "INVITE A TEAMMATE\nTwo teams from this lobby" or "1v1 DUEL"))
    if teamSearching then
        local teammateId = player:GetAttribute(teammateAttribute)
        local teammate = type(teammateId) == "number" and Players:GetPlayerByUserId(teammateId)
        local name = teammate and teammate.DisplayName or "TEAMMATE"
        currentStatus = "FINDING A TEAM\nWITH " .. name
        if elapsedText then currentStatus ..= " · " .. elapsedText end
    elseif incoming then
        currentStatus = string.format("%s · %ds\n%s", teamIncoming and "2v2 INVITE" or "1v1 INVITE",
            inviteSeconds, incoming.DisplayName)
    end
    local replying = requestPending and readyRequest.invitation ~= nil
    local sendingInvite = requestPending and not replying and readyRequest.targetId ~= nil
    local pendingStatus = sendingInvite
        and ((readyRequest.teamInvite and "SENDING 2v2 INVITE…\n" or "SENDING INVITE…\n") .. readyRequest.targetName)
        or "WAITING FOR SERVER"
    local confirmationMissing = readyRequest and (not incoming or readyRequest.invitation == invitation)
    status.Text = requestPending and pendingStatus
        or (confirmationMissing and "NO CONFIRMATION · TRY AGAIN" or currentStatus)
    search.Text = requestPending and not replying and not sendingInvite
        and (readyRequest.enabled and "SENDING REQUEST…" or "CANCELLING…")
        or (teamSearching and "CANCEL TEAM SEARCH" or ready and "CANCEL REQUEST" or "FIND OPPONENT")
    search.Visible = ready or not selectedTeamFormat
    search.Interactable = search.Visible and not busy and not requestPending
    search.Selectable = search.Interactable
    local formatsVisible = not Workspace:GetAttribute("IronYardDuelLocal")
    for _, tab in ipairs({soloTab, teamTab}) do
        local selected = (tab == teamTab) == selectedTeamFormat
        tab.BackgroundColor3 = selected and currentTab or availableTab
        tab.Visible = formatsVisible
        tab.Interactable = formatsVisible and not ready and not busy and not requestPending
        tab.Selectable = tab.Interactable
    end
    invite.Visible = incoming ~= nil
    decline.Visible = invite.Visible
    invite.Interactable = not requestPending
    decline.Interactable = invite.Interactable
    invite.Selectable = invite.Interactable and invite.Visible
    decline.Selectable = decline.Interactable and decline.Visible
    invite.Text = replying and readyRequest.enabled and "ACCEPTING…"
        or (incoming and (teamIncoming and "JOIN TEAM" or "ACCEPT") or "")
    decline.Text = replying and not readyRequest.enabled and "DECLINING…" or "DECLINE"
    displayedInvitation = invite.Visible and invitation or nil
    displayedInviterId = invite.Visible and incomingId or nil
    displayedInviteExpiry = invite.Visible and inviteExpiry or nil
    local actionTop = formatsVisible and 89 or 47
    search.Position = UDim2.fromOffset(12, actionTop)
    local inviteTop = actionTop + (search.Visible and 44 or 0)
    invite.Position = UDim2.fromOffset(12, inviteTop)
    decline.Position = UDim2.new(1, -106, 0, inviteTop)
    local top = inviteTop + (invite.Visible and 44 or 0)
    roster.Visible = not busy and not teamSearching and not invite.Visible
    if not roster.Visible then emptyRoster.Visible = false end
    roster.Position = UDim2.fromOffset(12, top)
    roster.Size = UDim2.new(1, -24, 1, -top - 8)
    emptyRoster.Position = roster.Position
    updateQuickCancel()
    if wasPending ~= requestPending or menu.Visible then refreshInviteRows() end
    syncMenuSelection()
    if nextRefresh < math.huge then
        duelClockTask = task.delay(math.max(0.02, nextRefresh), function()
            duelClockTask = nil
            duelLabel()
        end)
    end
end

local function sendReadyRequest(request)
    if requestPending then return end
    request.deadline = Workspace:GetServerTimeNow() + REQUEST_CONFIRMATION_SECONDS
    if request.targetName then request.previousState = player:GetAttribute("IronYardDuelTravel") end
    readyRequest = request
    duelLabel()
    remotes.SetDuelReady:FireServer(request.enabled, request.targetId, request.invitation, nil, request.teamInvite)
end

local function syncInviteRow(other)
    if not canInvite(other) then return removeInviteRow(other) end
    local previous = inviteRows[other.UserId]
    if previous then
        if previous.player == other then return false end
        removeInviteRow(previous.player)
    end

    local button = duelButton(roster, other.Name, "INVITE  " .. other.DisplayName,
        UDim2.new(1, -7, 0, 36), UDim2.fromOffset(0, 0))
    local row = { button = button, name = other.DisplayName, player = other }
    inviteRows[other.UserId] = row
    button.Activated:Connect(function()
        if not menu.Visible or requestPending or inviteRows[other.UserId] ~= row or not button.Interactable
            or not canInvite(other) then return end
        sendReadyRequest({
            enabled = true,
            targetId = other.UserId,
            targetName = row.name,
            teamInvite = selectedTeamFormat or nil,
        })
    end)
    return true
end

local function updateRoster()
    for _, other in ipairs(Players:GetPlayers()) do
        syncInviteRow(other)
    end
    refreshInviteRows()
end

local function toggleDuel()
    if not duelToggle.Visible or not duelToggle.Interactable or GuiService.MenuIsOpen then return end
    if Workspace:GetAttribute("IronYardDedicatedDuel") then
        if returnPhase and returnRound then
            remotes.ReturnToFfa:FireServer(returnPhase, returnRound)
        end
        return
    end
    local opening = not menu.Visible
    setMenu(opening)
    if opening then
        duelLabel()
        updateRoster()
    end
end

duelToggle.Activated:Connect(toggleDuel)
quickCancel.Activated:Connect(function()
    updateQuickCancel()
    if quickCancel.Visible then sendReadyRequest({ enabled = false }) end
end)
close.Activated:Connect(function() setMenu(false) end)
for _, tab in ipairs({soloTab, teamTab}) do
    tab.Activated:Connect(function()
        if not menu.Visible or not tab.Interactable then return end
        selectedTeamFormat = tab == teamTab
        duelLabel()
    end)
end
search.Activated:Connect(function()
    if not menu.Visible or not search.Visible or not search.Interactable then return end
    local start = player:GetAttribute("IronYardDuelReady") ~= true
    sendReadyRequest({ enabled = start })
    if start then setMenu(false) end
end)
local function replyToInvitation(accept)
    if menu.Visible and not requestPending and displayedInvitation then
        if Workspace:GetServerTimeNow() < displayedInviteExpiry then
            sendReadyRequest({
                enabled = accept,
                targetId = displayedInviterId,
                invitation = displayedInvitation,
                inviteExpiry = displayedInviteExpiry,
            })
        else
            duelLabel()
        end
    end
end
invite.Activated:Connect(function() replyToInvitation(true) end)
decline.Activated:Connect(function() replyToInvitation(false) end)
UserInputService.InputBegan:Connect(function(input, used)
    if used or playerGui:GetAttribute("IronYardSettingsOpen") == true then return end
    if input.KeyCode == Enum.KeyCode.V or (input.KeyCode == Enum.KeyCode.ButtonR3
        and GamepadCombatPolicy.isGamepad(input.UserInputType.Name)) then
        toggleDuel()
    end
end)
UserInputService.LastInputTypeChanged:Connect(duelLabel)
GuiService.MenuOpened:Connect(syncMenuSelection)
GuiService.MenuClosed:Connect(syncMenuSelection)
for _, name in ipairs({
    "IronYardDuelReady", "IronYardDuelTravel", "IronYardDuelInvitation", SEARCH_STARTED_ATTRIBUTE,
    OUTGOING_INVITE_ATTRIBUTE, teammateAttribute,
}) do
    player:GetAttributeChangedSignal(name):Connect(duelLabel)
end
player:GetAttributeChangedSignal(REINVITE_ATTRIBUTE):Connect(readReinviteDeadlines)
readReinviteDeadlines()
playerGui:GetAttributeChangedSignal("IronYardSettingsOpen"):Connect(function()
    duelLabel()
end)
local travelConnections = {}
local function watchRosterPlayer(other)
    if other == player or travelConnections[other] then return end
    local function refreshRow()
        if travelConnections[other] and menu.Visible and syncInviteRow(other) then
            refreshInviteRows()
        end
    end
    travelConnections[other] = {
        other:GetAttributeChangedSignal("IronYardDuelTravel"):Connect(refreshRow),
        other:GetAttributeChangedSignal(PracticeMode.ATTRIBUTE):Connect(refreshRow),
    }
    if menu.Visible and syncInviteRow(other) then refreshInviteRows() end
    task.defer(duelLabel)
end
Players.PlayerAdded:Connect(watchRosterPlayer)
Players.PlayerRemoving:Connect(function(other)
    local connections = travelConnections[other]
    if not connections then return end
    travelConnections[other] = nil
    for _, connection in ipairs(connections) do connection:Disconnect() end
    if removeInviteRow(other) then refreshInviteRows() end
    task.defer(duelLabel)
end)
for _, other in ipairs(Players:GetPlayers()) do watchRosterPlayer(other) end
Workspace:GetAttributeChangedSignal("IronYardDuelLocal"):Connect(function()
    if menu.Visible then updateRoster() end
end)

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
    local duelArena = Workspace:GetAttribute("IronYardDuelArena")
    local arenaTitle = DuelSpawnPlan.arenaLabel(duelArena)
    local duelScoreA = Workspace:GetAttribute("IronYardDuelScoreA") or 0
    local duelScoreB = Workspace:GetAttribute("IronYardDuelScoreB") or 0
    local duelAId = Workspace:GetAttribute("IronYardDuelPlayerA")
    local duelBId = Workspace:GetAttribute("IronYardDuelPlayerB")
    local teamDuel = Workspace:GetAttribute("IronYardDuelSize") == 4
    local side = teamDuel and DuelReadout.sideIn(Workspace, player.UserId)
    local scoreReaderId = side == "A" and duelAId or side == "B" and duelBId or player.UserId
    local myWins, rivalWins = DuelReadout.scores(scoreReaderId,
        duelAId, duelBId, duelScoreA, duelScoreB)
    local lastDuelResult = Workspace:GetAttribute("IronYardDuelLastResult")
    local boutLabel = DuelReadout.boutLabel(lastDuelResult,
        scoreReaderId, duelAId, duelBId)
    local kills = eliminations and eliminations.Value or 0
    local clock = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)

    local headerText, detailText
    if PracticeMode.active(player) then
        headerText = "IRON YARD  /  PRACTICE RANGE"
        detailText = "TRY ALL 5 WEAPONS  ·  SETTINGS TO EXIT"
    elseif matchMode == "DUEL" and phase ~= "COUNTDOWN" and phase ~= "WAITING" then
        local score = myWins and string.format(teamDuel and "TEAM %d : %d RIVALS" or "YOU %d : %d RIVAL",
            myWins, rivalWins)
            or string.format("A %d : %d B", duelScoreA, duelScoreB)
        if phase == "LIVE" then
            headerText = string.format("%s  |  %d · %s", arenaTitle, duelBout, clock)
            local spectating = playerGui:GetAttribute("IronYardSpectating")
            detailText = spectating and ("SPECTATING TEAMMATE   /   " .. score)
                or ("FIRST TO 5   /   " .. score)
        elseif phase == "DUEL_PREP" then
            headerText = string.format("%s  /  %ds   ·   %s",
                arenaTitle, math.clamp(seconds, 1, 3), score)
            local character = player.Character
            local pad = character and character:GetAttribute("IronYardDuelPad")
            detailText = DuelSpawnPlan.padLabel(pad, duelArena) or "PREPARE"
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
                local waiting = teamDuel and "WAITING FOR ALL FOUR" or "WAITING FOR OPPONENT"
                detailText = seconds > 0 and string.format("%s  /  %ds", waiting, seconds) or waiting
            end
        else
            detailText = "WAITING FOR OPERATORS"
        end
    elseif phase == "COUNTDOWN" then
        headerText = string.format("ROUND %d  |  STARTING", count + 1)
        local localDuel = Workspace:GetAttribute("IronYardDuelLocal")
            and readyCount == 2 and #Players:GetPlayers() == 2
        detailText = (Workspace:GetAttribute("IronYardDedicatedDuel") or localDuel)
            and ((teamDuel and "2v2 NEXT  /  " or "1v1 DUEL NEXT  /  ") .. seconds .. "s")
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
    "IronYardDuelPlayerA", "IronYardDuelPlayerB", "IronYardDuelLastResult", "IronYardDuelArena",
    "IronYardDuelPlayerA2", "IronYardDuelPlayerB2", "IronYardDuelSize",
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
playerGui:GetAttributeChangedSignal("IronYardSpectating"):Connect(update)
player:GetAttributeChangedSignal(PracticeMode.ATTRIBUTE):Connect(function()
    if PracticeMode.active(player) then setMenu(false) end
    duelLabel()
    update()
end)
bindDuelPad(player.Character)
duelLabel()
