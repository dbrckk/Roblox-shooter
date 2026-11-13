#!/usr/bin/env python3
"""Static wiring check for safe multi-material VANGUARD GLB imports."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def source(path):
    return (ROOT / path).read_text(encoding="utf-8")

def must(s, item, reason):
    assert item in s, f"{reason}: {item}"

policy = source("src/shared/VanguardMeshPolicy.luau")
kit = source("src/server/VanguardMeshKit.luau")
loader = source("src/server/VanguardAssetLoader.luau")
visuals = source("src/server/BotVisuals.luau")
audit = source("scripts/audit_vanguard_glb.py")
test = source("scripts/test_vanguard_mesh_policy.luau")
workflow = source(".github/workflows/rojo-build.yml")

for item in ("Policy.MAX_PRIMITIVES_PER_PIECE = 8",
             "function Policy.primitiveCountValid(count)",
             "function Policy.visualTier(piece, primitiveIndex)",
             'normalized:match("^" .. prefixed .. "%d+$")',
             'normalized:match("^" .. prefixed .. "primitive%d+$")'):
    must(policy, item, "bounded identity policy")
for item in ("function Kit.primitives(component)",
             "Policy.primitiveCountValid(#children)",
             "if not Kit.isRenderable(child) then return nil end",
             "if not Policy.keepChild("):
    must(kit, item, "sanitized group")
for item in ("MAX_DELIVERY_ATTEMPTS = 3",
             "for attempt = 1, MAX_DELIVERY_ATTEMPTS do",
             "InsertService:LoadAsset(assetId)",
             "task.wait(0.35 * (2 ^ (attempt - 1)))",
             'error("VANGUARD_DELIVERY_FAILED: "',
             '"DELIVERY_FAILED" or "VALIDATION_FAILED"',
             "staging:Destroy()"):
    must(loader, item, "bounded owner asset retry and failure diagnosis")
for item in ("loaded:GetDescendants()", "Policy.identifyPiece(ancestor.Name)",
             "MeshKit.isRenderable(item)",
             "Policy.MAX_PRIMITIVES_PER_PIECE",
             "basis:ToObjectSpace(item.CFrame)",
             "MeshKit.cleanClone(item)",
             "MeshKit.primitives(mesh)",
             "staging:Destroy()"):
    must(loader, item, "loader safety and atomic fallback")
for item in ("MeshKit.primitives(template)",
             "MeshKit.cleanClone(template)",
             "MeshPolicy.visualTier(partName, index)",
             'part:SetAttribute("NeonCosmeticTier", tier)',
             'part.CastShadow = tier == "Core"',
             "part.CFrame = target.CFrame * offset * relative",
             "part.CanCollide = false", "part.CanTouch = false",
             "part.CanQuery = false", 'bodyPart.Transparency = 1',
             'model:SetAttribute("NeonVisualSource", "PROCEDURAL_PARTS")'):
    must(visuals, item, "R6 visual-only mount and fallback")
for item in ("primitive_count += len(primitives)",
             "1 <= len(primitives) <= 8", '"material_primitives": primitive_count'):
    must(audit, item, "GLB primitive count audit")
must(test, 'Policy.identifyPiece("VANGUARD_torso.001")', "numbered variant regression")
must(test, 'Policy.visualTier(piece, 1) == "Core"', "seven retained R6 cores")
must(test, 'Policy.visualTier(piece, index) == "Detail"', "secondary material detail LOD")
lod = source("src/client/BotLOD.client.luau")
for item in ('tier == "Detail"', 'part.LocalTransparencyModifier =',
             'BotDetailCache.decide(entry.state,'):
    must(lod, item, "existing client-only bot LOD")
must(workflow, "python3 scripts/check_vanguard_import_contract.py",
     "CI wiring")
print("IRON YARD multi-primitive PBR import safety contract: OK")
