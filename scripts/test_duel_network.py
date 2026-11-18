"""Exercise the production duel HUD, lobby and reserved room under delayed delivery."""

import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]

SERVER_FIXTURE = r"""
local now = 1000
local warn = print
local tasks = {}
local os = {clock = function() return now end}
local task = {}
function task.delay(delay, callback)
    local job = {at = now + delay, callback = callback}
    table.insert(tasks, job)
    return job
end
function task.cancel(job) job.cancelled = true end
function task.spawn(callback, ...)
    local thread = coroutine.create(callback)
    local function resume(...)
        local ok, delay = coroutine.resume(thread, ...)
        assert(ok, delay)
        if coroutine.status(thread) ~= "dead" then task.delay(delay, resume) end
    end
    resume(...)
end
function task.wait(delay) return coroutine.yield(delay) end
local function advance(duration)
    local stop = now + duration
    while true do
        local earliest
        for index, job in ipairs(tasks) do
            if job.at <= stop and (not earliest or job.at < tasks[earliest].at) then
                earliest = index
            end
        end
        if not earliest then break end
        local job = table.remove(tasks, earliest)
        now = job.at
        if not job.cancelled then job.callback() end
    end
    now = stop
end
local function signal()
    local event = {listeners = {}}
    function event:Connect(callback) table.insert(self.listeners, callback) end
    function event:fire(...) for _, callback in ipairs(self.listeners) do callback(...) end end
    return event
end
local Players = {PlayerAdded = signal(), PlayerRemoving = signal(), online = {}}
function Players:GetPlayers() return self.online end
function Players:GetPlayerByUserId(id) return self.online[id] end

local Workspace = {attributes = {NeonMatchPhase = "LIVE", IronYardMatchMode = "FFA"}}
function Workspace:GetServerTimeNow() return now end
function Workspace:GetAttribute(key) return self.attributes[key] end
function Workspace:SetAttribute(key, value) self.attributes[key] = value end
local reservations, attempts = 0, 0
local transfers, rosters = {}, {}
local rosterReadBlocked = false
local Teleport = {TeleportInitFailed = signal()}
function Teleport:ReserveServerAsync()
    reservations += 1
    return "room-" .. reservations, reservations
end
function Teleport:TeleportAsync(_, players, options)
    table.insert(transfers, {group = players, options = options})
end
local services = {
    Players = Players,
    Workspace = Workspace,
    TeleportService = Teleport,
    MemoryStoreService = {GetHashMap = function()
        return {
            SetAsync = function(_, roomId, ids)
                rosters[roomId] = ids
                return true
            end,
            GetAsync = function(_, roomId)
                if rosterReadBlocked then error("MemoryStore unavailable") end
                return rosters[roomId]
            end,
        }
    end},
    HttpService = {JSONEncode = function(_, value)
        if value.mode == "DUEL" then Workspace.lastDuelResult = value end
        return "{}"
    end, GenerateGUID = function()
        attempts += 1
        return tostring(attempts)
    end},
    RunService = {IsStudio = function() return false end},
    ReplicatedStorage = {WaitForChild = function(self, name) return name == "Shared" and self or name end},
}
local game = {PrivateServerId = "", PrivateServerOwnerId = 0, PlaceId = 99}
function game:GetService(name) return assert(services[name]) end
local Instance = {new = function()
    return {
        SetTeleportData = function(self, value) self.payload = value end,
        GetTeleportData = function(self) return self.payload end,
    }
end}
local function connectPlayer(id)
    local p = {UserId = id, Name = "Player" .. id, DisplayName = "Player " .. id, Parent = Players}
    local authoritative, replicated = {}, {}
    local client = {}
    function client:GetAttribute(key) return replicated[key] end
    function p:GetAttribute(key) return authoritative[key] end
    function p:SetAttribute(key, value)
        if authoritative[key] == value then return end
        authoritative[key] = value
        task.delay(self.downstream, function()
            replicated[key] = value
            if self.render then self.render() end
        end)
    end
    p.downstream = 0.4
    function p:FindFirstChild() return nil end
    function p:Kick(message) self.kickReason = message end
    Players.online[id] = p
    Players.PlayerAdded:fire(p)
    return p, client
end
"""

