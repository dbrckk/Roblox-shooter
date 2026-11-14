#!/usr/bin/env python3
"""Production match scheduler fault containment contract.

This does not claim to execute Roblox services. It guards the real server
scheduler's lifecycle, non-yielding pcall boundary and recovery path.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = (root / "src/server/MatchService.luau").read_text()
workflow = (root / ".github/workflows/rojo-build.yml").read_text()
tail = source.split("function MatchService.start()", 1)[1]
assert "while started do" in tail
assert "local ok, err = pcall(function()" in tail
assert "tick()" in tail.split("local ok, err = pcall(function()", 1)[1].split("end)", 1)[0]
assert "consecutiveFailures += 1" in tail
assert "consecutiveFailures >= 3" in tail
assert "DuelCombatState.clear()" in tail
assert "releaseDuelPrep()" in tail
assert 'transition("WAITING", 0)' in tail
assert "task.wait(0.20)" in tail
assert tail.index("task.wait(0.20)") > tail.index("consecutiveFailures >= 3")
assert "CombatAwards.recordVictory" not in tail
assert "SpawnService.placePlayers()" not in tail
assert "python3 scripts/check_match_scheduler_recovery.py" in workflow
print("IRON YARD production scheduler exception recovery: OK")
