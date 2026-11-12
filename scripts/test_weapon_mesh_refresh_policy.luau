local Refresh = require("../src/shared/WeaponMeshRefreshPolicy")
local safe = {
    scoped=false, sprinting=false, reloading=false, pendingCartridge=false,
    pendingFlash=false, aimBlend=0, reloadBlend=0, stepBlend=0,
    swayMagnitude=0, sinceReloadFinish=math.huge, sinceShot=3, sinceEquip=2,
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
for _, key in ipairs({"scoped", "sprinting", "reloading", "pendingCartridge", "pendingFlash"}) do
    local s = table.clone(safe)
    s[key] = true
    assert(not Refresh.shouldRefresh(true, "LOD0", "LOD1", true, s),
        "Never interrupt active weapon state: " .. key)
end
for _, row in ipairs({
    {"aimBlend", 0.1}, {"reloadBlend", 0.1}, {"sinceShot", 1.99},
    {"sinceEquip", 0.79}, {"sinceShot", 0/0}, {"aimBlend", 0/0},
    {"reloadBlend", math.huge},
    {"stepBlend", 0.061}, {"stepBlend", -0.01},
    {"stepBlend", 0/0}, {"stepBlend", math.huge},
    {"swayMagnitude", 0.013}, {"swayMagnitude", -0.01},
    {"swayMagnitude", 0/0}, {"swayMagnitude", math.huge},
    {"sinceReloadFinish", 0.49}, {"sinceReloadFinish", 0.649},
    {"sinceReloadFinish", -0.01}, {"sinceReloadFinish", 0/0},
}) do
    local s = table.clone(safe)
    s[row[1]] = row[2]
    assert(not Refresh.shouldRefresh(false, nil, "LOD0", true, s),
        "Unsafe timing or interpolated pose must defer the PBR swap")
end
-- The first fully idle safe instant is valid, including an untouched gun.
-- Avoid delaying quality changes after the shot/reload/turn have settled.
for _, limits in ipairs({
    {stepBlend = 0.06},
    {swayMagnitude = 0.012},
    {sinceReloadFinish = 0.65},
    {sinceReloadFinish = math.huge},
}) do
    local quiet = table.clone(safe)
    for key, value in pairs(limits) do quiet[key] = value end
    assert(Refresh.shouldRefresh(true, "LOD0", "LOD1", true, quiet),
        "Boundary-safe idle model swap must eventually execute")
end
for _, missing in ipairs({"stepBlend", "swayMagnitude", "sinceReloadFinish"}) do
    local state = table.clone(safe)
    state[missing] = nil
    assert(not Refresh.shouldRefresh(false, nil, "LOD1", true, state),
        "Incomplete mobility state must not trigger expensive mesh rebuild")
end
assert(Refresh.shouldRefresh(false, nil, "LOD0", true, safe))
print("IRON YARD live PBR: no mid-strafe/turn/reload-rack mesh rebuild; idle LOD recovery OK")
