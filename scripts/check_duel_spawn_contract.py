"""Verify exact-opposite duel spawns and no fallback to an FFA pad.

Pure Luau tests exercise pad choice and both-character-generation gate.
This source contract proves that the live Roblox SpawnService uses that
policy and commits both prevalidated opposite positions directly.
Roblox Studio physics still needs a live test.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spawn = (root / "src/server/SpawnService.luau").read_text(encoding="utf-8")
plan = (root / "src/shared/DuelSpawnPlan.luau").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/rojo-build.yml").read_text(encoding="utf-8")

assert "function Plan.canCommit(aPlayer, bPlayer, expectedA, expectedB, aReady, bReady)" in plan
assert "aPlayer.Character == expectedA and bPlayer.Character == expectedB" in plan
assert "scripts/test_duel_spawn_plan.luau" in workflow
assert "scripts/check_duel_spawn_contract.py" in workflow

duel = spawn.split("function SpawnService.placeDuelPair(a, b, bout)", 1)[1].split(
    "\nfunction SpawnService.placePlayers()", 1)[0]
for needle in (
    "a.Parent ~= Players or b.Parent ~= Players",
    "aChar:IsDescendantOf(Workspace)",
    "bChar:IsDescendantOf(Workspace)",
    "aRoot, aHumanoid = combatReady(aChar)",
    "bRoot, bHumanoid = combatReady(bChar)",
    "DuelSpawnPlan.select(clear, bout)",
    "not clearAt(first, aChar, bChar)",
    "not clearAt(second, aChar, bChar)",
    "DuelSpawnPlan.canCommit(a, b, aChar, bChar,",
    "not aRoot.Anchored and aHumanoid.Health > 0",
    "not bRoot.Anchored and bHumanoid.Health > 0",
    "applyPlacement(aChar, aRoot, aHumanoid, first, second)",
    "applyPlacement(bChar, bRoot, bHumanoid, second, first)",
):
    assert needle in duel, f"Dual spawn safety integration missing: {needle}"
assert "SpawnService.place(" not in duel, (
    "Duel pair must not call flexible FFA spawn / partial teleport fallback")
assert duel.index("DuelSpawnPlan.canCommit(") < duel.index(
    "applyPlacement(aChar")
assert duel.index("applyPlacement(aChar") < duel.index(
    "applyPlacement(bChar")
assert duel.index("not clearAt(second") < duel.index("applyPlacement(aChar")
assert "function SpawnService.place(player, character," in spawn, (
    "Normal FFA spawning must remain available")
assert "applyPlacement(character, root, humanoid, position, faceToward)" in spawn
print("IRON YARD duel spawns: two original rigs and both opposite pads verified before either move; FFA fallback excluded")
