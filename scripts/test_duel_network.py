"""Exercise the production duel HUD and lobby together with delayed delivery."""

import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]

SERVER_FIXTURE = r"""
local now = 1000
local tasks = {}
local task = {}
function task.delay(delay, callback)
    local job = {at = now + delay, callback = callback}
    table.insert(tasks, job)
    return job
end
function task.cancel(job) job.cancelled = true end
function task.spawn(callback, ...) callback(...) end
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

local Workspace = {}
function Workspace:GetServerTimeNow() return now end
function Workspace:GetAttribute(key)
    if key == "NeonMatchPhase" then return "LIVE" end
    if key == "IronYardMatchMode" then return "FFA" end
end
local reservations, attempts = 0, 0
local transfers, rosters = {}, {}
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
        return {SetAsync = function(_, roomId, ids)
            rosters[roomId] = ids
            return true
        end}
    end},
    HttpService = {JSONEncode = function() return "{}" end, GenerateGUID = function()
        attempts += 1
        return tostring(attempts)
    end},
    RunService = {IsStudio = function() return false end},
    ReplicatedStorage = {WaitForChild = function(self) return self end},
}
local game = {PrivateServerId = "", PrivateServerOwnerId = 0, PlaceId = 99}
function game:GetService(name) return assert(services[name]) end
local Instance = {new = function()
    return {SetTeleportData = function(self, value) self.payload = value end}
end}
local function connectPlayer(id)
    local p = {UserId = id, DisplayName = "Player " .. id, Parent = Players}
    local authoritative, replicated = {}, {}
    local client = {}
    function client:GetAttribute(key) return replicated[key] end
    function p:GetAttribute(key) return authoritative[key] end
    function p:SetAttribute(key, value)
        if authoritative[key] == value then return end
        authoritative[key] = value
        task.delay(self.downstream, function()
            replicated[key] = value
            self.render()
        end)
    end
    p.downstream = 0.4
    Players.online[id] = p
    return p, client
end
"""

HUD_FIXTURE = r"""
local function newHud(serverPlayer, player)
    local upstream = 0.4
    local sent = {}
    local function activeControl()
        return {Activated = signal(), Visible = true, Interactable = true, Selectable = true}
    end
    local menu, gui = {Visible = false}, {}
    local search, invite, decline = activeControl(), activeControl(), activeControl()
    local close, duelToggle, quickCancel = activeControl(), activeControl(), activeControl()
    local status, roster, emptyRoster = {}, {}, {}
    local GuiService = {}
    local UDim2 = {new = function() end, fromOffset = function() end}
    local inputType = {Name = "Touch"}
    local UserInputService = {TouchEnabled = true, GetLastInputType = function() return inputType end}
    local GamepadCombatPolicy = {isGamepad = function(name) return name == "Gamepad1" end}
    local playerGui = {SetAttribute = function() end, GetAttribute = function() end}
    local remotes = {ReturnToFfa = {}}
    remotes.SetDuelReady = {FireServer = function(_, ...)
        local args = table.pack(...)
        table.insert(sent, args)
        local deliver = function() Room.request(serverPlayer, table.unpack(args, 1, args.n)) end
        task.delay(upstream, deliver)
    end}
    local function refreshInviteRows() end
    local function updateRoster() end
"""

CHECKS = r"""
    serverPlayer.render = duelLabel
    duelLabel()
    return {
        open = toggleDuel, search = search, invite = invite, decline = decline, status = status,
        sent = sent, delay = function(seconds) upstream = seconds end,
    }
end

Room.start()
local sender, senderReplica = connectPlayer(1)
local recipient, recipientReplica = connectPlayer(2)
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
print("Duel network regression: slow confirmation, stale invitation, decline, acceptance and shared reservation passed.")
"""


def run(luau):
    queue = (ROOT / "src/shared/DuelQueue.luau").read_text()
    room = (ROOT / "src/server/DuelRoom.luau").read_text().replace(
        'local Queue = require(Shared:WaitForChild("DuelQueue"))', "local Queue = Queue"
    )
    hud = (ROOT / "src/client/MatchHud.client.luau").read_text()
    hud_sections = (
        hud[hud.index("local states = {"):hud.index("local function refreshInviteRows()")],
        hud[hud.index("local displayedInvitation"):hud.index("UserInputService.InputBegan:Connect")],
    )
    program = (
        SERVER_FIXTURE
        + "\nlocal Queue = (function()\n" + queue + "\nend)()\n"
        + "local Room = (function()\n" + room + "\nend)()\n"
        + HUD_FIXTURE + "\n".join(hud_sections) + CHECKS
    )
    with TemporaryDirectory() as directory:
        fixture = Path(directory) / "duel-network.luau"
        fixture.write_text(program)
        subprocess.run([str(Path(luau).resolve()), str(fixture)], check=True)


if __name__ == "__main__":
    run(sys.argv[1])