HUD_FIXTURE = r"""
local function newHud(serverPlayer, player, deliverReturn)
    local upstream = 0.4
    local sent, returns = {}, {}
    local function enumGroup()
        return setmetatable({}, {__index = function(_, key) return key end})
    end
    local Enum = setmetatable({}, {__index = enumGroup})
    local Vector2 = {new = function(x, y) return {X=x, Y=y} end}
    local UDim = {new = function() end}
    local Color3 = {fromRGB = function() end}
    local GuiService, gui = {}, {}
    local UDim2 = {}
    function UDim2.new(sx, x, sy, y)
        return {X = {Scale=sx, Offset=x}, Y = {Scale=sy, Offset=y}}
    end
    function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
    function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end

    local Instance = {new = function()
        local control = {Activated = signal(), Visible = true, Interactable = true, Selectable = true}
        function control:IsDescendantOf(root)
            local parent = self.Parent
            while parent do
                if parent == root then return true end
                parent = parent.Parent
            end
            return false
        end
        function control:Destroy() self.Parent = nil end
        return control
    end}
    local serverPlayers = Players
    local Players = setmetatable({}, {__index = serverPlayers})
    local views = {}
    function Players:GetPlayers()
        local visible = {}
        for _, other in ipairs(serverPlayers:GetPlayers()) do
            local view = player
            if other ~= serverPlayer then
                view = views[other] or setmetatable({Parent=Players}, {__index=other})
                views[other] = view
            end
            table.insert(visible, view)
        end
        return visible
    end
    local inputType = {Name = "Touch"}
    local UserInputService = {TouchEnabled = true, GetLastInputType = function() return inputType end}
    local GamepadCombatPolicy = {isGamepad = function(name) return name == "Gamepad1" end}
    local playerGui = {SetAttribute = function() end, GetAttribute = function() end}
    local remotes = {ReturnToFfa = {FireServer = function(_, ...)
        local args = table.pack(...)
        table.insert(returns, args)
        if deliverReturn then
            task.delay(upstream, function()
                deliverReturn(serverPlayer, table.unpack(args, 1, args.n))
            end)
        end
    end}}
    remotes.SetDuelReady = {FireServer = function(_, ...)
        local args = table.pack(...)
        table.insert(sent, args)
        local deliver = function() Room.request(serverPlayer, args[1], args[2], args[3], args[5]) end
        task.delay(upstream, deliver)
    end}
"""

HUD_ENTRY_POINT = r"""
    serverPlayer.render = duelLabel
    duelLabel()
    return {
        open = toggleDuel, search = search, invite = invite, decline = decline, status = status,
        solo = soloTab, teams = teamTab, roster = roster, menu = menu, limit = menuLimit,
        sent = sent, returns = returns, render = duelLabel,
        delay = function(seconds) upstream = seconds end,
        row = function(id) return inviteRows[id].button end,
        focus = function(control) GuiService.SelectedObject = control end,
        selected = function() return GuiService.SelectedObject end,
        input = function(name) inputType.Name = name; duelLabel() end,
    }
end
"""

