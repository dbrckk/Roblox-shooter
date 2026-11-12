"""Guard the real, server-owned duel preparation transition.

Executable Luau exercises the same pure prep policy. This source integration
check rejects regressions where missing/dead/stale rigs leave DUEL_PREP
hanging, and prevents unrelated FFA or results screens from being changed.
Roblox humanoid/physics playtests are still required.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
server = (root / "src/server/MatchService.luau").read_text(encoding="utf-8")
rules = (root / "src/shared/DuelRules.luau").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/rojo-build.yml").read_text(encoding="utf-8")

assert 'function Duel.prepState(prep, actualA, readyA, actualB, readyB)' in rules
assert 'Duel.prepValid(prep[1].character, actualA, readyA,' in rules
assert 'scripts/test_duel_rules.luau' in workflow
assert 'scripts/check_duel_prep_contract.py' in workflow

prep = server.split("local function duelPrepState()", 1)[1].split(
    "\nlocal function retryInterruptedDuelPrep()", 1)[0]
assert 'type(entry) ~= "table"' in prep
for needle in (
    'entry.root.Parent ~= nil and entry.root.Anchored',
    'h ~= nil and h.Health > 0',
    'entry.root:IsDescendantOf(c)',
    'DuelRules.prepState(prep,',
    'a and a.Character',
    'b and b.Character',
):
    assert needle in prep, f"Original duel rig guard missing: {needle}"

retry = server.split("local function retryInterruptedDuelPrep()", 1)[1].split(
    "\nlocal function startLiveDuelBout()", 1)[0]
for needle in (
    'DuelCombatState.clear()',
    'releaseDuelPrep()',
    'duel.liveCharacterA = nil',
    'duel.liveCharacterB = nil',
    'duel.waitSince = duel.waitSince or os.clock()',
    'transition("DUEL_BREAK", DUEL_BREAK_SECONDS)',
    'return false',
):
    assert needle in retry, f"Interrupted duel cleanup missing: {needle}"

start = server.split("local function startLiveDuelBout()", 1)[1].split(
    "\nlocal function startDuelSeries(", 1)[0]
assert 'if duelPrepState() ~= "READY" then' in start
assert 'return retryInterruptedDuelPrep()' in start
assert start.index('if duelPrepState()') < start.index('releaseDuelPrep()')
assert 'if not DuelCombatState.begin(a, b) then' in start
assert start.count('return retryInterruptedDuelPrep()') == 2
assert 'duel.waitSince = nil' in start
assert 'duel.bouts += 1' in start
assert start.index('if not DuelCombatState.begin') < start.index('duel.bouts += 1')

tick = server.split("local function tick()", 1)[1].split(
    "\nfunction MatchService.start()", 1)[0]
assert 'elseif phase == "DUEL_PREP" then' in tick
branch = tick.split('elseif phase == "DUEL_PREP" then', 1)[1].split(
    'elseif phase == "DUEL_BREAK"', 1)[0]
assert 'if duelPrepState() ~= "READY" then' in branch
assert 'retryInterruptedDuelPrep()' in branch
assert 'elseif remaining <= 0 then' in branch
assert 'startLiveDuelBout()' in branch
assert branch.index('retryInterruptedDuelPrep()') < branch.index('startLiveDuelBout()')
assert 'if duel and phase ~= "RESULTS" and not duelPlayersIntact() then' in tick
assert 'DuelRules.forfeitSide(Players:GetPlayers(), a, b)' in tick
print("IRON YARD duel preparation: early stale-rig cleanup, bounded recovery, no double bout OK")
