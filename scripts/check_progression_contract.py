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
    awards = read("src/server/CombatAwards.luau")
    weapon = read("src/server/WeaponService.luau")
    match = read("src/server/MatchService.luau")
    startup = read("src/server/init.server.luau")
    ui = read("src/client/ProgressionHud.client.luau")
    doc = read("docs/PROGRESSION_PERSISTENCE.md")
    hud = read("src/client/CombatAwards.client.luau")

    contains(data, (
        'STORE_NAME = "IronYard_Progression_v1"',
        'return "player_" .. tostring(player.UserId)',
        'Ledger = require(script.Parent:WaitForChild("ProgressionLedger"))',
        'return Ledger.acquire(previous, record.token, timestamp, LEASE_SECONDS)',
        'return Ledger.commit(previous, record.token, snapshot, timestamp,',
        "local function acquire(player, record)",
        "local function flush(player, record, release)",
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
    ), "DataStore lease/recovery")

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
        "data.lock = nil",
    ), "Pure idempotent DataStore ledger")

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
        "local selectedPlayer = nil",
        "selectedPlayer = player",
        "selectedPlayer = nil",
        "return selectedName, best, tied, selectedPlayer",
        "local name, topScore, tied, winningPlayer = leader()",
        "if winningPlayer and winningPlayer.Parent then",
        "CombatAwards.recordVictory(winningPlayer)",
    ), "Winner identity")

    require("DataStoreService" not in ui, "HUD may not access Roblox DataStore")
    require('IronYardProgressStatus' in ui, "HUD must announce saving state")
    require("SAVE NOT CONFIRMED" in ui, "HUD must display failure")
    require("STUDIO / SESSION ONLY" in ui, "Studio cannot pretend data is saved")
    require("ONLINE" in ui, "No success indication for confirmed DataStore access")
    require("CombatAward" in hud, "Session medal feedback must remain intact")

    contains(doc.lower(), ("updateasync", "idempotent", "45", "180", "studio",
                           "published experience", "not a transaction guarantee"),
             "Progression runbook")
    print("IRON YARD persistent progression source contracts: OK")
    print("NOTE: real Roblox DataStore read/write/reconnect tests are still required.")


if __name__ == "__main__":
    main()
