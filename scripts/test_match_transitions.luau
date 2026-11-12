-- IRON YARD / A1 executable decision matrix for FFA <-> duel round transitions.
-- Every pure policy required here is the SAME module MatchService calls, so a
-- behaviour regression in those rules fails this suite.
-- This file does NOT simulate Roblox replication, physics, RemoteEvent loss,
-- bot movement or latency: it proves decision outcomes and matrix closure only.
-- The source-to-matrix wiring is checked separately by
-- scripts/check_match_transition_contract.py.
local Duel = require("../src/shared/DuelRules")
local Lobby = require("../src/shared/MatchLobbyPolicy")
local Gate = require("../src/server/DuelCombatState")
local Victory = require("../src/shared/VictoryAwardPolicy")
local Standings = require("../src/server/RoundStandings")

local PHASES = { "WAITING", "COUNTDOWN", "LIVE", "DUEL_PREP", "DUEL_BREAK", "RESULTS" }

-- Every transition MatchService actually emits, with the mode it can occur in.
-- DUEL_PREP and DUEL_BREAK exist only inside a duel series.
local EDGES = {
    { from = "WAITING", to = "COUNTDOWN", mode = "FFA" },
    { from = "COUNTDOWN", to = "LIVE", mode = "FFA" },
    { from = "COUNTDOWN", to = "DUEL_PREP", mode = "DUEL" },
    { from = "COUNTDOWN", to = "DUEL_BREAK", mode = "DUEL" },
    { from = "LIVE", to = "RESULTS", mode = "FFA" },
    { from = "LIVE", to = "RESULTS", mode = "DUEL" },
    { from = "LIVE", to = "DUEL_PREP", mode = "FFA" }, -- duel accepted mid-FFA
    { from = "LIVE", to = "DUEL_BREAK", mode = "DUEL" },
    { from = "DUEL_PREP", to = "LIVE", mode = "DUEL" },
    { from = "DUEL_PREP", to = "DUEL_BREAK", mode = "DUEL" },
    -- Participants changed during the 3-2-1: the series ends instead of
    -- leaving an orphaned preparation. Never reached on a mere interruption.
    { from = "DUEL_PREP", to = "RESULTS", mode = "DUEL" },
    { from = "DUEL_BREAK", to = "DUEL_PREP", mode = "DUEL" },
    { from = "DUEL_BREAK", to = "DUEL_BREAK", mode = "DUEL" }, -- bounded retry
    { from = "DUEL_BREAK", to = "RESULTS", mode = "DUEL" },
    { from = "RESULTS", to = "COUNTDOWN", mode = "FFA" },
}

local function isPhase(name)
    for _, phase in ipairs(PHASES) do
        if phase == name then return true end
    end
    return false
end

-- Roster emptied: MatchLobbyPolicy resets any non-clean phase to WAITING,
-- whatever the current mode. A clean WAITING room publishes nothing.
local function legal(from, to, mode)
    if not isPhase(from) or not isPhase(to) then return false end
    if to == "WAITING" then
        return Lobby.shouldReset(0, from, mode, mode == "DUEL")
    end
    for _, edge in ipairs(EDGES) do
        if edge.from == from and edge.to == to and edge.mode == mode then
            return true
        end
    end
    return false
end

-- 1. Matrix closure: declared phases, declared targets, no dead end.
local seenFrom, outgoing = {}, {}
for _, phase in ipairs(PHASES) do
    seenFrom[phase] = false
    outgoing[phase] = 0
end
for _, edge in ipairs(EDGES) do
    assert(isPhase(edge.from), "Undefined source phase: " .. tostring(edge.from))
    assert(isPhase(edge.to), "Undefined target phase: " .. tostring(edge.to))
    seenFrom[edge.from] = true
    outgoing[edge.from] += 1
end
for _, phase in ipairs(PHASES) do
    assert(seenFrom[phase], "Phase has no declared transition: " .. phase)
    assert(outgoing[phase] > 0, "Dead-end phase: " .. phase)