CHECKS = r"""
Room.start()
local sender, senderReplica = connectPlayer(1)
local recipient, recipientReplica = connectPlayer(2)
local waitingPlayer, waitingReplica = connectPlayer(3)
local a = newHud(sender, senderReplica)
local b = newHud(recipient, recipientReplica)

-- A delayed start response crosses the retry threshold. The UI converges
-- after replication and sends only one request despite the second press.
a.delay(3.1)
a.open()
a.search.Activated:fire()
a.open()
a.search.Activated:fire()
assert(#a.sent == 1 and a.status.Text == "WAITING FOR SERVER")
advance(3.05)
assert(a.status.Text == "NO CONFIRMATION · TRY AGAIN")
advance(0.5)
assert(a.search.Text == "CANCEL REQUEST" and sender:GetAttribute("IronYardDuelReady"))
a.delay(0.4)
a.search.Activated:fire()
advance(0.81)
assert(a.search.Text == "FIND OPPONENT" and not sender:GetAttribute("IronYardDuelReady"))

-- Direct invitations keep the lobby open and wait for the exact recipient.
a.delay(3.1)
local before = #a.sent
a.input("Gamepad1")
a.focus(a.row(2))
a.row(2).Activated:fire()
assert(a.menu.Visible and a.status.Text == "SENDING INVITE…\n" .. recipient.DisplayName)
assert(not a.selected(), "A second gamepad press must not browse or close the lobby")
a.row(3).Activated:fire()
a.search.Activated:fire()
assert(#a.sent == before + 1 and not a.row(3).Interactable)
advance(3.05)
assert(a.status.Text == "NO CONFIRMATION · TRY AGAIN" and a.row(2).Interactable)
a.delay(0.4)
a.row(2).Activated:fire()
advance(0.06)
local firstInvite = assert(sender:GetAttribute("IronYardDuelOutgoingInvite"))
advance(0.4)
assert(a.status.Text:find(recipient.DisplayName, 1, true) and not a.row(2).Interactable)
assert(sender:GetAttribute("IronYardDuelOutgoingInvite") == firstInvite, "Retry must not restart the invite timer")
assert(a.selected() == a.search, "Gamepad focus should return to the cancel action")
a.row(2).Activated:fire()
assert(#a.sent == before + 2, "The current recipient should not receive a second invite")

-- Switching recipients must not complete from the old invite or ready flag.
a.row(3).Activated:fire()
advance(0.41)
assert(a.status.Text == "SENDING INVITE…\n" .. waitingPlayer.DisplayName)
advance(0.4)
assert(a.status.Text:find(waitingPlayer.DisplayName, 1, true) and not a.row(3).Interactable)

-- A rejection replaces the pending message even when the target became busy in transit.
a.row(2).Activated:fire()
recipient:SetAttribute(PracticeMode.ATTRIBUTE, 1)
advance(0.81)
assert(a.status.Text == "PLAYER UNAVAILABLE" and not sender:GetAttribute("IronYardDuelReady"))
recipient:SetAttribute(PracticeMode.ATTRIBUTE, 2)

-- The old invite expires in transit. A fresh invitation from the same
-- player reaches the receiver, and the stale response cannot start a duel.
Room.request(sender, true, recipient.UserId)
Room.match()
advance(29.8)
local oldToken = recipientReplica:GetAttribute("IronYardDuelInvitation")
assert(oldToken)
b.open()
b.invite.Activated:fire()
b.decline.Activated:fire()
assert(#b.sent == 1 and b.sent[1][3] == oldToken)
advance(0.21)
Room.match()
Room.request(sender, true, recipient.UserId)
Room.match()
advance(0.41)
local newToken = recipientReplica:GetAttribute("IronYardDuelInvitation")
assert(newToken and newToken ~= oldToken and #transfers == 0)
assert(b.invite.Visible and b.invite.Interactable)

-- Decline applies to the exact successor while preserving an existing
-- search. Acceptance of a later invite requests one shared reservation.
Room.request(recipient, true)
advance(0.41)
b.decline.Activated:fire()
advance(0.81)
assert(recipient:GetAttribute("IronYardDuelTravel") == "SEARCHING")
assert(sender:GetAttribute("IronYardDuelTravel") == "INVITE_DECLINED")
assert(not b.invite.Visible)
advance(30)
Room.request(sender, true, recipient.UserId)
Room.match()
advance(0.41)
assert(b.invite.Visible)
b.invite.Activated:fire()
b.invite.Activated:fire()
advance(0.81)
assert(#b.sent == 3 and reservations == 1 and #transfers == 1)
assert(transfers[1].group[1] == sender and transfers[1].group[2] == recipient)
assert(transfers[1].options.ReservedServerAccessCode == "room-1")
assert(#rosters[1] == 2 and rosters[1][1] == sender.UserId and rosters[1][2] == recipient.UserId)
assert(not b.invite.Visible and recipientReplica:GetAttribute("IronYardDuelTravel") == "CONNECTING")
assert(waitingPlayer:GetAttribute("IronYardDuelTravel") == nil, "The third player must remain in FFA")

-- The HUD exit sends the phase and series it displays, including series zero.
local waiting = newHud(waitingPlayer, waitingReplica)
Workspace:SetAttribute("IronYardDedicatedDuel", true)
Workspace:SetAttribute("NeonMatchPhase", "WAITING")
Workspace:SetAttribute("NeonMatchRound", 0)
waiting.render()
waiting.open()
Workspace:SetAttribute("NeonMatchPhase", "COUNTDOWN")
waiting.render()
waiting.open()
assert(#waiting.returns == 2 and waiting.returns[1][1] == "WAITING" and waiting.returns[1][2] == 0)
assert(waiting.returns[2][1] == "COUNTDOWN" and waiting.returns[2][2] == 0)
print("Duel lobby network regression: slow confirmation, stale invite, shared reservation and exit context passed.")
"""


