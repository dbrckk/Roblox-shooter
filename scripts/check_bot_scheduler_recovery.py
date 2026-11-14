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