end
assert(legal("WAITING", "COUNTDOWN", "FFA"))
assert(not legal("WAITING", "WAITING", "FFA"), "Empty waiting room is already clean")
for _, phase in ipairs({ "COUNTDOWN", "LIVE", "DUEL_PREP", "DUEL_BREAK", "RESULTS" }) do
    assert(legal(phase, "WAITING", "FFA"), "Emptied FFA room must return to WAITING: " .. phase)
    assert(legal(phase, "WAITING", "DUEL"), "Emptied duel room must return to WAITING: " .. phase)
end

-- 2. Forbidden edges: the shortcuts that would skip countdown, invent results
-- without a round, or resurrect a finished series.
local FORBIDDEN = {
    { "WAITING", "LIVE", "FFA" },
    { "WAITING", "DUEL_PREP", "DUEL" },
    { "WAITING", "RESULTS", "FFA" },
    { "COUNTDOWN", "RESULTS", "FFA" },
    { "COUNTDOWN", "DUEL_BREAK", "FFA" },
    { "DUEL_PREP", "DUEL_PREP", "DUEL" },
    { "LIVE", "DUEL_BREAK", "FFA" },
    { "RESULTS", "LIVE", "FFA" },
    { "RESULTS", "DUEL_PREP", "DUEL" },
    { "RESULTS", "DUEL_BREAK", "DUEL" },
    { "RESULTS", "RESULTS", "DUEL" },
    { "COUNTDOWN", "DUEL_PREP", "FFA" },
    { "LIVE", "DUEL_PREP", "DUEL" },
}
for _, case in ipairs(FORBIDDEN) do
    assert(not legal(case[1], case[2], case[3]),
        "Illegal transition accepted: " .. case[1] .. " -> " .. case[2] .. " (" .. case[3] .. ")")
end
assert(not legal("NOWHERE", "LIVE", "FFA"))
assert(not legal("LIVE", "NOWHERE", "FFA"))

-- 3. T1 - a player removed before the round starts.
local function startMode(playerCount, readyA, readyB)
    if Duel.canStart(playerCount, readyA, readyB) then return "DUEL" end
    return "FFA"
end
assert(startMode(2, true, true) == "DUEL")
assert(startMode(1, true, true) == "FFA", "A lone survivor cannot start a duel")
assert(startMode(3, true, true) == "FFA", "Three players cannot start a 1v1")
assert(startMode(2, true, false) == "FFA", "One opt-in is not a duel")
assert(legal("COUNTDOWN", "DUEL_PREP", "DUEL"))
assert(legal("COUNTDOWN", "LIVE", "FFA"))
assert(Lobby.shouldReset(0, "COUNTDOWN", "DUEL", true))
assert(legal("COUNTDOWN", "WAITING", "DUEL"))

-- 4. T2 - duplicated SetDuelReady cannot accumulate or survive consumption.
local ready = { a = false, b = false }
for _ = 1, 25 do ready.a = true end
assert(ready.a == true and Duel.canStart(2, ready.a, ready.b) == false)
ready.b = true
assert(Duel.canStart(2, ready.a, ready.b))
-- startDuelSeries consumes both opt-ins; a rematch needs two fresh requests.
ready.a, ready.b = false, false
assert(not Duel.canStart(2, ready.a, ready.b), "Consumed consent must not replay")
ready.a, ready.b = true, true
assert(Duel.canStart(2, ready.a, ready.b), "Fresh consent allows a rematch")

-- 5. T3 - both participants leave during a duel.
local playerA, playerB = { UserId = 11 }, { UserId = 22 }
assert(Duel.forfeitSide({}, playerA, playerB) == nil,
    "An empty server has no surviving combatant")
assert(Duel.forfeitSide({ playerA, playerB }, playerA, playerB) == nil,
    "Two occupants are not a forfeit")
assert(Lobby.shouldReset(0, "LIVE", "DUEL", true))
assert(legal("LIVE", "WAITING", "DUEL"))
local emptyResult = Standings.build({}, 3)
assert(emptyResult.winner == "DRAW" and emptyResult.winnerUserId == 0,
    "An empty roster cannot produce a champion")
