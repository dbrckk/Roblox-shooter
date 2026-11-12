-- IRON YARD / executable TTK baseline harness (LOT 0a of the RIVALS gap plan).
-- Locks the CURRENT cadence/damage values so any balance change is deliberate.
-- It does NOT measure player accuracy, shotgun dispersion, recoil control,
-- network latency or Roblox frame pacing: expected seconds assume every
-- accepted shot connects on the chosen hit zone from t = 0.
local Config = require("../src/shared/WeaponConfig")
local TtkModel = require("../src/shared/TtkModel")

local TOLERANCE = 1e-6
local HEALTH = 100

-- Locked 12 November 2026 values, computed at 15 studs with a full pellet
-- load AND the server's shotgun falloff/rounded aggregate damage.
-- Changing damage, falloff, reload or cadence must update this table.
local BASELINE = {
    AssaultRifle = { body = { 5, 0.460 }, head = { 3, 0.230 } },
    Pistol = { body = { 3, 0.440 }, head = { 1, 0.000 } },
    Shotgun = { body = { 2, 0.840 }, head = { 1, 0.000 } },
    Sniper = { body = { 2, 1.150 }, head = { 1, 0.000 } },
    Knife = { body = { 1, 0.078947368 }, head = { 1, 0.078947368 } },
}

-- The existing test_arsenal_baseline locks theoretical POINT-BLANK shots.
-- Compare it at zero range; it intentionally ignores falloff, whereas
-- BASELINE locks server-equivalent results at 15 studs.
local ARSENAL_SHOTS = {
    AssaultRifle = { body = 5, head = 3 },
    Pistol = { body = 3, head = 1 },
    Shotgun = { body = 1, head = 1 },
    Sniper = { body = 2, head = 1 },
    Knife = { body = 1, head = 1 },
}

local function close(actual, expected, label)
    assert(type(actual) == "number" and math.abs(actual - expected) < TOLERANCE,
        string.format("%s: expected %.6fs, got %s", label, expected,
            tostring(actual)))
end

local function rows(weaponId)
    local weapon = Config.get(weaponId)
    assert(weapon, "WeaponConfig is missing " .. weaponId)
    return weapon, BASELINE[weaponId], ARSENAL_SHOTS[weaponId]
end

-- 1. Every weapon has a locked shot count AND a locked TTK at 15 studs.
for _, weaponId in ipairs(Config.Order) do
    local weapon, locked, arena = rows(weaponId)
    for _, zone in ipairs({ "body", "head" }) do
        local result = TtkModel.timeToKill(weapon, { studs = 15, zone = zone })
        assert(result, weaponId .. " cannot damage a 15-stud target")
        assert(result.shots == locked[zone][1],
            weaponId .. " " .. zone .. " shot count drifted")
        local pointBlank = TtkModel.timeToKill(weapon, { studs = 0, zone = zone })
        assert(pointBlank and pointBlank.shots == arena[zone],
            weaponId .. " disagrees with the point-blank arsenal baseline")
        close(result.seconds, locked[zone][2],
            weaponId .. " " .. zone .. " TTK drifted")
        assert(result.studs == 15 and result.zone == zone,
            weaponId .. " result must echo its request")
    end
end

-- 2. Range gating: no damage beyond the authored server range.
assert(TtkModel.timeToKill(Config.get("AssaultRifle"), { studs = 500 }) == nil,
    "AR-24 must not damage a target beyond 440 studs")
assert(TtkModel.timeToKill(Config.get("Shotgun"), { studs = 150 }) == nil,
    "B-8 must not damage a target beyond 115 studs")
assert(TtkModel.timeToKill(Config.get("Shotgun"), { studs = 115 }) ~= nil,
    "B-8 must still reach its own maximum range")
assert(TtkModel.timeToKill(Config.get("Sniper"), { studs = 1500 }) ~= nil,
    "Sniper must reach its own maximum range")
assert(TtkModel.timeToKill(Config.get("Knife"), { studs = 291 }) == nil,
    "Throwing knife must not reach beyond 290 studs")

-- 3. Knife is a projectile: its TTK is travel time, and it grows with range.
local travel = { 5 / 190, 15 / 190, 50 / 190, 100 / 190 }
local previousTravel = -1
for index, studs in ipairs(TtkModel.RANGES) do
    local result = TtkModel.timeToKill(Config.get("Knife"), { studs = studs })
    assert(result, "Knife must reach " .. studs .. " studs")
    assert(result.travelSeconds > 0, "Projectile travel must be positive")
    close(result.travelSeconds, travel[index], "Knife travel at " .. studs)
    close(result.seconds, travel[index], "Knife TTK at " .. studs)
    assert(result.seconds > previousTravel,
        "Knife TTK must grow with distance")
    previousTravel = result.seconds
end

