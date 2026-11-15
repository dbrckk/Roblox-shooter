#!/usr/bin/env python3
"""Contract for real server bot task fault isolation (not synthetic bot behavior).

Roblox engine physics, tactical raycasts and network remain authoritative.
The contract keeps each production coroutine live after a failing task and
prevents one broken NPC from stopping AI/combat for other slots.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root / "src/server/BotService.luau").read_text(encoding="utf-8")
ci = (root / ".github/workflows/rojo-build.yml").read_text(encoding="utf-8")
assert 'local faultWarningAt = {}' in s
assert 'local botRetryAfter = {}' in s
assert 'Workspace:SetAttribute("IronYardBotSchedulerFaults", totalSchedulerFaults)' in s
assert 'if now - (faultWarningAt[source] or -math.huge) >= 10 then' in s
assert 'local ok, err = pcall(reconcile)' in s
assert 'task.wait(1.25)' in s
assert 'local ok, err = pcall(createBot, slot)' in s
assert 'botRetryAfter[slot] = os.clock() + 5' in s
assert 'os.clock() >= (botRetryAfter[slot] or 0)' in s
assert 'local ok, err = pcall(updateBot, bot, dt)' in s
assert 'bot.thinkFailures = 0' in s
assert 'bot.thinkFailures >= 3 and slots[slot] == bot' in s
assert 'slots[slot] = nil' in s
assert 'pcall(BotNavigation.invalidate, bot)' in s
assert 'bot.model:Destroy()' in s
assert 'local ok, err = pcall(BotAnimation.step,' in s
assert 'bot.nextAnimationAt = now + 2' in s
assert 'task.wait(1 / 30)' in s
assert 'task.wait(config.ThinkInterval / config.MaxBots)' in s
assert 'if not spawn then return nil end' in s
assert 'if not model then return nil end' in s
assert 'python3 scripts/check_bot_scheduler_recovery.py' in ci
assert 'CombatAwards.recordVictory' not in s, "Recovery must never invent wins"
print("IRON YARD bot reconcile/combat/pose tasks: fault isolated and bounded")

# Death can originate from an actual hit while a cosmetic/PathfindingService
# operation fails. The 2.5-second live slot release must already be queued
# before any such fallible operation, and cannot evict a replacement bot.
death = s.split('humanoid.Died:Connect(function()', 1)[1].split(
    '\n    return bot', 1)[0]
cleanup = 'task.delay(config.DespawnAfterDeath, function()'
assert cleanup in death, "Missing mandatory real bot corpse cleanup"
assert death.index(cleanup) < death.index('pcall(BotNavigation.invalidate, bot)')
assert death.index(cleanup) < death.index('BotDeathAnimation.play(bot)')
assert 'if slots[slot] ~= bot then return end' in death
assert death.index('slots[slot] = nil') < death.index('model:Destroy()')
assert 'local navOk, navErr = pcall(BotNavigation.invalidate, bot)' in death
assert 'local poseOk, poseErr = pcall(function()' in death
assert death.index('component.CanQuery = false') < death.index(
    'BotDeathAnimation.play(bot)')
assert 'reportSchedulerFault("death-nav:" .. slot, navErr)' in death
assert 'reportSchedulerFault("death-pose:" .. slot, poseErr)' in death
print("IRON YARD bot death: cleanup precedes fallible navigation and posing")


# A detached rig may never fire Died. It must be replaced without clearing
# its active slot's score or skipping the ordinary safe-spawn retry.
reconcile = s.split("local function reconcile()", 1)[1].split(
    "function BotService.reconcileNow()", 1)[0]
rig = s.split("local function hasActiveRig(bot)", 1)[1].split("\nend", 1)[0]
for condition in (
    "bot.model.Parent == folder", "bot.humanoid.Parent == bot.model",
    "bot.root.Parent == bot.model", "bot.head.Parent == bot.model",
):
    assert condition in rig
assert reconcile.index("if bot and not hasActiveRig(bot) then removeBot(slot, bot) end") < (
    reconcile.index("pcall(createBot, slot)"))
assert reconcile.count("roundKills[slot] = 0") == 1
assert reconcile.index("roundKills[slot] = 0") < reconcile.index("else\n")
retire = s.split("local function removeBot(slot, bot)", 1)[1].split("\nend", 1)[0]
assert retire.index("if slots[slot] ~= bot then return end") < retire.index("slots[slot] = nil")
assert "pcall(BotNavigation.invalidate, bot)" in retire
assert "bot.model:Destroy()" in retire

# In a round reset, a failing NPC is retired and retried by reconciliation,
# while the rest of the roster and MatchService's round start can continue.
reset = s.split("function BotService.resetRound()", 1)[1].split(
    "function BotService.start()", 1)[0]
failure = reset.split("pcall(resetBotForRound, bot, slot)", 1)[1].split(
    "reportSchedulerFault", 1)[0]
assert "botRetryAfter[slot] = os.clock() + 5" in failure
assert "removeBot(slot, bot)" in failure
init = s.split("local function createBot(slot)", 1)[1].split(
    "-- Server-authored hit attributes", 1)[0]
assert init.index("humanoid.Died:Connect") < init.index("model.Parent = folder")
assert init.index("model.Parent = folder") < init.index("SpawnService.protectCharacter(model, 2.0)")
print("IRON YARD bot roster: detached rig recovery and per-slot round reset isolation")
