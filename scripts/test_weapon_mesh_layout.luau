local Layout = require("../src/shared/WeaponMeshLayout")
local expected = {"IRONYARD_AssaultRifle_Static", "IRONYARD_AssaultRifle_Magazine"}
local function node(name, class, parent)
    local instance = {Name=name, ClassName=class, Parent=parent, children={}}
    function instance:IsA(id) return self.ClassName == id end
    function instance:GetDescendants()
        local result={}
        local function visit(root)
            for _, child in ipairs(root.children) do
                table.insert(result, child)
                visit(child)
            end
        end
        visit(self)
        return result
    end
    if parent then table.insert(parent.children, instance) end
    return instance
end
local root = node("OriginalWeaponPackage", "Model")
local static = node("IRONYARD_AssaultRifle_Static_Node", "Model", root)
local body = node("Material_0", "MeshPart", static)
local detail = node("Material_1", "MeshPart", static)
local magazine = node("IRONYARD_AssaultRifle_Magazine", "Model", root)
local mag = node("Mesh_0", "MeshPart", magazine)
local script = node("DangerousScript", "Script", static)
local unrelated = node("Unknown", "Model", root)
node("MaliciousButUnknown", "MeshPart", unrelated)
local all = Layout.collect(root, expected, function(part)
    return part.ClassName == "MeshPart"
end)
assert(all and #all[expected[1]] == 2 and #all[expected[2]] == 1)
assert(all[expected[1]][1] == body and all[expected[1]][2] == detail)
assert(all[expected[2]][1] == mag)
assert(Layout.componentName(expected[1] .. "_Node", expected) == expected[1])
assert(Layout.componentName(expected[1] .. "_extra", expected) == nil)
assert(Layout.componentName("Unknown", expected) == nil)
assert(Layout.collect(root, expected, function(part) return part ~= body end) == nil,
    "PBR validation must apply to EACH imported material primitive")
assert(Layout.collect(root, {"IRONYARD_Sniper_Bolt"}, function() return true end) == nil)
-- A single already-authorized MeshPart without nested Models is supported.
local one = node("LOD0", "Model")
node("IRONYARD_Pistol_Slide", "MeshPart", one)
local source = Layout.collect(one, {"IRONYARD_Pistol_Slide"}, function() return true end)
assert(source and #source.IRONYARD_Pistol_Slide == 1)
-- Duplicate authored root names are not merged silently.
local duplicate = node(expected[1], "Model", root)
node("Material_2", "MeshPart", duplicate)
assert(Layout.collect(root, expected, function() return true end) == nil)
duplicate.Parent=nil
for i,v in ipairs(root.children) do
    if v == duplicate then table.remove(root.children,i) break end
end
-- Bound cost and primitive count, even for trusted Roblox package containers.
for _=1, Layout.MAX_PER_COMPONENT do
    node("extra", "MeshPart", magazine)
end
assert(Layout.collect(root, expected, function() return true end) == nil,
    "Huge imported multi-primitive groups must be rejected")
assert(script and unrelated)
-- Authored root marker: require exactly one real MeshPart, even when a
-- GLB importer nests it under a _Node Model with a generic primitive name.
local originRoot = node("IRONYARD_WeaponOrigin_Node", "Model", root)
local originPart = node("Material_0", "MeshPart", originRoot)
assert(Layout.origin(root, function(part) return part == originPart end) == originPart)
assert(Layout.origin(root, function() return false end) == nil)
assert(Layout.origin(root, nil) == nil)
local secondRoot = node("IRONYARD_WeaponOrigin", "Model", root)
node("Marker_2", "MeshPart", secondRoot)
assert(Layout.origin(root, function() return true end) == nil,
    "Duplicated source marker must never become a weapon pivot")
print("IRON YARD glTF primitives and authored weapon origin: safety checks OK")

-- Optional PBR magazine: old two-piece kits load, but new extra meshes must
-- be validated, bounded, and unique before Roblox replication.
local pistolRoot = node("PistolLOD0", "Model")
local pistolStatic = node("IRONYARD_Pistol_Static_Node", "Model", pistolRoot)
node("Material_0", "MeshPart", pistolStatic)
local pistolSlide = node("IRONYARD_Pistol_Slide_Node", "Model", pistolRoot)
node("Material_0", "MeshPart", pistolSlide)
local req = {"IRONYARD_Pistol_Static", "IRONYARD_Pistol_Slide"}
local opt = {"IRONYARD_Pistol_Magazine"}
local old = Layout.collect(pistolRoot, req, function() return true end, opt)
assert(old and old.IRONYARD_Pistol_Magazine == nil,
    "Legacy two-piece owner PBR pistol must remain usable")
local pistolMagazine = node("IRONYARD_Pistol_Magazine_Node", "Model", pistolRoot)
local magPart = node("Material_0", "MeshPart", pistolMagazine)
local upgraded = Layout.collect(pistolRoot, req, function() return true end, opt)
assert(upgraded and upgraded.IRONYARD_Pistol_Magazine[1] == magPart)
assert(Layout.collect(pistolRoot, req, function(part)
    return part ~= magPart end, opt) == nil,
    "Invalid optional PBR map must not bypass validation")
assert(Layout.collect(pistolRoot, req, function() return true end, "bad") == nil)
local duplicateMagazine = node("IRONYARD_Pistol_Magazine", "Model", pistolRoot)
node("Material_0", "MeshPart", duplicateMagazine)
assert(Layout.collect(pistolRoot, req, function() return true end, opt) == nil,
    "Duplicate optional magazine roots are prohibited")
