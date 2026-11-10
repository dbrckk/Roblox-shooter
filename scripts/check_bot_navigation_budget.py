#!/usr/bin/env python3
"""Offline integration contract for the four-bot server navigation budget.

Pure Luau behavior is tested independently; this guard ensures the live
PathfindingService code actually uses it without weakening raycast safety.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
nav = (root / "src/server/BotNavigation.luau").read_text(encoding="utf-8")
budget = (root / "src/shared/BotPathBudget.luau").read_text(encoding="utf-8")
service = (root / "src/server/BotService.luau").read_text(encoding="utf-8")

for needle in (
    'require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BotPathBudget"))',
    "local pathBudget = Budget.new()",
    "local ticket = Budget.claim(pathBudget, now)",
    'if not ticket then\n        BotPerfService.count("pathDeferred")\n        return\n    end',
    "local leaseValid = Budget.valid(pathBudget, ticket, os.clock())",
    "Budget.release(pathBudget, ticket)",

    "if not leaseValid or not isCurrent()",
    "or bot.pathRevision ~= revision then return end",
    "function BotNavigation.invalidate(bot)",
    "bot.pathRevision = (bot.pathRevision or 0) + 1",
    "bot.lastMoveGoal = nil",
    "bot.lastMoveIssuedAt = nil",
    "Budget.shouldIssueMove(moved, age)",
    "requestMove(bot, goal, now)",
    "requestMove(bot, point.Position, now)",
    "requestMove(bot, detour, now)",
    "requestMove(bot, candidate, now)",
    'requestMove(bot, bot.root.Position, now, bot.navMode ~= "WAIT")',
    "directRouteClear(bot, goal, params)",
    "followDetour(bot, goal, now, params)",
    "directRouteClear(bot, detour, params)",
    "local params = environmentParams(bot)",
    "params.RespectCanCollide = true",
    "Workspace:Raycast(",
    "PathfindingService:CreatePath(",
    "path:ComputeAsync(start, goal)",
    "computedPath.Blocked:Connect(",
):
    assert needle in nav, f"Navigation safety or performance integration missing: {needle}"

assert nav.count("bot.humanoid:MoveTo(") == 1, (
    "Only the coalescing requestMove helper may send Humanoid commands"
)
assert nav.index("local ticket = Budget.claim") < nav.index("bot.pathing = true\n    bot.pathStartedAt = now"), (
    "Path workload must be admitted before claiming a pending bot computation"
)
assert nav.index("Budget.release(pathBudget, ticket)") < nav.index(
    "if not leaseValid or not isCurrent()"), (
    "Every completed ComputeAsync attempt must release its ticket before state mutation"
)
for needle in (
    "Budget.MAX_IN_FLIGHT = 2",
    "function Budget.inFlight(state)",
    "if active >= Budget.MAX_IN_FLIGHT then return nil end",
    "Budget.MIN_START_GAP = 0.18",
    "Budget.LEASE_SECONDS = 5.8",
    "Budget.MOVE_REFRESH_SECONDS = 1.15",
    "Budget.MOVE_DELTA = 1.25",
):
    assert needle in budget, f"Server nav bound missing: {needle}"
assert "task.wait(config.ThinkInterval / config.MaxBots)" in service, (
    "Four tactical brains must be staggered over 20Hz scheduler slices"
)
for needle in (
    'require(shared:WaitForChild("BotThinkCadence"))',
    "nextThinkAt = BotThinkCadence.firstAt(",
    "bot.nextThinkAt = BotThinkCadence.nextAt(",
    "now, config.ThinkInterval, bot.slot)",
):
    assert needle in service, f"Five-hertz per-bot cadence integration missing: {needle}"
assert "BotAnimation.step(bot, now, bot.isAiming == true)" in service, (
    "Existing visible bot animations must remain untouched"
)
print("IRON YARD capped navmesh, unchanged collision probes and MoveTo coalescing: OK")

assert "reap(state, now)" not in budget, (
    "Expired logical tickets must never release still-running engine calls"
)
assert "state.leases[token] = nil" in budget.split("function Budget.release", 1)[1], (
    "Only actual asynchronous completion may release a running slot"
)