TEAM_LOBBY_CHECKS = r"""
Room.start()
local a, ar = connectPlayer(1)
local b, br = connectPlayer(2)
local c, cr = connectPlayer(3)
local d = connectPlayer(4)
local menu = newHud(c, cr)
menu.open()
assert(menu.solo.Visible and menu.teams.Visible and menu.search.Visible)
local function size(axis, parent)
    return axis.Scale * parent + axis.Offset
end
local compactHeight = math.min(size(menu.menu.Size.Y, TouchLayout.MIN_HEIGHT), menu.limit.MaxSize.Y)
local compactWidth = math.min(size(menu.menu.Size.X, TouchLayout.MIN_WIDTH), menu.limit.MaxSize.X)
assert(size(menu.roster.Size.Y, compactHeight) >= size(menu.row(1).Size.Y, compactHeight),
    "Compact viewport needs one whole invite row")
assert(size(menu.solo.Position.X, compactWidth) + size(menu.solo.Size.X, compactWidth)
    < size(menu.teams.Position.X, compactWidth), "Duel format controls must not overlap")
menu.teams.Activated:fire()
assert(not menu.search.Visible and menu.roster.Visible)
assert(string.find(menu.status.Text, "INVITE A TEAMMATE", 1, true))
menu.search.Activated:fire()
assert(#menu.sent == 0, "2v2 must not start a solo search")
menu.solo.Activated:fire()
assert(menu.search.Visible and menu.search.Text == "FIND OPPONENT")
menu.input("Gamepad1")
menu.focus(menu.row(1))
Room.request(a, true, c.UserId, nil, true)
Room.match()
advance(0.41)
assert(menu.selected() == menu.invite, "Incoming invitation hid the focused row without focusing the reply")
menu.input("Touch")
assert(not menu.selected(), "Switching to touch must clear the gamepad focus")
assert(menu.invite.Visible and menu.invite.Text == "JOIN TEAM" and not menu.roster.Visible)
assert(menu.status.Text:find("2v2 INVITE", 1, true) and menu.status.Text:find(a.DisplayName, 1, true))
assert(size(menu.invite.Position.Y, compactHeight) + size(menu.invite.Size.Y, compactHeight) <= compactHeight,
    "Invitation must fit small landscape screens")
assert(size(menu.invite.Position.X, compactWidth) + size(menu.invite.Size.X, compactWidth)
    < size(menu.decline.Position.X, compactWidth), "Invitation actions must not overlap")
assert(size(menu.decline.Position.X, compactWidth) + size(menu.decline.Size.X, compactWidth) <= compactWidth,
    "Decline action must stay inside the safe panel")
local token = c:GetAttribute("IronYardDuelInvitation")
assert(token and token:sub(-2) == ":2")
Room.request(d, true, a.UserId, token)
assert(not a:GetAttribute("IronYardDuelSearchStartedAt") and #transfers == 0)
menu.invite.Activated:fire()
advance(0.81)
assert(a:GetAttribute("IronYardDuelTravel") == "TEAM_SEARCHING")
assert(c:GetAttribute("IronYardDuelTravel") == "TEAM_SEARCHING")
assert(c:GetAttribute("IronYardDuelTeammate") == a.UserId)
assert(a:GetAttribute("IronYardDuelTeammate") == c.UserId)
assert(menu.status.Text:find("FINDING A TEAM", 1, true) and menu.status.Text:find(a.DisplayName, 1, true))
assert(not menu.roster.Visible and menu.search.Text == "CANCEL TEAM SEARCH")
assert(not menu.solo.Interactable and not menu.teams.Interactable)

Room.request(b, true)
Room.match()
assert(#transfers == 0, "A 2v2 team cannot fill the solo 1v1 queue")
menu.search.Activated:fire()
assert(menu.search.Text == "CANCELLING…")
advance(0.81)
assert(a:GetAttribute("IronYardDuelTravel") == "TEAM_CANCELLED")
assert(menu.roster.Visible and not menu.search.Visible and menu.teams.Interactable)
assert(not a:GetAttribute("IronYardDuelReady") and not c:GetAttribute("IronYardDuelReady"))
assert(not a:GetAttribute("IronYardDuelTeammate") and not c:GetAttribute("IronYardDuelTeammate"))
local captain = newHud(a, ar)
captain.open()
captain.teams.Activated:fire()
captain.row(3).Activated:fire()
assert(captain.menu.Visible and captain.status.Text == "SENDING 2v2 INVITE…\n" .. c.DisplayName)
captain.row(4).Activated:fire()
assert(#captain.sent == 1 and captain.sent[1][5] == true)
advance(0.81)
assert(captain.status.Text:find("2v2 INVITE", 1, true)
    and captain.status.Text:find(c.DisplayName, 1, true) and not captain.row(3).Interactable)
Room.match()
Room.request(c, true, a.UserId, token)
assert(a:GetAttribute("IronYardDuelTravel") == "INVITED", "Stale team invitation reused")
Room.request(c, true, a.UserId, c:GetAttribute("IronYardDuelInvitation"))
Room.request(b, true, d.UserId, nil, true)
Room.match()
Room.request(d, true, b.UserId, d:GetAttribute("IronYardDuelInvitation"))
Room.match()
assert(#transfers == 1 and #transfers[1].group == 4)
assert(transfers[1].group[1] == a and transfers[1].group[2] == b
    and transfers[1].group[3] == c and transfers[1].group[4] == d)
assert(table.concat(rosters[1], ",") == "1,2,3,4", "Authoritative team order changed")
print("2v2 lobby: explicit invitation, cancellation, stale token, queue separation and exact reserved roster passed.")
"""


DEDICATED_FIXTURE = r"""
local remotes = {SetDuelReady = {OnServerEvent = signal()}, ReturnToFfa = {OnServerEvent = signal()},
    SetPracticeRange = {OnServerEvent = signal()}}
local function noop() end
local preparedArenas = {}
local modules = {
    DuelSpawnPlan = DuelSpawnPlan,
    MapService = {prepareDuelArena = function(arena) table.insert(preparedArenas, arena) end},
    DuelRoom = Room, DuelRules = DuelRules, MatchLobbyPolicy = MatchLobbyPolicy, RoundStandings = RoundStandings,
    BotService = {reconcileNow = noop, resetRound = noop, getScores = function() return {} end},
    SpawnService = {}, WeaponService = {}, MovementService = {},
    PracticeMode = PracticeMode, PracticeRange = {},
    DuelCombatState = DuelCombatState, CombatAwards = {resetRound = noop}, SupplyService = {resetRound = noop},
    RemoteGuard = {allow = function() return true end},
    PrecisionNet = {getRemotes = function() return remotes end},
}
local script = {Parent = services.ReplicatedStorage}
local function require(name) return assert(modules[name], name) end
"""

