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
-- A 7-part fighter always has one readable Core silhouette per R6 limb,
-- even when every extra material primitive is culled for low-end Android.
for _, piece in ipairs(Policy.Pieces) do
    assert(Policy.visualTier(piece, 1) == "Core",
        "All seven PBR bones must keep a visible base: " .. piece)
    for index = 2, Policy.MAX_PRIMITIVES_PER_PIECE do
        assert(Policy.visualTier(piece, index) == "Detail",
            "Extra PBR materials must respect existing client LOD")
    end
end
for _, bad in ipairs({ 0, -1, 1.5, Policy.MAX_PRIMITIVES_PER_PIECE + 1 }) do
    assert(Policy.visualTier("torso", bad) == nil,
        "Reject an out-of-bounds cosmetic primitive")
end
-- Imported GLB surface order is arbitrary: the smallest detail often comes
-- first. The largest valid component, NOT the first, must survive mobile LOD.
local components = {
    { Size = { X = 0.12, Y = 0.06, Z = 0.08 } },
    { Size = { X = 1.4, Y = 1.1, Z = 0.5 } },
    { Size = { X = 0.3, Y = 0.4, Z = 0.2 } },
}
assert(Policy.dominantIndex(components) == 2,
    "Core silhouette must be largest material primitive")
for _, piece in ipairs(Policy.Pieces) do
    local cores = 0
    for index = 1, #components do
        local tier = Policy.visualTier(piece, index, Policy.dominantIndex(components))
        if tier == "Core" then cores += 1 end
        if index ~= 2 then assert(tier == "Detail") end
    end
    assert(cores == 1, "Exactly one dominant Core retained: " .. piece)
end
assert(Policy.dominantIndex({
    { Size = {X = 1, Y = 1, Z = 1} },
    { Size = {X = 1, Y = 1, Z = 1} },
}) == 1, "Exact ties retain original component order")
assert(Policy.dominantIndex({}) == nil)
assert(Policy.dominantIndex(nil) == nil)
assert(Policy.dominantIndex({
    { Size = {X = math.huge, Y = 1, Z = 1} },
}) == nil, "Infinite geometry must fail validation")
assert(Policy.dominantIndex({
    { Size = {X = 2, Y = 0, Z = 1} },
}) == nil, "Zero-size geometry must fail validation")
assert(Policy.visualTier("torso", 1, 0) == nil)
assert(Policy.visualTier("torso", 1, 1.5) == nil)
assert(Policy.visualTier("torso", 1, 2) == "Detail")
assert(Policy.visualTier("torso", 2, 2) == "Core")
assert(Policy.visualTier("unknown", 1) == nil)
assert(Policy.visualTier(nil, 1) == nil)
assert(Policy.visualTier("head", 0/0) == nil)
assert(Policy.visualTier("head", math.huge) == nil)
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
