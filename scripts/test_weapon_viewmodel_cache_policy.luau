-- Pure Luau regressions for ONE transient cached weapon viewmodel.
-- No Roblox engine required. Lifecycle / reparent wiring is also checked
-- in scripts/check_weapon_presentation_contract.py.
local P = require("../src/shared/WeaponViewmodelCachePolicy")

assert(P.TTL == 8 and P.MAX_PARTS == 80)
for _, id in ipairs({"AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife"}) do
    assert(P.shouldStore(id, "OtherWeapon", 1))
    assert(P.shouldStore(id, "OtherWeapon", P.MAX_PARTS))
    assert(not P.shouldStore(id, id, 20),
        "Same-weapon LOD refresh must never cache stale source")
    assert(not P.shouldStore(id, "OtherWeapon", P.MAX_PARTS + 1))
    assert(not P.shouldStore(id, "OtherWeapon", 0))
end
assert(not P.shouldStore(nil, "Pistol", 3))
assert(not P.shouldStore("", "Pistol", 3))
assert(not P.shouldStore("Pistol", nil, 3))
assert(not P.shouldStore("Pistol", "", 3))
assert(not P.shouldStore("Pistol", "Shotgun", 0/0))
assert(not P.shouldStore("Pistol", "Shotgun", math.huge))

local pbr = {
    model = true, parts = {true, true}, weaponId = "Pistol",
    imported = true, lod = "LOD1", stashedAt = 10,
}
assert(P.canReuse(pbr, "Pistol", "LOD1", 10))
assert(P.canReuse(pbr, "Pistol", "LOD1", 18),
    "An eight-second old slot is still eligible at the TTL boundary")
assert(not P.canReuse(pbr, "Pistol", "LOD1", 18.01))
assert(not P.canReuse(pbr, "Pistol", "LOD0", 11),
    "QUALITY/ECO switch requires a fresh authored MeshPart model")
assert(not P.canReuse(pbr, "Shotgun", "LOD1", 11),
    "Never reuse another weapon's cached model or mechanical parts")
assert(not P.canReuse(pbr, "Pistol", "unknown", 11))
assert(not P.expired(pbr, 10))
assert(not P.expired(pbr, 18))
for _, now in ipairs({0/0, math.huge, -math.huge, -1, 9.9, 18.01}) do
    assert(P.expired(pbr, now))
    assert(not P.canReuse(pbr, "Pistol", "LOD1", now))
end
for _, stashedAt in ipairs({0/0, math.huge, -math.huge, -1, "10"}) do
    local invalid = table.clone(pbr)
    invalid.stashedAt = stashedAt
    assert(P.expired(invalid, 10))
end
local empty = table.clone(pbr)
empty.parts = {}
assert(not P.canReuse(empty, "Pistol", "LOD1", 11))
local missing = table.clone(pbr)
missing.model = nil
assert(not P.canReuse(missing, "Pistol", "LOD1", 11))
local tooLarge = table.clone(pbr)
tooLarge.parts = table.create(P.MAX_PARTS + 1, true)
assert(not P.canReuse(tooLarge, "Pistol", "LOD1", 11))

local fallback = {
    model = true, parts = {true}, weaponId = "AssaultRifle",
    imported = false, lod = nil, stashedAt = 25,
}
assert(P.canReuse(fallback, "AssaultRifle", "LOD0", 25.1))
assert(P.canReuse(fallback, "AssaultRifle", "LOD1", 27),
    "Procedural gun remains valid while PBR arrives asynchronously")
fallback.lod = "LOD0"
assert(not P.canReuse(fallback, "AssaultRifle", "LOD0", 27))
assert(P.expired(nil, 27))
print("IRON YARD one-slot mobile weapon cache: TTL/LOD/bounded memory verified")
