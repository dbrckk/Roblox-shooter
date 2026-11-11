local Refresh = require("../src/shared/WeaponMeshRefreshPolicy")
local safe = {
    scoped=false, sprinting=false, reloading=false, pendingCartridge=false,
    aimBlend=0, reloadBlend=0, sinceShot=3, sinceEquip=2,
}
assert(Refresh.shouldRefresh(false, nil, "LOD1", true, safe),
    "Procedural viewmodel must upgrade once valid LOD arrives")
assert(Refresh.shouldRefresh(true, "LOD0", "LOD1", true, safe),
    "ECO switch must downgrade an imported high-poly viewmodel")
assert(Refresh.shouldRefresh(true, "LOD1", "LOD0", true, safe),
    "Quality switch must upgrade the imported mesh")
assert(not Refresh.shouldRefresh(true, "LOD0", "LOD0", true, safe),
    "Never rebuild an already correct weapon")
assert(not Refresh.shouldRefresh(false, nil, "LOD0", false, safe),
    "Unavailable/incomplete assets must keep procedural fallback")
assert(not Refresh.shouldRefresh(false, nil, "none", true, safe))
assert(not Refresh.shouldRefresh(false, nil, "LOD0", true, nil))
for _, key in ipairs({"scoped", "sprinting", "reloading", "pendingCartridge"}) do
    local s = table.clone(safe)
    s[key] = true
    assert(not Refresh.shouldRefresh(true, "LOD0", "LOD1", true, s),
        "Never interrupt active weapon state: " .. key)
end
for _, row in ipairs({
    {"aimBlend", 0.1}, {"reloadBlend", 0.1}, {"sinceShot", 1.99},
    {"sinceEquip", 0.79}, {"sinceShot", 0/0}, {"aimBlend", 0/0},
    {"reloadBlend", math.huge},
}) do
    local s = table.clone(safe)
    s[row[1]] = row[2]
    assert(not Refresh.shouldRefresh(false, nil, "LOD0", true, s),
        "Unsafe timing or interpolated pose must defer the PBR swap")
end
assert(Refresh.shouldRefresh(false, nil, "LOD0", true, safe))
print("IRON YARD live PBR: late assets, hot LOD changes and combat-safe deferred refresh OK")
