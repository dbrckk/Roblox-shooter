#!/usr/bin/env python3
"""Validate that opt-in profiling cannot change combat or expose players.

Executable Luau regression verifies the pure sampler; this guard verifies
the real server/client hooks and the owner-only network boundary.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
def src(path):
    return (root / path).read_text(encoding="utf-8")
service = src("src/server/BotPerfService.luau")
profile = src("src/shared/BotPerfProfile.luau")
client = src("src/client/PerfOverlay.client.luau")
frame_window = src("src/shared/ClientFrameWindow.luau")
net = src("src/shared/PrecisionNet.luau")
boot = src("src/server/init.server.luau")
bot = src("src/server/BotService.luau")
motion = src("src/shared/BotMotionProfile.luau")
think_cadence = src("src/shared/BotThinkCadence.luau")
nav = src("src/server/BotNavigation.luau")
tactics = src("src/server/BotTactics.luau")

for phrase in (
    'PerformanceDiagnostics = "RemoteEvent"',
):
    assert phrase in net, "Missing bounded diagnostics network transport"

for phrase in (
    "function Profile.new(now)",
    "function Profile.count(state, key, amount)",
    "function Profile.timing(state, key, milliseconds)",
    "function Profile.flush(state, now, livingBots)",
    "Profile.WINDOW_SECONDS = 5",
):
    assert phrase in profile, "Missing pure metric aggregation contract: " + phrase

for phrase in (
    "game.CreatorType == Enum.CreatorType.User",
    "player.UserId == game.CreatorId",
    "RunService:IsStudio()",
    "if not authorized(player)",
    'command ~= "start" and command ~= "stop"',
    'remote:FireClient(player, snapshot)',
    'remote.OnServerEvent:Connect(function(player, command)',
    "Players.PlayerRemoving:Connect(",
    "if state then Profile.count(state, key) end",
    "return state and os.clock() or nil",
):
    assert phrase in service, "Remote security/opt-in missing: " + phrase
assert "FireAllClients" not in service, "Never broadcast private performance diagnostics"
assert "DataStore" not in service, "Never persist diagnostic reports"
assert "FireServer" not in service, "Never trust client-provided timing values"

for phrase in (
    "game.CreatorType == Enum.CreatorType.User",
    "player.UserId == game.CreatorId",
    "remote:FireServer(active and \"start\" or \"stop\")",
    "RunService.RenderStepped:Connect(function(dt)",
    "if not active then return end",
    "remote.OnClientEvent:Connect(function(packet)",
    'panel.Visible = false',
):
    assert phrase in client, "Android owner-only FPS panel missing: " + phrase
for phrase in (
    'local FrameWindow = require(Shared:WaitForChild("ClientFrameWindow"))',
    'FrameWindow.push(frameWindow, dt)',
    'FrameWindow.snapshot(frameWindow)',
    'FrameWindow.clear(frameWindow)',
    '"P95: %.0fms  P99: %.0fms',
    '">33ms: %d / %d images',
):
    assert phrase in client, "Client percentile profiler wiring missing: " + phrase
for phrase in (
    "FrameWindow.CAPACITY = 240",
    "function FrameWindow.push(window, seconds)",
    "function FrameWindow.snapshot(window)",
    "function FrameWindow.clear(window)",
    "sorted[math.ceil(count * 0.95)]",
    "sorted[math.ceil(count * 0.99)]",
):
    assert phrase in frame_window, "Bounded frame sampler missing: " + phrase
assert "BotPerfService.start()" in boot, "Server profiler must initialize on game start"
for phrase in (
    'BotPerfService.count("think")',
    'BotPerfService.count("pose")',
    'BotPerfService.count("targetRay")',
    'BotPerfService.count("muzzleRay")',
    'BotPerfService.count("shotRay")',
    'BotPerfService.count("botShot")',
    'BotPerfService.measure("thinkMs", thinkSample)',
    'BotPerfService.measure("poseMs", poseSample)',
):
    assert phrase in bot, "Missing measured bot tactical/animation hook: " + phrase
for phrase in (
    'BotPerfService.count("navRay")',
    'BotPerfService.count("moveIssued")',
    'BotPerfService.count("pathStarted")',
    'BotPerfService.count("pathDeferred")',
    'BotPerfService.count("pathFinished")',
    'BotPerfService.measure("pathMs", pathSample)',
    "Budget.claim(pathBudget, now)",
    "Workspace:Raycast(",
    "path:ComputeAsync(start, goal)",
):
    assert phrase in nav, "Missing nav workload or safety hook: " + phrase
for phrase in (
    "local function finite(value)",
    "if not finite(previousX) or not finite(previousZ)",
    "or not finite(currentX) or not finite(currentZ)",
):
    assert phrase in motion, "No-allocation motion signal validation missing: " + phrase
assert "local values = {" not in motion, (
    "Server R6 pose signals must validate scalars without table allocations")
for phrase in (
    "function Motion.intervalSquared(nearestPlayerDistanceSquared)",
    "function Motion.nextPoseAt(now, nearestPlayerDistanceSquared, slot)",
    "and nearestPlayerDistanceSquared <= 155 * 155",
    "local phase = (botSlot - 1) * interval / 4",
):
    assert phrase in motion, "Bot animation scheduling contract missing: " + phrase
for phrase in (
    "nextAnimationAt = BotMotionProfile.nextPoseAt(os.clock(), 0, slot)",
    "bot.nextAnimationAt = BotMotionProfile.nextPoseAt(",
    "now, nearestSquared, bot.slot)",
    "local offset = root.Position - botPosition",
    "offset:Dot(offset)",
    "BotAnimation.step(bot, now, bot.isAiming == true)",
    "task.wait(1 / 30)",
):
    assert phrase in bot, "Staggered server bot pose integration missing: " + phrase
assert '(root.Position - bot.root.Position).Magnitude' not in bot.split(
    'for _, bot in pairs(slots) do\n                if bot.model.Parent', 1)[1], (
    "Cosmetic pose scheduling must use squared distance, not repeated roots")
for phrase in (
    "Cadence.SLOTS = 4",
    "Cadence.MIN_GAP_FRACTION = 0.75",
    "function Cadence.firstAt(now, interval, slot)",
    "function Cadence.nextAt(now, interval, slot)",
):
    assert phrase in think_cadence, "Server tactical scheduler contract missing: " + phrase
assert "task.wait(config.ThinkInterval / config.MaxBots)" in bot
assert "bot.nextThinkAt = BotThinkCadence.nextAt(" in bot
assert 'BotPerfService.count("tacticsRay")' in tactics
assert nav.count('BotPerfService.count("navRay")') == 3
assert tactics.count('BotPerfService.count("tacticsRay")') == 4
assert bot.count('BotPerfService.count("targetRay")') == 2
assert bot.count('BotPerfService.count("shotRay")') == 1

print("IRON YARD private 5s bot profiler: authorized, bounded, opt-in, wired: OK")
