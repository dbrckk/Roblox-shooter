#!/usr/bin/env python3
"""Fail-closed static integration contracts for Iron Yard durable progression.

These checks are supplementary: only Roblox servers can exercise DataStore
transactions, lock expiry, throttling and live player reconnect behavior.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str):
    if not condition:
        raise AssertionError(message)


def contains(text: str, items, scope: str):
    for item in items:
        require(item in text, f"{scope} is missing {item!r}")


def main():
    data = read("src/server/ProgressionService.luau")
    ledger = read("src/server/ProgressionLedger.luau")
    shutdown_tracker = read("src/server/ProgressionShutdownTracker.luau")
    detached_policy = read("src/server/ProgressionDetachedRelease.luau")
    workflow = read(".github/workflows/rojo-build.yml")
    awards = read("src/server/CombatAwards.luau")
    weapon = read("src/server/WeaponService.luau")
    match = read("src/server/MatchService.luau")
    startup = read("src/server/init.server.luau")
    ui = read("src/client/ProgressionHud.client.luau")
    podium = read("src/client/RoundResults.client.luau")
    readout = read("src/shared/CareerReadout.luau")
    doc = read("docs/PROGRESSION_PERSISTENCE.md")
    hud = read("src/client/CombatAwards.client.luau")

    contains(data, (
        'STORE_NAME = "IronYard_Progression_v1"',
        'return "player_" .. tostring(player.UserId)',
        'Ledger = require(script.Parent:WaitForChild("ProgressionLedger"))',
        'return Ledger.acquire(previous, record.token, timestamp, LEASE_SECONDS)',
        'return Ledger.commit(previous, record.token, snapshot, timestamp,',
        "local function acquire(player, record)",
        "local flush -- acquisition may finish after a player has already left",
        "flush = function(player, record, release)",
        "if not ok or not released then",
        'require(script.Parent:WaitForChild("ProgressionDetachedRelease"))',
        "queueDetachedRelease(player, record)",
        "while record.saving and os.clock() < untilTime do",
        "store:UpdateAsync(keyFor(player), function(previous)",
        "local snapshot = cloneSnapshot(record.earned)",
        "record.triedAcquire = true",
        "function ProgressionService.recordElimination(player, points, headshot)",
        "function ProgressionService.recordVictory(player)",
        "function ProgressionService.start()",
        "Players.PlayerRemoving:Connect",
        "game:BindToClose(function()",
        "RunService:IsStudio()",
        'setStatus(player, record, "STUDIO")',
        "loadOrRetry(player, record)",
        "player:SetAttribute(\"IronYardProgressStatus\", status)",
        '"IronYardLifetimeXP"',
        '"IronYardSavedXP"',
        'math.min(earned.xp, record.committed.xp)',
        'record.earned = Ledger.applyGrant(record.earned, deltas)',
    ), "DataStore lease/recovery")
    require("record.earned[field] += amount" not in data,
            "Unsafe partial progression award mutation must not return")
    contains(shutdown_tracker, (
        "function Tracker.new()",
        "function Tracker.begin(state)",
        "function Tracker.finish(state)",
        "function Tracker.hasPending(state)",
        "state.count += 1",
        "state.count -= 1",
    ), "Pure in-flight shutdown operation tracker")
    contains(data, (
        'require(script.Parent:WaitForChild("ProgressionShutdownTracker"))',
        "local shutdownTracker = ShutdownTracker.new()",
        "ShutdownTracker.begin(shutdownTracker)",
        "ShutdownTracker.finish(shutdownTracker)",
        "ShutdownTracker.hasPending(shutdownTracker)",
        "if not record.closing and (record.loaded or record.triedAcquire) then",
    ), "Roblox DataStore shutdown accounting")
    contains(detached_policy, (
        "function Detached.claim(record)",
        "record.detachedReleaseQueued = true",
        "record.detachedReleaseQueued == true",
    ), "Single-flight detached release guard")
    require("scripts/test_progression_detached_release.luau" in workflow,
            "Executable slow-autosave departure regression must run in CI")
    require("scripts/test_progression_recovery.luau" in workflow,
            "Executable out-of-order and departure DataStore scenarios must run in CI")

    # A2: every degraded state must stay explicit, so no save can look confirmed.
    for degraded in (
        'setStatus(player, record, "STUDIO")',
        'setStatus(player, record, success and "LOCKED" or "RETRYING")',
        'RunService:IsStudio() and "STUDIO" or "UNAVAILABLE"',
    ):
        require(degraded in data,
                f"Degraded progression status is missing: {degraded}")
    require("Scénarios hors ordre et départ de joueur" in doc,
            "A2 scenarios must be documented in docs/PROGRESSION_PERSISTENCE.md")
    queued = data.index("queueDetachedRelease = function(player, record)")
    worker = data[queued:data.index("\nlocal function loadOrRetry(", queued)]
    require(worker.index("DetachedRelease.claim(record)") < worker.index(
        "ShutdownTracker.begin(shutdownTracker)") < worker.index("task.spawn(function()"),
        "One final release slot must be claimed and tracked before scheduling work")
    require("if record.saving then return false end" in worker
            and "if flush(player, record, true) then return true end" in worker,
            "Detached release must wait for busy autosave and attempt owned final save")
    late = data[data.index("if not isLive(player, record) then"):queued]
    require(late.index("queueDetachedRelease(player, record)")
            < late.index("ShutdownTracker.finish(shutdownTracker)"),
            "Late acquisition MUST queue final release before finishing acquire slot")
    removing = data.split("Players.PlayerRemoving:Connect(function(player)", 1)[1].split(
        "\n    task.spawn(function()", 1)[0]
    require(removing.index("released = flush(player, record, true)")
            < removing.index("queueDetachedRelease(player, record)")
            < removing.index("records[player] = nil"),
            "PlayerRemoving must schedule final save after timeout before unlinking player")
    require("while (pending > 0 or ShutdownTracker.hasPending(shutdownTracker))" in data,
            "BindToClose must wait for completed-Player detached saves")

    contains(ledger, (
        "function Ledger.normalize(raw)",
        "function Ledger.copyStats(value)",
        "raw.schema == 1",
        "function Ledger.acquire(previous, token, timestamp, leaseSeconds)",
        "function Ledger.commit(previous, token, earnedSnapshot, timestamp, leaseSeconds, release)",
        "lock.owner ~= token", "lock.expiresAt > timestamp",
        "lock.owner == token", "snapshot[field] - committed",
        "math.max(committed, snapshot[field])",
        "data.lastSession.owner == token",
        "data.lastSession.committed[field] < snapshot[field]",
        'assert(committed[field] <= data[field],',
        '"Progression lock exceeds stored counter: " .. field',
        '"Progression release exceeds stored counter: " .. field',
        "data.lock = nil",
        "function Ledger.applyGrant(earned, deltas)",
        'assert(safeInt(timestamp + leaseSeconds),',
        '"Progression lease expiry overflow"',
        'assert(safeInt(delta) and delta <= 10000,',
        'assert(safeInt(updated), "Progression session counter overflow: " .. field)',
        "return nextEarned",
    ), "Pure idempotent DataStore ledger")

    require(ledger.count("assert(committed[field] <= data[field],") == 2,
            "Active locks and completed releases must both reject false saved progress")
    require(ledger.index('"Progression lock exceeds stored counter: " .. field')
            < ledger.index('"Progression release exceeds stored counter: " .. field'),
            "Check lock and marker invariants when normalizing records")
    require('lock.expiresAt = math.max(lock.expiresAt, timestamp + leaseSeconds)' in ledger,
            "Out-of-order acquire retry must not reduce the existing owner's expiry")
    require('data.lock.expiresAt = math.max(data.lock.expiresAt,' in ledger
            and 'timestamp + leaseSeconds)' in ledger,
            "Out-of-order autosave must not reduce the existing owner's expiry")
    require('lock and lock.owner ~= token and lock.expiresAt > timestamp' in ledger,
            "Another server must still wait until the active lease expires")
    require("if release and data.lastSession" in ledger,
            "Previously released sessions need idempotent acknowledgement after a new lease")
    require("publish(player, record)" in data.split("local function flush(player, record, release)")[-1]
            or "publish(player, record)" in data.split("flush = function(player, record, release)")[-1],
            "Successful DataStore saves must refresh the saved counter")
    require(data.count("store:UpdateAsync(") == 2,
            "Acquisition and every save must use UpdateAsync")
    for unsafe in ("store:SetAsync(", "store:IncrementAsync(", "GetDataStore("):
        if unsafe == "GetDataStore(":
            require(data.count("GetDataStore(") >= 1, "Missing named datastore init")
        else:
            require(unsafe not in data, "Progression must not use blind writes")

    require(startup.index("ProgressionService.start()") < startup.index("CombatAwards.start()"),
            "Persistence must initialize before combat rewards")
    require(awards.count("ProgressionService.recordVictory(") == 1,
            "Round win XP must originate in server-verified combat awards")
    require(awards.count("ProgressionService.recordElimination(") == 1,
            "Exactly one persistent grant per server-verified kill")
    require(weapon.count("CombatAwards.recordElimination(") == 2,
            "Hitscan and shotgun must both feed server-confirmed awards")
    contains(match, (
        'local RoundStandings = require(script.Parent:WaitForChild("RoundStandings"))',
        "finalResult = currentStandings()",
        "Workspace:SetAttribute(\"IronYardFinalStandings\"",
        "if finalResult.winnerUserId > 0 then",
        "Players:GetPlayerByUserId(finalResult.winnerUserId)",
        "if winningPlayer and winningPlayer.Parent then",
        "CombatAwards.recordVictory(winningPlayer)",
    ), "Winner identity and frozen result snapshot")

    require("DataStoreService" not in ui and "DataStoreService" not in podium,
            "Client display must never access a DataStore")
    for client, scope in ((ui, "Career HUD"), (podium, "Results podium")):
        contains(client, ('Shared:WaitForChild("CareerReadout")',
                          'CareerReadout.save(', "IronYardSavedXP",
                          "IronYardProgressStatus"), scope + " save-status wiring")
    contains(readout, ("function Readout.save(status, xp, savedXP)",
                       "function Readout.rank(xp, level)",
                       "acknowledged == earned", "acknowledged < earned",
                       "CAREER / SAVED", "XP SAVE PENDING",
                       "STUDIO / SESSION ONLY", "SAVE NOT CONFIRMED",
                       "CAREER / SYNCING..."), "Pure save-status policy")
    require("saveLabel.Text = saveInfo.label" in podium,
            "Round results must show the current save state")
    require('player:GetAttributeChangedSignal(attr):Connect(render)' in podium,
            "Podium must react when saved XP is acknowledged")
    require("CareerReadout.rank(xp, level)" in ui and
            "CareerReadout.rank(xp, level)" in podium,
            "Both displays must share rank computation")
    require("CombatAward" in hud, "Medal feedback must remain intact")

    contains(doc.lower(), ("updateasync", "idempotent", "45", "180", "studio",
                           "published experience", "not a transaction guarantee"),
             "Progression runbook")
    print("IRON YARD persistent progression source contracts: OK")
    print("NOTE: real Roblox DataStore read/write/reconnect tests are still required.")


if __name__ == "__main__":
    main()
