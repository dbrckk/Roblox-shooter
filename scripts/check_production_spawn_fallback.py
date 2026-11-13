#!/usr/bin/env python3
"""Production FFA spawn recovery contract (not a synthetic gameplay mock).

Runtime physics is still handled by Workspace:GetPartBoundsInBox. These
assertions prevent accidentally reintroducing the old forced blocked pad.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spawn = (root / "src/server/SpawnService.luau").read_text(encoding="utf-8")
bots = (root / "src/server/BotService.luau").read_text(encoding="utf-8")
safety = (root / "src/shared/SpawnSafety.luau").read_text(encoding="utf-8")
ci = (root / ".github/workflows/rojo-build.yml").read_text(encoding="utf-8")

for needle in (
    "function SpawnSafety.chooseEmergencyPad(isClear, scoreAt)",
    "for gx = -3, 3 do", "for gz = -3, 3 do",
    "if isClear(x, z) then", "local score = scoreAt(x, z)",
    "if bestX == nil then return nil end",
):
    assert needle in safety, f"Emergency search missing: {needle}"
for needle in (
    "SpawnSafety.chooseEmergencyPad(function(px, pz)",
    "clearAt(Vector3.new(px, 3.4, pz), character)",
    "scoreAt(Vector3.new(px, 3.4, pz))",
    "if x ~= nil then return Vector3.new(x, 3.4, z) end",
    "return nil",
    "if not position then",
    "if SpawnService.place(player, character) then return end",
    'Workspace:GetAttribute("IronYardMatchMode") == "DUEL"',
):
    assert needle in spawn, f"FFA failed-closed recovery missing: {needle}"
assert "no unobstructed spawn pad; using fallback under shield" not in spawn
assert spawn.index("if not position then") < spawn.index(
    "applyPlacement(character, root, humanoid, position, faceToward)\n    return true"
), "No CFrame created with nil/blocked fallback"
for needle in (
    "if not spawn then return nil end",
    "if not model then return nil end",
    "local safeRoundSpawn = SpawnService.selectSafeSpawn(bot.model)",
    "if safeRoundSpawn then",
):
    assert needle in bots, f"Bot reconcile must tolerate saturated map: {needle}"
assert "CFrame.new(SpawnService.selectSafeSpawn(bot.model))" not in bots
duel = spawn.split("function SpawnService.placeDuelPair(a, b, bout)", 1)[1].split(
    "\nfunction SpawnService.placePlayers()", 1
)[0]
assert "chooseEmergencyPad" not in duel
assert "applyPlacement(aChar, aRoot, aHumanoid, first, second)" in duel
assert "applyPlacement(bChar, bRoot, bHumanoid, second, first)" in duel
assert "./luau scripts/test_spawn_safety.luau" in ci
assert "python3 scripts/check_production_spawn_fallback.py" in ci
print("IRON YARD FFA: bounded clear-pad recovery, no blocked teleports or NPC nil CFrames; strict 1v1 preserved")
