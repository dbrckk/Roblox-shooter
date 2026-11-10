#!/usr/bin/env python3
"""Static integration checks for safe movement remotes and respawn mantles."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
server = (root / "src/server/MovementService.luau").read_text(encoding="utf-8")
safe = (root / "src/shared/SafePlanarInput.luau").read_text(encoding="utf-8")
for token in (
    'require(shared:WaitForChild("SafePlanarInput"))',
    "SafePlanarInput.normalize(raw.X, raw.Y, raw.Z)",
    "local function getFlatDirection(payload, root)",
    "local function getOptionalFlatDirection(payload)",
    "currentRoot ~= root",
    "player.Character ~= character",
):
    assert token in server, f"Missing movement security guard: {token}"
for token in ("function SafePlanarInput.normalize(x, y, z)",
              "coordinate ~= coordinate", "math.abs(coordinate) > MAX_COMPONENT"):
    assert token in safe, f"Missing numeric validation: {token}"
print("IRON YARD movement remote and mantle-respawn contracts: OK")


# Duel round introductions must not allow acceleration exploits while roots
# are server-anchored for the countdown. All stops remain admissible.
for token in (
    "function MovementService.resetDuelMovement(player)",
    'Workspace:GetAttribute("NeonMatchPhase") == "DUEL_PREP"',
    'action ~= "BoostStop" and action ~= "StopWallRun"',
    "state.slideToken += 1",
    "state.wallRunToken += 1",
    "root.AssemblyLinearVelocity = Vector3.zero",
):
    assert token in server, "DUEL_PREP movement isolation missing: " + token


for token in (
    "function MovementService.resetDuelMovement(player)",
    "state.boostFuel = MovementConfig.boostFuelMax",
    "state.lastSlideAt = -math.huge",
    "state.lastBoostAt = -math.huge",
    "root.AssemblyLinearVelocity = Vector3.zero",
    "sendMovementState(player, state)",
):
    assert token in server, "Duel must restore fair starting movement: " + token
