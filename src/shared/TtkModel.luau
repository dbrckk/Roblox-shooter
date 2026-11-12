-- IRON YARD / pure time-to-kill harness for weapon balance work.
-- Reads no Roblox API, owns no damage value and never mutates WeaponConfig:
-- damage, cadence and range stay authored in WeaponConfig and enforced by the
-- server. This module only answers "how many accepted shots, and how long,
-- before a target at a given distance can die".
-- Time is measured from the first accepted shot at t = 0.
local TtkModel = {}

TtkModel.DEFAULT_HEALTH = 100
-- Ranges used by the balance baseline: point blank, typical duel, mid, long.
TtkModel.RANGES = { 5, 15, 50, 100 }
TtkModel.ZONES = { body = "damage", head = "headshotDamage" }

local function finite(number, label)
    assert(type(number) == "number" and number == number
        and number > -math.huge and number < math.huge,
        "Invalid " .. label)
    return number
end

local function positive(number, label)
    finite(number, label)
    assert(number > 0, "Invalid " .. label)
    return number
end

-- Accepted shots needed to remove `health`, never zero and never negative.
-- A one-shot weapon returns 1; nothing here can return 0.
function TtkModel.shotsToKill(damage, health)
    positive(damage, "damage per shot")
    positive(health, "target health")
    return math.ceil(health / damage)
end

-- Damage of one accepted shot on a hit zone. Shotgun damage is per pellet:
-- `pelletsLanded` defaults to the full pellet count and must stay in bounds,
-- because the model describes landed pellets, not random dispersion.
function TtkModel.damagePerShot(weapon, zone, pelletsLanded)
    assert(type(weapon) == "table", "Missing weapon definition")
    local field = TtkModel.ZONES[zone]
    assert(field, "Unknown hit zone: " .. tostring(zone))
    local base = positive(weapon[field], tostring(zone) .. " damage")
    local pellets = weapon.pellets
    if pellets == nil then return base end
    local landed = pelletsLanded == nil and pellets or pelletsLanded
    assert(type(landed) == "number" and landed == landed
        and landed % 1 == 0 and landed >= 1 and landed <= pellets,
        "Invalid pellets landed")
    return base * landed
end

-- Server range limits are part of the weapon identity: a shotgun cannot
-- damage a target beyond its 115-stud range, whatever the model says.
function TtkModel.reachesRange(weapon, studs)
    assert(type(weapon) == "table", "Missing weapon definition")
    finite(studs, "target distance")
    assert(studs >= 0, "Invalid target distance")
    return studs <= positive(weapon.range, "weapon range")
end

-- Returns nil when the target is out of the weapon's range: no accepted shot
-- can deal damage, so the weapon has no time-to-kill at that distance.
-- options: { studs = 15, zone = "body", health = 100, pelletsLanded = 8 }
function TtkModel.timeToKill(weapon, options)
    assert(type(weapon) == "table", "Missing weapon definition")
    local opts = options or {}
    local studs = opts.studs == nil and 15 or opts.studs
    finite(studs, "target distance")
    assert(studs >= 0, "Invalid target distance")
    if not TtkModel.reachesRange(weapon, studs) then return nil end

    local zone = opts.zone or "body"
    local health = opts.health == nil and TtkModel.DEFAULT_HEALTH or opts.health
    positive(health, "target health")
    local damage = TtkModel.damagePerShot(weapon, zone, opts.pelletsLanded)
    local shots = TtkModel.shotsToKill(damage, health)
    local cooldown = positive(weapon.fireCooldown, "fire cooldown")

    -- A projectile only lands after travelling; hitscan resolves immediately.
    local travel = 0
    if weapon.kind == "Projectile" then
        travel = studs / positive(weapon.projectileSpeed, "projectile speed")
    end

    return {
        zone = zone,
        studs = studs,
        shots = shots,
        damagePerShot = damage,
        travelSeconds = travel,
        seconds = (shots - 1) * cooldown + travel,
    }
end

return TtkModel
