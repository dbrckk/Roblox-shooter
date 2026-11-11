-- Offline weapon upload/owner gating; no Roblox service or network calls.
local P = require("../src/shared/WeaponAssetPolicy")
local registry = {
    ownerUserId = 9774173158,
    modelIds = {
        Pistol = { LOD0 = 1, LOD1 = 2 },
        Knife = { LOD0 = 3, LOD1 = 4 },
        AssaultRifle = { LOD0 = 5, LOD1 = 6 },
        Shotgun = { LOD0 = 7, LOD1 = 8 },
        Sniper = { LOD0 = 9, LOD1 = 10 },
    },
}
assert(P.sameOwner(registry, "User", 9774173158))
assert(not P.sameOwner(registry, "Group", 9774173158))
assert(not P.sameOwner(registry, "User", 1))
assert(not P.sameOwner(nil, "User", 9774173158))
assert(P.isComplete(registry))
for _, id in ipairs(P.Weapons) do
    assert(P.pair(registry, id) == registry.modelIds[id])
    local row = registry.modelIds[id]
    local old = row.LOD1
    for _, value in ipairs({ 0, -1, math.huge, 0/0, 2.5, "123", row.LOD0 }) do
        row.LOD1 = value
        assert(not P.pair(registry, id), "Invalid LOD1 must fail closed")
        assert(not P.isComplete(registry))
    end
    row.LOD1 = old
end
assert(not P.pair(registry, "Other"))
assert(not P.pair(nil, "Pistol"))
assert(P.isComplete(registry))
print("IRON YARD owned GLB activation: 5 pairs, creator guard and invalid ID rejection OK")
