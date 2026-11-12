local Policy = require("../src/shared/RemoteRatePolicy")

local bucket = {}
assert(not Policy.allow(bucket, "Unknown", 0))
assert(not Policy.allow(bucket, "FireWeapon", 0 / 0))
assert(not Policy.allow(bucket, "FireWeapon", math.huge))
assert(not Policy.allow(nil, "FireWeapon", 0))

-- Exposing a profile must never grant write access to the server's quotas.
local mutable = Policy.profile("FireWeapon")
local originalRate, originalBurst = mutable.rate, mutable.burst
mutable.rate, mutable.burst = 999999, 999999
assert(Policy.profile("FireWeapon").rate == originalRate)
assert(Policy.profile("FireWeapon").burst == originalBurst)
assert(Policy.profile("Missing") == nil)
local probe = {}
for _ = 1, originalBurst do
    assert(Policy.allow(probe, "FireWeapon", 0))
end
assert(not Policy.allow(probe, "FireWeapon", 0),
    "Mutating a returned profile must not increase the real quota")
assert(not Policy.allow(probe, "FireWeapon", 0.001),
    "Mutating a returned profile must not increase refill speed")
local profile = Policy.profile("FireWeapon")
assert(profile.rate >= 9 and profile.burst >= 9,
    "Normal 8.7Hz assault rifle is not throttled")
for _ = 1, profile.burst do
    assert(Policy.allow(bucket, "FireWeapon", 10))
end
assert(not Policy.allow(bucket, "FireWeapon", 10), "Per-channel burst is capped")
assert(not Policy.allow(bucket, "FireWeapon", 9), "Backwards client-like times rejected")
assert(Policy.allow(bucket, "FireWeapon", 10.06),
    "Legitimate follow-up fire is promptly refilled")
assert(not Policy.allow(bucket, "FireWeapon", 10.06))
assert(Policy.allow(bucket, "FireWeapon", 11),
    "Normal traffic resumes after a flood without permanent lockout")

local other = {}
for _ = 1, profile.burst do
    assert(Policy.allow(other, "FireWeapon", 10),
        "Other player budget not consumed by the first one")
end
assert(Policy.allow(bucket, "EquipWeapon", 10),
    "Weapon swaps must not share fire bucket")
assert(Policy.allow(bucket, "ReloadWeapon", 10),
    "Reloads must not be blocked by weapon fire")
local duelProfile = Policy.profile("SetDuelReady")
assert(duelProfile.rate >= 2 and duelProfile.burst >= 2)
local duelBucket = {}
for _ = 1, duelProfile.burst do
    assert(Policy.allow(duelBucket, "SetDuelReady", 50))
end
assert(not Policy.allow(duelBucket, "SetDuelReady", 50))
assert(Policy.allow(duelBucket, "SetDuelReady",
    50 + 1 / duelProfile.rate))
assert(Policy.allow(duelBucket, "FireWeapon", 50))
local aimProfile = Policy.profile("SetAiming")
assert(aimProfile.rate >= 8 and aimProfile.burst >= 6)
local aimBucket = {}
for _ = 1, aimProfile.burst do
    assert(Policy.allow(aimBucket, "SetAiming", 20))
end
assert(not Policy.allow(aimBucket, "SetAiming", 20))
assert(Policy.allow(aimBucket, "SetAiming", 20 + 1 / aimProfile.rate))
assert(Policy.allow(aimBucket, "FireWeapon", 20))
assert(Policy.profile("MovementUpdate").rate > 13,
    "12.5Hz boost and wallrun updates should pass on normal devices")

local burst = Policy.profile("MovementUpdate").burst
for _ = 1, burst do assert(Policy.allow(bucket, "MovementUpdate", 20)) end
assert(not Policy.allow(bucket, "MovementUpdate", 20))
assert(Policy.allow(bucket, "MovementStop", 20),
    "Safe movement stop survives update flood")
assert(Policy.channelForAction("BoostStop") == "MovementStop")
assert(Policy.channelForAction("StopWallRun") == "MovementStop")
assert(Policy.channelForAction("BoostUpdate") == "MovementUpdate")
assert(Policy.channelForAction("WallRunUpdate") == "MovementUpdate")
assert(Policy.channelForAction("Mantle") == nil)
assert(Policy.channelForAction({}) == nil)
assert(not Policy.allow(bucket, "MovementAction", -math.huge))
assert(not Policy.allow(bucket, "MovementAction", "not a number"))

-- A high-frequency sender cannot drive an arbitrary timestamp backward
-- or prevent refills by repeatedly requesting while out of tokens.
local spam = {}
local s = Policy.profile("SetSprinting")
for i = 1, 1000 do
    Policy.allow(spam, "SetSprinting", 30)
end
assert(spam.SetSprinting.tokens >= 0)
assert(not Policy.allow(spam, "SetSprinting", 30))
assert(Policy.allow(spam, "SetSprinting", 30 + 1 / s.rate),
    "Coalesced sprint state can recover after 1000 duplicate messages")
print("IRON YARD per-player remote budgets, emergency stop and flood recovery: OK")
