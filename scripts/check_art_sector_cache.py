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
    "local function getDetailGroups(folder, initialEye)",
    "folder.DescendantAdded:Connect(inspectPart)",
    "folder.DescendantRemoving:Connect(function(item)",
    'item:GetAttributeChangedSignal("NeonArtTier")',
    'if tier == "Detail" then',
    "ArtSectorRegistry.add(entry.registry, item, item.Position)",
    "ArtSectorRegistry.remove(entry.registry, item)",
    "local eye = entry.lastEye",
    "ArtLOD.hiddenSquared(offset:Dot(offset),",
    "local initialParts = folder:GetDescendants()",
    "task.spawn(function()",
    "ArtLOD.bootstrapBatch(",
    "RunService.Heartbeat:Wait()",
    "if item:IsDescendantOf(folder) then inspectPart(item) end",
    "for _, group in pairs(entry.registry.byKey) do",
    'if mode == "HIDE" or mode == "SHOW" then',
    "local previous = trackedArtFolders[name]",
    "if previous then releaseArtFolder(previous) end",
    "connection:Disconnect()",
)
for needle in needles:
    assert needle in src, f"Missing streamed art cache integration: {needle}"
assert "ArtSectorRegistry.clear(entry.registry)" in src, (
    "Whole arena replacement must not recompute every 48-stud sector")
assert src.count("folder:GetDescendants()") == 1, (
    "Whole-folder scans must happen only on first registration")
assert "for _, item in ipairs(folder:GetDescendants())" not in src, (
    "Initial indexing must be sliced, not synchronous")
assert "if index % batch == 0 then" in src, (
    "Bootstrap must yield after every fixed registration batch")
for needle in (
    "entry.dirty = true",
    "local needsSweep = entry.dirty",
    "or entry.lastSweepEye ~= position",
    "or entry.lastSweepHide ~= artHideBeyond",
    "or entry.lastSweepShow ~= artUnhideBefore",
    "if needsSweep then",
    "entry.lastSweepEye = position",
    "entry.dirty = false",
):
    assert needle in src, f"Stationary camera LOD invalidation missing: {needle}"
assert src.count("entry.dirty = true") >= 3, (
    "Every detail addition and removal must invalidate the stationary cache")
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
    "function Registry.clear(state)",
    "local edge = p.X == before.minX",
    "if edge then",
    "elseif expanded then",
):
    assert needle in registry, f"Missing per-sector cleanup: {needle}"
assert "Policy.CellSize = 48" in policy and "Policy.MotionMargin = 8" in policy, (
    "Spatial density and moving-art padding preserved")
print("IRON YARD incremental art LOD: stream-in, group cleanup and safe core geometry: OK")