-- 4. Shotgun is pellet-based, distance-falloff and reload-sensitive.
-- The server aggregates 8 pellet hits with falloff and rounds once:
-- at 15 studs full body spread is 97 HP, not the nominal 104.
local shotgun = Config.get("Shotgun")
local landed = {
    -- landed, shots, seconds, rounded damage per shot, reloads
    { 8, 2, 0.84, 97, 0 },
    { 6, 2, 0.84, 72, 0 },
    { 4, 3, 1.68, 48, 0 },
    { 1, 9, 8.43, 12, 1 },
}
for _, case in ipairs(landed) do
    local result = TtkModel.timeToKill(shotgun,
        { studs = 15, pelletsLanded = case[1] })
    assert(result, "Shotgun must reach 15 studs")
    assert(result.shots == case[2],
        case[1] .. " landed pellets: unexpected shot count")
    assert(result.damagePerShot == case[4], "Server pellet falloff must be rounded once")
    assert(result.reloads == case[5], "Reload count must match magazine depletion")
    close(result.seconds, case[3], case[1] .. " landed pellets TTK")
end
local closeBody = TtkModel.timeToKill(shotgun, { studs = 5 })
assert(closeBody and closeBody.damagePerShot == 102 and closeBody.shots == 1,
    "A true close-range 8-pellet shotgun blast remains lethal")
local maxRangeBody = TtkModel.timeToKill(shotgun, { studs = shotgun.range })
assert(maxRangeBody and maxRangeBody.damagePerShot == 47
    and maxRangeBody.shots == 3, "Max-range damage is attenuated and rounded")
local fullHead = TtkModel.timeToKill(shotgun, { studs = 15, zone = "head" })
assert(fullHead and fullHead.damagePerShot == 119 and fullHead.shots == 1,
    "A full-headshot pellet hit remains lethal at 15 studs")
assert(TtkModel.damagePerShot(shotgun, "body", 8, 0) == 104,
    "Point-blank damage must still match the legacy baseline")

-- 5. Target health is a parameter, not a constant of the model.
local tanky = TtkModel.timeToKill(Config.get("AssaultRifle"),
    { studs = 15, health = 125 })
assert(tanky and tanky.shots == 6, "125 HP needs six AR-24 body shots")
close(tanky.seconds, 0.575, "125 HP AR-24 body TTK")

-- 6. ADS changes spread, never damage or cadence: no aim input exists here.
local hip = TtkModel.timeToKill(Config.get("AssaultRifle"), { studs = 15 })
local aimed = TtkModel.timeToKill(Config.get("AssaultRifle"),
    { studs = 15, aimed = true })
assert(hip.seconds == aimed.seconds and hip.shots == aimed.shots,
    "Aiming must not alter time-to-kill in the balance model")

-- 7. All five weapons remain in effective range at 100 studs (ideal hits).
for _, weaponId in ipairs(Config.Order) do
    local result = TtkModel.timeToKill(Config.get(weaponId), { studs = 100 })
    assert(result, weaponId .. " has no TTK at 100 studs")
    assert(result.seconds < 60,
        weaponId .. " TTK at 100 studs is unusably long: " .. result.seconds)
end

-- 8. Invalid inputs must fail loudly instead of producing a fake balance.
local function rejects(operation, label)
    local ok = pcall(operation)
    assert(not ok, "Harness accepted an invalid input: " .. label)
end
local weapon = Config.get("AssaultRifle")
rejects(function() TtkModel.shotsToKill(0, 100) end, "zero damage")
rejects(function() TtkModel.shotsToKill(-1, 100) end, "negative damage")
rejects(function() TtkModel.shotsToKill(0 / 0, 100) end, "NaN damage")
rejects(function() TtkModel.shotsToKill(24, 0) end, "zero health")
rejects(function() TtkModel.damagePerShot(weapon, "torso") end, "unknown zone")
rejects(function() TtkModel.damagePerShot(weapon, nil) end, "missing zone")
rejects(function() TtkModel.damagePerShot(shotgun, "body", 0) end,
    "zero landed pellets")
rejects(function() TtkModel.damagePerShot(shotgun, "body", 9) end,
    "more pellets than the weapon fires")
rejects(function() TtkModel.damagePerShot(shotgun, "body", 2.5) end,
    "fractional pellets")
rejects(function() TtkModel.timeToKill(weapon, { studs = -5 }) end,
    "negative distance")
rejects(function() TtkModel.timeToKill(weapon, { studs = 0 / 0 }) end,
    "NaN distance")
rejects(function() TtkModel.timeToKill(weapon, { health = 0 }) end,
    "zero health target")
rejects(function() TtkModel.timeToKill({ damage = 24, range = 440 }, {}) end,
    "weapon without cadence")
rejects(function() TtkModel.timeToKill(nil, {}) end, "missing weapon")

print("IRON YARD five-weapon TTK harness (cadence, range, pellets, health): OK")
