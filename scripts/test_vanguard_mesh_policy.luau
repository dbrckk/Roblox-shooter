local Policy = require("../src/shared/VanguardMeshPolicy")

assert(#Policy.Pieces == 7 and #Policy.Palettes == 4, "Exact four-color seven-piece kit")
local names = {
    VANGUARD_torso = "torso", VANGUARD_head = "head",
    vanguard_left_arm = "left_arm", VANGUARD_right_arm = "right_arm",
    left_leg = "left_leg", right_leg = "right_leg", VANGUARD_rifle = "rifle",
}
for raw, expected in pairs(names) do
    assert(Policy.identifyPiece(raw) == expected, "Canonical GLB mesh name " .. raw)
end
assert(Policy.MAX_PRIMITIVES_PER_PIECE >= 5
    and Policy.MAX_PRIMITIVES_PER_PIECE <= 8)
assert(Policy.primitiveCountValid(1) and Policy.primitiveCountValid(5))
assert(not Policy.primitiveCountValid(0))
assert(not Policy.primitiveCountValid(Policy.MAX_PRIMITIVES_PER_PIECE + 1))
assert(not Policy.primitiveCountValid(2.5))
assert(Policy.identifyPiece("VANGUARD_torso.001") == "torso")
assert(Policy.identifyPiece("VANGUARD_left_arm_Primitive_04") == "left_arm")
assert(Policy.identifyPiece("VANGUARD_rifle_7") == "rifle")
for _, raw in ipairs({"VANGUARD_head_script", "OtherVanguardTorso",
    "VANGUARD_right_arm_old", "script", "torsoVanguard", ""}) do
    assert(Policy.identifyPiece(raw) == nil, "Reject loosely matched payload name " .. raw)
end
local good = { ColorMap = "rbxassetid://124", NormalMap = "rbxassetid://125",
    RoughnessMap = "rbxassetid://126", MetalnessMap = "rbxassetid://127" }
assert(Policy.mapsReady(good), "PBR requires actual map references")
for _, missing in ipairs(Policy.RequiredMaps) do
    local bad = table.clone(good)
    bad[missing] = ""
    assert(not Policy.mapsReady(bad), "Missing " .. missing .. " cannot be PBR-ready")
    bad[missing] = "rbxassetid://0"
    assert(not Policy.mapsReady(bad), "Placeholder map " .. missing .. " cannot count")
end
assert(not Policy.mapsReady({}), "No fake complete map manifests")
assert(Policy.keepChild("SurfaceAppearance", true, true), "Allow one material")
for _, className in ipairs({"Script", "LocalScript", "ModuleScript",
    "RemoteEvent", "BindableEvent", "Sound", "ObjectValue", "Attachment"}) do
    assert(not Policy.keepChild(className, true, false),
        "Never load executable or unrelated asset children: " .. className)
end
assert(not Policy.keepChild("SurfaceAppearance", false, true),
    "Nested appearance is rejected")
assert(not Policy.keepChild("SurfaceAppearance", true, false),
    "Second material is rejected")
print("IRON YARD exact PBR piece identity, four complete maps and mesh child allowlist: OK")