WAITING_EXIT_CHECKS = r"""
local first, replica = connectPlayer(1)
MatchService.start()
advance(0.21)
assert(Workspace:GetAttribute("NeonMatchPhase") == "WAITING")
assert(Workspace:GetAttribute("NeonMatchRound") == 0)

local hud = newHud(first, replica, function(...)
    remotes.ReturnToFfa.OnServerEvent:fire(...)
end)
hud.delay(1)
hud.open()
assert(#hud.returns == 1 and hud.returns[1][1] == "WAITING" and hud.returns[1][2] == 0)
local second = connectPlayer(2)
advance(0.4)
assert(Workspace:GetAttribute("NeonMatchPhase") == "COUNTDOWN" and #transfers == 0)
remotes.ReturnToFfa.OnServerEvent:fire(first, "WAITING", -1)
assert(not Room.isClosing(), "A return from a different round closed the countdown")
advance(0.61)
assert(Room.isClosing() and #transfers == 1 and transfers[1].group[1] == first,
    "The return pressed in WAITING was lost when the opponent arrived")
advance(0.25)
assert(#transfers == 2 and transfers[2].group[1] == second,
    "Both participants must be offered a return when the countdown closes")
assert(Workspace:GetAttribute("NeonMatchPhase") == "WAITING")
print("Duel arrival regression: a return in flight still applies across the lobby countdown.")
"""

ROSTER_RECOVERY_CHECKS = r"""
rosterReadBlocked = true
local first, replica = connectPlayer(1)
MatchService.start()
local hud = newHud(first, replica, function(...)
    remotes.ReturnToFfa.OnServerEvent:fire(...)
end)
advance(11.9)
assert(#transfers == 0 and not first.kickReason, "The roster should be retried before falling back")
advance(0.2)
assert(not first.kickReason and #transfers == 1 and transfers[1].group[1] == first,
    "A player whose room cannot be verified should be sent back to FFA")
assert(not transfers[1].options.ReservedServerAccessCode)
assert(#Room.players() == 0 and Room.combatantCount() == 0 and not Room.isClosing())

Teleport.TeleportInitFailed:fire(first, nil, nil, game.PlaceId, transfers[1].options)
advance(1.51)
assert(#transfers == 2 and transfers[2].group[1] == first, "The FFA fallback should retry once")
Teleport.TeleportInitFailed:fire(first, nil, nil, game.PlaceId, transfers[2].options)
advance(0.41)
assert(replica:GetAttribute("IronYardDuelTravel") == "FAILED" and not first.kickReason)
hud.open()
advance(0.41)
assert(#transfers == 3 and transfers[3].group[1] == first, "The FFA button should retry a failed fallback")
assert(not transfers[3].options.ReservedServerAccessCode)

rosterReadBlocked = false
local second = connectPlayer(2)
local outsider = connectPlayer(3)
assert(Room.combatantCount() == 1 and Room.players()[1] == second and not Room.isClosing(),
    "Recovery for one player should keep verified admission available to the other")
assert(outsider.kickReason and #transfers == 3,
    "A verified roster must still reject a player absent from the reservation")
print("Duel roster regression: a failed roster read offers FFA and preserves verified admission.")
"""

RESULTS_FIXTURE = r"""
local function resultsClient(serverPlayer, player, displayedResultsRound)
    local back = {Activated = signal(), Visible = true, Interactable = true}
    local rematch = {Activated = signal(), Visible = true, Interactable = true}
    local root = {Visible = true}
    local votesSent = 0
    local dropVote = false
    local function delayed(remote, isVote)
        return {FireServer = function(_, ...)
            if isVote then
                votesSent += 1
                if dropVote then return end
            end
            local args = table.pack(...)
            task.delay(1.25, function()
                remote.OnServerEvent:fire(serverPlayer, table.unpack(args, 1, args.n))
            end)
        end}
    end
    local remotes = {
        ReturnToFfa = delayed(remotes.ReturnToFfa),
        SetDuelReady = delayed(remotes.SetDuelReady, true),
    }
"""

