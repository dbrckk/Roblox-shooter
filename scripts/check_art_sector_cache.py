#!/usr/bin/env python3
"""Verify arena LOD streaming and sector cache cannot modify combat physics."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
src = (ROOT / "src/client/BotLOD.client.luau").read_text()
registry = (ROOT / "src/shared/ArtSectorRegistry.luau").read_text()
policy = (ROOT / "src/shared/ArtLODPolicy.luau").read_text()

needles = (
    'Shared:WaitForChild("ArtSectorRegistry")',
    "local function releaseArtFolder(folder)",
    "local function getDetailGroups(folder)",
    "folder.DescendantAdded:Connect(inspectPart)",
    "folder.DescendantRemoving:Connect(function(item)",
    'item:GetAttributeChangedSignal("NeonArtTier")',
    'if tier == "Detail" then',
    "ArtSectorRegistry.add(entry.registry, item, item.Position)",
    "ArtSectorRegistry.remove(entry.registry, item)",
    "local eye = entry.lastEye",
    "ArtLOD.hiddenSquared(offset:Dot(offset),",
    "for _, item in ipairs(folder:GetDescendants()) do inspectPart(item) end",
    "for _, group in pairs(entry.registry.byKey) do",
    'if mode == "HIDE" or mode == "SHOW" then',
    "local previous = trackedArtFolders[name]",
    "if previous then releaseArtFolder(previous) end",
    "connection:Disconnect()",
)
for needle in needles:
    assert needle in src, f"Missing streamed art cache integration: {needle}"
assert src.count("folder:GetDescendants()") == 1, (
    "Whole-folder scans must happen only on first registration")
assert "entry.dirty" not in src, "No dirty-triggered global art rebuilds"
assert "for _, item in ipairs(group.parts)" not in src, (
    "Streaming registry group.parts is a set, not a sequential array")
assert "Part:Destroy()" not in src and "CanQuery =" not in src and "CanCollide =" not in src, (
    "Cosmetic LOD must not destroy physical parts or alter gameplay geometry")
for needle in (
    "function Registry.add(state, part, position)",
    "function Registry.remove(state, part)",
    "state.byPart[part] = nil",
    "if group.count == 0 then",
    "for other in pairs(group.parts) do",
    "ArtLOD.extendBounds(bounds, state.byPart[other].position)",
):
    assert needle in registry, f"Missing per-sector cleanup: {needle}"
assert "Policy.CellSize = 48" in policy and "Policy.MotionMargin = 8" in policy, (
    "Spatial density and moving-art padding preserved")
print("IRON YARD incremental art LOD: stream-in, group cleanup and safe core geometry: OK")