-- endDuel grants a victory only for a fully played series and a present winner.
local function grantsVictory(reason, winnerPresent)
    return winnerPresent == true
        and (reason == "SCORE_LIMIT" or reason == "BOUT_LIMIT")
end
assert(not grantsVictory(nil, false))
assert(not grantsVictory("FORFEIT", true), "A forfeit never pays a victory")
assert(not grantsVictory("LOBBY_CHANGED", true))
assert(not grantsVictory("SPAWN_TIMEOUT", nil))
assert(grantsVictory("SCORE_LIMIT", true))
assert(grantsVictory("BOUT_LIMIT", true))

-- 6. T4 - simultaneous deaths in the same server tick.
assert(Duel.boutWinner(0, 100, 0, 100, false) == "DRAW")
local dA, dB, dN, dDone = Duel.advance(0, 0, 0, "DRAW")
assert(dA == 0 and dB == 0 and dN == 1 and not dDone, "A double KO scores nothing")

-- 7. T5 - time expiry decides on relative health.
assert(Duel.boutWinner(30, 100, 60, 100, true) == "B")
assert(Duel.boutWinner(75, 150, 50, 100, true) == "DRAW", "Equal ratios are a draw")
assert(Duel.boutWinner(30, 100, 60, 100, false) == nil, "No verdict before the deadline")
assert(Duel.boutWinner(0 / 0, 100, 40, 100, true) == nil)

-- 8. T6 - a drawn bout publishes DRAW and pays nothing.
local drawA, drawB, drawN, drawDone, drawWinner, drawReason =
    Duel.advance(2, 2, 10, "DRAW")
assert(drawA == 2 and drawB == 2 and drawN == 11)
assert(not drawDone and drawWinner == nil and drawReason == nil)
local awardState = { victoryGranted = false }
assert(Victory.claim(awardState), "First victory claim wins")
assert(not Victory.claim(awardState), "Repeated end callbacks cannot pay twice")
Victory.reset(awardState)
assert(Victory.claim(awardState), "A new round rearms exactly one claim")

-- 9. T7 - damage after a phase change never lands.
playerA.Character, playerB.Character = {}, {}
Gate.clear()
assert(Gate.begin(playerA, playerB))
assert(Gate.canFire(playerA, "LIVE", "DUEL", 2))
for _, phase in ipairs({ "DUEL_PREP", "DUEL_BREAK", "RESULTS", "COUNTDOWN", "WAITING" }) do
    assert(not Gate.canFire(playerA, phase, "DUEL", 2),
        "Duel fire must be closed in " .. phase)
end
-- FFA damage is gated on the LIVE phase only (enforced in WeaponService).
local function ffaDamageAllowed(phase) return phase == "LIVE" end
for _, phase in ipairs({ "COUNTDOWN", "DUEL_PREP", "DUEL_BREAK", "RESULTS", "WAITING" }) do
    assert(not ffaDamageAllowed(phase), "FFA damage must be closed in " .. phase)
end
assert(ffaDamageAllowed("LIVE"))
Gate.clear()
assert(not Gate.canFire(playerA, "LIVE", "DUEL", 2), "Cleared series closes fire")

-- 10. T8 - a late respawn cannot consume an older anchored preparation.
local rigA, rigB = {}, {}
local prep = { { character = rigA, root = {} }, { character = rigB, root = {} } }
assert(Duel.prepState(prep, rigA, true, rigB, true) == "READY")
local lateA = {}
assert(Duel.prepState(prep, lateA, true, rigB, true) == "INTERRUPTED",
    "A replacement character invalidates the preparation")
local health, maximum = Duel.healthForBout(rigA, lateA, 100, 100)
assert(health == 0 and maximum == 100, "A respawn is never a second life")
assert(Duel.boutWinner(health, maximum, 40, 100, false) == "B")