DEDICATED_CHECKS = r"""
    serverPlayer.render = render
    return {
        back = back, rematch = rematch,
        votesSent = function() return votesSent end,
        dropVote = function(enabled) dropVote = enabled end,
    }
end

local function reachPhase(target)
    for _ = 1, 250 do
        if Workspace:GetAttribute("NeonMatchPhase") == target then return end
        advance(0.2)
    end
    error("Reserved room never reached " .. target)
end

local first, firstReplica = connectPlayer(1)
local second, secondReplica = connectPlayer(2)
MatchService.start()
reachPhase("RESULTS")
local round = Workspace:GetAttribute("NeonMatchRound")
assert(round == 1 and not Room.isClosing())
local firstArena = DuelSpawnPlan.nextArena(nil, game.JobId)
assert(Workspace:GetAttribute("IronYardDuelArena") == firstArena)
assert(#preparedArenas == 1 and preparedArenas[1] == firstArena)
remotes.SetPracticeRange.OnServerEvent:fire(first, true, 0)
assert(not PracticeMode.active(first) and first:GetAttribute("IronYardPracticeNotice") == "FFA ONLY")
local oldResults = resultsClient(first, firstReplica, round)
oldResults.rematch.Activated:fire()
oldResults.rematch.Activated:fire()
assert(oldResults.votesSent() == 1, "Repeated presses sent the same rematch vote")
assert(oldResults.rematch.Text == "VOTING…" and oldResults.rematch.Interactable,
    "A pending vote should give immediate feedback and retain gamepad selection")
resultsClient(second, secondReplica, round).rematch.Activated:fire()
advance(1.7)
assert(first:GetAttribute("IronYardDuelReady") and second:GetAttribute("IronYardDuelReady"),
    "Both current results buttons must register a vote")
assert(oldResults.rematch.Text == "CANCEL  ·  2/2", "The HUD must reflect acknowledged consent")

-- The request was made from the results screen, but arrives after the
-- scheduler has started the agreed rematch countdown.
advance(9.4)
assert(Workspace:GetAttribute("NeonMatchPhase") == "RESULTS")
assert(Workspace:GetAttribute("NeonMatchTimeLeft") == 1)
oldResults.back.Activated:fire()
oldResults.rematch.Activated:fire()
advance(1.26)
assert(Workspace:GetAttribute("NeonMatchPhase") == "COUNTDOWN")
assert(not Room.isClosing() and #transfers == 0, "An old results action cancelled the rematch")

reachPhase("DUEL_BREAK")
remotes.ReturnToFfa.OnServerEvent:fire(first, "COUNTDOWN", Workspace:GetAttribute("NeonMatchRound"))
assert(not Room.isClosing() and #transfers == 0, "An exit from a lobby screen interrupted an active series")

-- A delayed return from the previous series is also ignored on the
-- next results screen, even though that screen has the same phase.
reachPhase("RESULTS")
local nextRound = Workspace:GetAttribute("NeonMatchRound")
assert(nextRound == round + 1)
local secondArena = DuelSpawnPlan.nextArena(firstArena, game.JobId)
assert(secondArena ~= firstArena and Workspace:GetAttribute("IronYardDuelArena") == secondArena)
assert(#preparedArenas == 2 and preparedArenas[2] == secondArena)
local currentResults = resultsClient(first, firstReplica, nextRound)
oldResults.back.Activated:fire()
oldResults.rematch.Activated:fire()
advance(1.26)
assert(not Room.isClosing() and #transfers == 0, "An old round action closed the current results")
assert(first:GetAttribute("IronYardDuelReady") == false, "A vote from the previous series was counted")

remotes.SetDuelReady.OnServerEvent:fire(first, true)
assert(first:GetAttribute("IronYardDuelReady") == false, "A vote without a results round was counted")
currentResults.rematch.Activated:fire()
advance(1.8)
assert(first:GetAttribute("IronYardDuelReady") == true, "A vote for the current series was rejected")
oldResults.rematch.Activated:fire()
advance(1.26)
assert(first:GetAttribute("IronYardDuelReady") == true, "A cancellation from the previous series changed the vote")
currentResults.rematch.Activated:fire()
assert(currentResults.rematch.Text == "CANCELLING…")
advance(1.7)
assert(first:GetAttribute("IronYardDuelReady") == false, "A cancellation for the current series was rejected")
currentResults.dropVote(true)
currentResults.rematch.Activated:fire()
advance(2.9)
assert(currentResults.rematch.Text == "VOTING…")
advance(0.11)
assert(currentResults.rematch.Text == "REMATCH  ·  0/2", "A missing confirmation must restore the vote action")
currentResults.dropVote(false)
currentResults.rematch.Activated:fire()
advance(1.26)
assert(first:GetAttribute("IronYardDuelReady") == true, "The retry must use the same current series")

-- A response from the current results still closes the reserved room.
currentResults.back.Activated:fire()
advance(1.26)
assert(Room.isClosing() and #transfers == 1 and transfers[1].group[1] == first)

-- Each explicit return gets one automatic retry. A late duplicate failure
-- from its first attempt must neither fail the retry nor start another.
local initial = transfers[1].options
Teleport.TeleportInitFailed:fire(first, nil, nil, game.PlaceId, initial)
advance(1.6)
assert(#transfers == 3 and transfers[2].group[1] == second and transfers[3].group[1] == first,
    "The other player should return when results expire and the first player should retry")
local retry = transfers[3].options
Teleport.TeleportInitFailed:fire(first, nil, nil, game.PlaceId, initial)
assert(first:GetAttribute("IronYardDuelTravel") == "RETURNING", "An expired attempt interrupted the retry")
Teleport.TeleportInitFailed:fire(first, nil, nil, game.PlaceId, retry)
assert(first:GetAttribute("IronYardDuelTravel") == "FAILED")
currentResults.back.Activated:fire()
advance(1.26)
assert(#transfers == 4 and transfers[4].group[1] == first, "Back to FFA must retry a failed transfer")
print("Duel network regression: " .. firstArena .. " -> " .. secondArena
    .. ", round-scoped votes, delayed confirmations and return retries passed.")
"""


