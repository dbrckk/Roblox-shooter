#!/usr/bin/env python3
"""Static wiring checks for the IRON YARD observability core (LOT 0b).

The executable Luau suites own the accounting. This contract guarantees that
the three modules stay pure, server-only and bounded, that the capacity
decision agrees with the bot ceilings already in BotConfig, and that CI runs
the suites. It never claims a real session was observed.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

MODULES = {
    "src/shared/ServerCapacity.luau": [
        "function ServerCapacity.classify(",
        "function ServerCapacity.admits(",
        "function ServerCapacity.botBudget(",
        "function ServerCapacity.freeSlots(",
        "function ServerCapacity.checkPlaceMaxPlayers(",
    ],
    "src/shared/TelemetryFunnel.luau": [
        "function TelemetryFunnel.new(",
        "function TelemetryFunnel.recordJoin(",
        "function TelemetryFunnel.recordKill(",
        "function TelemetryFunnel.recordRound(",
        "function TelemetryFunnel.snapshot(",
    ],
    "src/shared/DiagnosticsLog.luau": [
        "function DiagnosticsLog.new(",
        "function DiagnosticsLog.record(",
        "function DiagnosticsLog.snapshot(",
        "function DiagnosticsLog.saturated(",
    ],
}

SUITES = [
    "scripts/test_server_capacity.luau",
    "scripts/test_telemetry_funnel.luau",
    "scripts/test_diagnostics_log.luau",
]


def source(path):
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition, description):
    if not condition:
        raise AssertionError(description)


def has(src, text, label):
    require(text in src, f"{label}: missing `{text}`")


def lua_constant(src, name):
    match = re.search(rf"{re.escape(name)}\s*=\s*(\d+)", src)
    require(match is not None, f"missing constant {name}")
    return int(match.group(1))


def main():
    texts = {path: source(path) for path in MODULES}
    workflow = source(".github/workflows/rojo-build.yml")
    bot_config = source("src/shared/BotConfig.luau")

    # 1. Observability must never reach a client: no remote, no engine access,
    # no dependency graph, no randomness. The server owns these modules.
    for path, text in texts.items():
        for forbidden in ("game:GetService", "require(", "RemoteEvent",
                          "FireClient", "FireServer", "PrecisionNet",
                          ":WaitForChild", "workspace.", "math.random"):
            require(forbidden not in text,
                    f"{path} must stay pure and server-side: found `{forbidden}`")
        for signature in MODULES[path]:
            has(text, signature, path)

    # 2. No client script may require them: a client copy would be a second,
    # untrusted source of the same numbers.
    client_files = sorted((ROOT / "src/client").rglob("*.luau"))
    for path in client_files:
        text = path.read_text(encoding="utf-8")
        for name in ("ServerCapacity", "TelemetryFunnel", "DiagnosticsLog"):
            require(name not in text,
                    f"{path.relative_to(ROOT)} must not require {name}")

    # 3. The capacity decision is internally consistent and documented.
    capacity = texts["src/shared/ServerCapacity.luau"]
    max_players = lua_constant(capacity, "ServerCapacity.MAX_PLAYERS")
    spectator = lua_constant(capacity, "ServerCapacity.SPECTATOR_SLOTS")
    require(max_players == 12, f"server capacity decision drifted: {max_players}")
    require(spectator == 2, f"spectator slots drifted: {spectator}")
    has(capacity, "ServerCapacity.COMBATANT_LIMIT = ServerCapacity.MAX_PLAYERS"
        " - ServerCapacity.SPECTATOR_SLOTS",
        "combatant limit must be derived from the two documented values")
    has(capacity, "reason = \"UNSET\"",
        "an absent Players.MaxPlayers must stay a reported gap")

    # 4. The policy must agree with the bot ceilings that already exist.
    max_combatants = lua_constant(bot_config, "BotConfig.MaxCombatants")
    max_bots = lua_constant(bot_config, "BotConfig.MaxBots")
    combatant_limit = max_players - spectator
    require(max_combatants <= combatant_limit,
            f"BotConfig.MaxCombatants {max_combatants} exceeds the roster "
            f"limit {combatant_limit}")
    require(max_bots <= combatant_limit,
            f"BotConfig.MaxBots {max_bots} exceeds the roster limit "
            f"{combatant_limit}")
    suite_capacity = source("scripts/test_server_capacity.luau")
    has(suite_capacity, f"local MAX_COMBATANTS = {max_combatants}",
        "capacity suite must mirror BotConfig.MaxCombatants")
    has(suite_capacity, f"local MAX_BOTS = {max_bots}",
        "capacity suite must mirror BotConfig.MaxBots")

    # 5. Bounded memory is the point of the other two modules.
    funnel = texts["src/shared/TelemetryFunnel.luau"]
    for constant in ("TelemetryFunnel.MAX_TRACKED_PLAYERS",
                     "TelemetryFunnel.MAX_TRACKED_WEAPONS",
                     "TelemetryFunnel.MAX_ROUND_SECONDS"):
        has(funnel, constant, "TelemetryFunnel must stay bounded")
    has(funnel, "TelemetryFunnel.OTHER_WEAPON", "overflow bucket must exist")
    log = texts["src/shared/DiagnosticsLog.luau"]
    has(log, "state.evicted = state.evicted + 1", "eviction must be counted")
    has(log, "math.min(capacity, DiagnosticsLog.MAX_CAPACITY)",
        "capacity must be clamped")
    require("table.remove(state.entries, 1)" in log,
            "the log must evict its oldest entry when full")

    # 6. Suites exist, exercise their module and are not placeholders.
    for suite in SUITES:
        text = source(suite)
        module = suite.replace("scripts/test_", "").replace(".luau", "")
        require("require(" in text, f"{suite} must require its module")
        require(len(text.splitlines()) > 50,
                f"{suite} is suspiciously short")

    # 7. CI must run the suites and this contract.
    for suite in SUITES:
        has(workflow, f"./luau {suite}", "rojo-build.yml observability suite step")
    has(workflow, "python3 scripts/check_observability_contract.py",
        "rojo-build.yml observability contract step")

    # 8. The server wiring must use the modules without inventing behaviour:
    # no kick, no remote, no print loop, and starts before the services whose
    # warnings it aggregates.
    service = source("src/server/ObservabilityService.luau")
    bootstrap = source("src/server/init.server.luau")
    for required in (
        'require(Shared:WaitForChild("ServerCapacity"))',
        'require(Shared:WaitForChild("TelemetryFunnel"))',
        'require(Shared:WaitForChild("DiagnosticsLog"))',
        "Players.PlayerAdded:Connect(",
        "Players.PlayerRemoving:Connect(",
        "LogService.MessageOut:Connect(onMessage)",
        "Enum.MessageType.MessageWarning",
        'player:SetAttribute("IronYardSlot", slot)',
        "ServerCapacity.classify(population)",
        "TelemetryFunnel.recordJoin(funnel, player.UserId)",
        "DiagnosticsLog.categorize(text)",
        'Workspace:SetAttribute("IronYardFreeSlots"',
    ):
        has(service, required, "ObservabilityService wiring")
    # It classifies and records; it must not act on a player.
    # Comments are stripped first: a comment that names a forbidden call is
    # documentation, not wiring.
    service_code = re.sub(r"--[^\n]*", "", service)
    for forbidden in ("Kick(", "FireClient", "FireServer", "RemoteEvent",
                      "RemoteFunction", "TeleportAsync", ":LoadCharacter",
                      "CharacterAdded"):
        require(forbidden not in service_code,
                f"ObservabilityService must not {forbidden}")
    # The MessageOut handler sees every warning: printing from it would loop.
    require("warn(" not in service_code,
            "ObservabilityService must never print (warning loop)")
    # Reporting must stay pcall-guarded so a bad message cannot break a join.
    has(service, "pcall(DiagnosticsLog.record", "records must be pcall-guarded")

    start_at = bootstrap.find("ObservabilityService.start()")
    progression_at = bootstrap.find("ProgressionService.start()")
    require(start_at != -1, "init.server.luau must start ObservabilityService")
    require(progression_at != -1, "ProgressionService.start must stay in place")
    require(start_at < progression_at,
            "ObservabilityService must start before the services it observes")
    require("ObservabilityService" in bootstrap,
            "init.server.luau must require ObservabilityService")

    # 9. The documentation states the decision and what remains unproven.
    doc = source("docs/OBSERVABILITY.md")
    for heading in ("## 1. Pourquoi ce lot", "## 2. Funnel",
                    "## 3. Plafond de serveur", "## 4. Journal d'erreurs",
                    "## 5. Ce qui reste à câbler", "## 6. Limites"):
        has(doc, heading, "docs/OBSERVABILITY.md section")
    has(doc, "12", "the capacity decision must be written down")
    has(doc, "Players.MaxPlayers", "the place setting must be named")

    print("IRON YARD observability contract (purity, server-only, capacity "
          "agreement, bounds, CI wiring): OK")


if __name__ == "__main__":
    main()
