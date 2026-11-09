-- Distance, overlap and local-shooter priority are pure and deterministic.
local Audio = require("../src/shared/WeaponAudioPolicy")
local function allowed(preset, mobile, distance, count)
    return Audio.select(preset, mobile, distance, false, count)
end

local eco = allowed("ECO", true, 30, 0)
assert(eco and eco.layers == 2 and eco.maxVoices == 8)
assert(allowed("ECO", true, 96, 0) == nil, "Mobile ECO range culling")
assert(allowed("ECO", true, 95, 0) ~= nil, "Distance inclusive at boundary")
assert(allowed("ECO", true, 35, 8) == nil, "Mobile ECO voice cap")
assert(allowed("BALANCED", true, 100, 0).layers == 1, "Far audio reduces layers")
assert(allowed("BALANCED", true, 60, 0).layers == 2, "Near audio stays layered")
assert(allowed("BALANCED", true, 131, 0) == nil)
assert(allowed("BALANCED", false, 170, 0).layers == 1)
assert(allowed("QUALITY", false, 204, 0) ~= nil)
assert(allowed("QUALITY", false, 206, 0) == nil)
assert(allowed("QUALITY", false, 30, 24) == nil)
assert(allowed("QUALITY", true, 30, 16) == nil)
assert(allowed("QUALITY", true, 30, 15) ~= nil)
assert(allowed(nil, true, 130, 0) ~= nil, "Unknown preset defaults to balanced")
assert(allowed("ECO", true, math.huge, 0) == nil)
assert(allowed("ECO", true, 0/0, 0) == nil)
assert(allowed("ECO", true, 10, -1) == nil)
local localMix = Audio.select("ECO", true, 900, true, 900)
assert(localMix and localMix.layers == 2 and localMix.volume == 1,
    "Local shooter sound remains immediate regardless of other shots")
-- Different weapons no longer broadcast identical acoustic reach.
local rifle = Audio.select("BALANCED", true, 120, false, 0, "AssaultRifle")
local pistol = Audio.select("BALANCED", true, 120, false, 0, "Pistol")
local shotgun = Audio.select("BALANCED", true, 120, false, 0, "Shotgun")
local knife = Audio.select("BALANCED", true, 120, false, 0, "Knife")
assert(rifle and rifle.maxDistance == 130)
assert(not pistol and not shotgun and not knife, "Compact weapons fall silent at range")
assert(Audio.select("BALANCED", true, 95, false, 0, "Pistol"))
assert(Audio.select("BALANCED", true, 48, false, 0, "Knife"))
assert(not Audio.select("BALANCED", true, 51, false, 0, "Knife"))
assert(Audio.select("ECO", true, 1000, true, 1000, "Knife").layers == 2,
    "Owner hears every own shot even outside the acoustic range")
assert(not Audio.select("ECO", true, 30, false, 8, "Sniper"),
    "Weapon-specific range must not bypass the global voice cap")
-- A single inexpensive collision probe is permitted for already-admitted
-- distant remote voices; the firing player's immediate mix never changes.
assert(not Audio.needsOcclusion(0, false))
assert(not Audio.needsOcclusion(11.99, false))
assert(Audio.needsOcclusion(12, false))
assert(Audio.needsOcclusion(120, false))
assert(not Audio.needsOcclusion(120, true))
assert(not Audio.needsOcclusion(math.huge, false))
assert(not Audio.needsOcclusion(0/0, false))
local clear = Audio.select("BALANCED", true, 50, false, 0, "AssaultRifle")
local covered = Audio.occludedMix(clear, true)
assert(covered and covered ~= clear, "Occlusion produces a new, independent mix")
assert(covered.layers == 1, "Cover removes the bright second layer")
assert(covered.volume == clear.volume * 0.40,
    "Cover is quieter but never completely silent")
assert(covered.maxDistance == clear.maxDistance
    and covered.lifetime == clear.lifetime and covered.maxVoices == clear.maxVoices,
    "Cover never raises distance, lifetime or voice allocations")
assert(clear.layers == 2 and clear.volume == 1, "Uncovered mix not mutated")
assert(Audio.occludedMix(clear, false) == clear)
assert(Audio.occludedMix(nil, true) == nil)
print("IRON YARD local-priority spatial weapon audio and capped remote voices: OK")