TEAM_MATCH_CHECKS = r"""
local function reachPhase(target)
    for _ = 1, 240 do
        if Workspace:GetAttribute("NeonMatchPhase") == target then return end
        advance(0.2)
    end
    error("Team room never reached " .. target)
end

Vector3 = {zero = {}}
local function spawnCharacter(player)
    local humanoid = {Health = 100, MaxHealth = 100}
    local root = {Anchored = false, Parent = true}
    local character = {attributes = {}}
    function character:FindFirstChildOfClass() return humanoid end
    function character:FindFirstChild() return root end
    function character:SetAttribute(name, value) self.attributes[name] = value end
    function root:IsDescendantOf(parent) return parent == character end
    player.Character = character
    return humanoid, root
end

local a, b, c = connectPlayer(1), connectPlayer(2), connectPlayer(3)
local victories = {}
local placements = 0
modules.SpawnService.placeDuelTeams = function(roster, bout, arena)
    assert(roster[1] == a and roster[2] == b and roster[3] == c and roster[4].UserId == 4)
    assert(bout >= 1 and arena)
    placements += 1
    return true
end
modules.SpawnService.clearProtection = noop
modules.MovementService.resetDuelMovement = noop
modules.WeaponService.resetRound = function()
    Workspace:SetAttribute("IronYardFireEpoch", (Workspace:GetAttribute("IronYardFireEpoch") or 0) + 1)
end
modules.CombatAwards.recordVictory = function(player) table.insert(victories, player) end
MatchService.start()
advance(7)
assert(Workspace:GetAttribute("NeonMatchPhase") == "WAITING" and placements == 0)
assert(Workspace:GetAttribute("IronYardDuelSize") == 4)
local d = connectPlayer(4)
local intruder = connectPlayer(5)
assert(intruder.kickReason and Room.combatantCount() == 4)
for _, operator in ipairs({a,b,c,d}) do spawnCharacter(operator) end

reachPhase("DUEL_PREP")
local _, oldRoot = c.Character:FindFirstChildOfClass(), c.Character:FindFirstChild()
assert(oldRoot.Anchored)
spawnCharacter(c)
advance(0.21)
assert(Workspace:GetAttribute("NeonMatchPhase") == "DUEL_BREAK" and not oldRoot.Anchored,
    "Replacing one rig must release the other preparation anchors")
reachPhase("LIVE")
assert(Workspace:GetAttribute("IronYardDuelBout") == 1, "Interrupted prep consumed a live bout")
assert(Workspace:GetAttribute("IronYardDuelPlayerA2") == c.UserId)
assert(Workspace:GetAttribute("IronYardDuelPlayerB2") == d.UserId)
assert(DuelCombatState.canDamage(c, d, d.Character, "LIVE", "DUEL", 4))
assert(not DuelCombatState.canDamage(c, a, a.Character, "LIVE", "DUEL", 4))
assert(not DuelCombatState.canFire(intruder, "LIVE", "DUEL", 4))
local originalD = d.Character
spawnCharacter(d)
assert(d.Character ~= originalD and not DuelCombatState.canFire(d, "LIVE", "DUEL", 4))
advance(0.21)
assert(Workspace:GetAttribute("NeonMatchPhase") == "LIVE", "A single teammate death ended the bout")
b.Character:FindFirstChildOfClass().Health = 0
reachPhase("DUEL_BREAK")
assert(Workspace:GetAttribute("IronYardDuelScoreA") == 1)
spawnCharacter(b)
for bout = 2, 5 do
    reachPhase("LIVE")
    assert(Workspace:GetAttribute("IronYardDuelBout") == bout)
    b.Character:FindFirstChildOfClass().Health = 0
    d.Character:FindFirstChildOfClass().Health = 0
    reachPhase(bout < 5 and "DUEL_BREAK" or "RESULTS")
    spawnCharacter(b)
    spawnCharacter(d)
end
local firstResult = Workspace.lastDuelResult
assert(firstResult.winner == "TEAM A" and firstResult.winnerTeam == 1)
assert(table.concat(firstResult.teams[1], ",") == "1,3")
assert(#victories == 2 and victories[1] == a and victories[2] == c)
local round = Workspace:GetAttribute("NeonMatchRound")
for _, operator in ipairs({a,b,c,d}) do
    remotes.SetDuelReady.OnServerEvent:fire(operator, true, nil, nil, round - 1)
    assert(not operator:GetAttribute("IronYardDuelReady"))
    remotes.SetDuelReady.OnServerEvent:fire(operator, true, nil, nil, round)
    assert(operator:GetAttribute("IronYardDuelReady"))
end
reachPhase("COUNTDOWN")
reachPhase("LIVE")
assert(Workspace:GetAttribute("IronYardDuelPlayerA2") == c.UserId, "Rematch split the original team")
c.Parent = nil
Players.PlayerRemoving:fire(c)
reachPhase("RESULTS")
local forfeit = Workspace.lastDuelResult
assert(forfeit.reason == "FORFEIT" and forfeit.winnerTeam == 2)
assert(#victories == 2, "Forfeit was credited as a completed victory")
advance(12.1)
assert(#transfers == 3 and Room.isClosing(), "Every remaining player must receive the FFA transfer")
for _, transfer in ipairs(transfers) do assert(not transfer.options.ReservedServerAccessCode) end
print("2v2 match: admission, prep retry, friendly-fire, no second life, victory, rematch and forfeit passed.")
"""


