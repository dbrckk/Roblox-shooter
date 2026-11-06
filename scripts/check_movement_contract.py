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