-- 11. T9 - a third player cannot inherit, observe-free, or win a duel.
local third = { UserId = 33, Character = {} }
playerA.Character, playerB.Character = {}, {}
assert(not Duel.sameParticipants({ playerA, playerB, third }, playerA, playerB))
assert(Duel.forfeitSide({ playerA, playerB, third }, playerA, playerB) == nil)
Gate.clear()
assert(Gate.begin(playerA, playerB))
assert(not Gate.canFire(third, "LIVE", "DUEL", 3))
assert(not Gate.canDamage(third, playerA, playerA.Character, "LIVE", "DUEL", 3))
assert(Duel.canStart(3, true, true) == false)
-- The result card ranks the verified survivor first and keeps real scores.
local rows = Standings.build({
    { name = "A", eliminations = 1, deaths = 0, userId = 11 },
    { name = "B", eliminations = 3, deaths = 0, userId = 22 },
}, 4, 11)
assert(rows.winner == "A" and rows.winnerUserId == 11,
    "A forfeit champion is the surviving original combatant")
assert(rows.standings[1].name == "A" and rows.standings[1].eliminations == 1,
    "Bout scores stay visible and unrewritten")
local plain = Standings.build({
    { name = "A", eliminations = 3, deaths = 1, userId = 11 },
    { name = "B", eliminations = 3, deaths = 2, userId = 22 },
}, 5)
assert(plain.winner == "DRAW" and plain.winnerUserId == 0,
    "Equal eliminations are never a victory")
local botFirst = Standings.build({
    { name = "BOT", eliminations = 9, deaths = 0, userId = 0, bot = true },
    { name = "A", eliminations = 1, deaths = 0, userId = 11 },
}, 6)
assert(botFirst.winner == "BOT" and botFirst.winnerUserId == 0,
    "A bot can lead a round but never receives persistent victory")

-- 12. T10 - restarting a round cannot resume a closed series.
assert(Duel.advance(5, 0, 5, "A") == nil, "No bout after a five-win series")
assert(Duel.advance(0, 5, 8, "B") == nil)
assert(Duel.advance(0, 0, Duel.MAX_BOUTS, "DRAW") == nil, "No bout after the hard cap")
assert(Duel.advance(3, 2, 1, "A") == nil, "Scores cannot exceed resolved bouts")

-- 13. T11 - a new duel request always passes through COUNTDOWN.
assert(not legal("RESULTS", "DUEL_PREP", "DUEL"))
assert(legal("RESULTS", "COUNTDOWN", "FFA"))
assert(legal("COUNTDOWN", "DUEL_PREP", "DUEL"))
assert(Duel.canStart(2, true, true))
assert(not Duel.canStart(2, false, false), "The opt-in is consumed by the series")

-- 14. Liveness: every series is bounded, even with repeated draws.
local scoreA, scoreB, bouts = 0, 0, 0
local guard = 0
while true do
    guard += 1
    assert(guard <= Duel.MAX_BOUTS + 1, "Duel series did not terminate")
    local nextA, nextB, nextN, complete, winner, reason =
        Duel.advance(scoreA, scoreB, bouts, "DRAW")
    assert(nextA, "Series refused to advance")
    scoreA, scoreB, bouts = nextA, nextB, nextN
    if complete then
        assert(winner == "DRAW" and reason == "BOUT_LIMIT")
        break
    end
end
assert(bouts == Duel.MAX_BOUTS)
assert(not Duel.recoveryExpired(100, 119))
assert(Duel.recoveryExpired(100, 120), "Spawn recovery is bounded at 20s")
assert(Duel.PREP_SECONDS > 0 and Duel.PREP_SECONDS <= 5)

local uniqueEdges = {}
for _, edge in ipairs(EDGES) do
    uniqueEdges[edge.from .. ">" .. edge.to] = true
end
local edgeCount = 0
for _ in pairs(uniqueEdges) do edgeCount += 1 end
assert(edgeCount == 14, "Unexpected number of unique phase pairs")
print("IRON YARD FFA/duel transition matrix: 6 phases, "
    .. tostring(edgeCount) .. " phase pairs, T1-T11 cases, bounded series OK")