def module(name, path, replacements=None):
    source = (ROOT / path).read_text()
    for original, replacement in (replacements or {}).items():
        assert original in source, f"Missing fixture injection in {path}: {original}"
        source = source.replace(original, replacement)
    return f"\nlocal {name} = (function()\n{source}\nend)()\n"


def run(luau):
    mode = module("PracticeMode", "src/shared/PracticeMode.luau")
    queue = module("Queue", "src/shared/DuelQueue.luau")
    room = module("Room", "src/server/DuelRoom.luau", {
        'local Queue = require(Shared:WaitForChild("DuelQueue"))': "local Queue = Queue",
        'local PracticeMode = require(Shared:WaitForChild("PracticeMode"))': "local PracticeMode = PracticeMode",
    })
    hud = (ROOT / "src/client/MatchHud.client.luau").read_text()
    hud_source = hud[hud.index('local function duelButton('):hud.index("UserInputService.InputBegan:Connect")]
    lobby_client = HUD_FIXTURE + hud_source + HUD_ENTRY_POINT
    touch_layout = module("TouchLayout", "src/shared/TouchLayout.luau")
    lobby = SERVER_FIXTURE + mode + queue + room + touch_layout + lobby_client + CHECKS
    results = (ROOT / "src/client/RoundResults.client.luau").read_text()
    rematch_state = results[results.index("local rematchRequest"):results.index("local function syncResultSelection")]
    results_render = """
    render = function()
        renderRematch(true, false, true, Workspace:GetAttribute("IronYardDuelReadyCount") or 0)
    end
    """
    results_actions = results[results.index("rematch.Activated:Connect"):results.index("local function safeCount")]
    dedicated_server = (
        SERVER_FIXTURE + mode + queue
        + '\ngame.PrivateServerId = "reserved"\nrosters.reserved = {1, 2}\n' + room
        + module("DuelRules", "src/shared/DuelRules.luau")
        + module("DuelCombatState", "src/server/DuelCombatState.luau")
        + module("DuelSpawnPlan", "src/shared/DuelSpawnPlan.luau")
        + module("MatchLobbyPolicy", "src/shared/MatchLobbyPolicy.luau")
        + module("RoundStandings", "src/server/RoundStandings.luau")
        + DEDICATED_FIXTURE + module("MatchService", "src/server/MatchService.luau")
    )
    dedicated = dedicated_server + RESULTS_FIXTURE + rematch_state + results_render + results_actions + DEDICATED_CHECKS
    dedicated_with_hud = dedicated_server + touch_layout + lobby_client
    fixtures = {
        "lobby": lobby,
        "team-lobby": SERVER_FIXTURE + mode + queue + room + touch_layout + lobby_client + TEAM_LOBBY_CHECKS,
        "team-match": dedicated_server.replace("rosters.reserved = {1, 2}", "rosters.reserved = {1, 2, 3, 4}")
        + TEAM_MATCH_CHECKS,
        "dedicated-sorting-first": dedicated,
        "dedicated-yard-first": dedicated.replace(
            'game.PrivateServerId = "reserved"',
            'game.PrivateServerId = "reserved"\ngame.JobId = "0000"',
            1,
        ),
        "waiting-exit": dedicated_with_hud + WAITING_EXIT_CHECKS,
        "roster-recovery": dedicated_with_hud + ROSTER_RECOVERY_CHECKS,
    }
    with TemporaryDirectory() as directory:
        for name, program in fixtures.items():
            fixture = Path(directory) / f"duel-network-{name}.luau"
            fixture.write_text(program)
            subprocess.run([str(Path(luau).resolve()), str(fixture)], check=True)


if __name__ == "__main__":
    run(sys.argv[1])
