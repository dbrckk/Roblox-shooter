-- IRON YARD: adaptive mobile FPS input geometry, without Roblox dependencies.
-- Bounds are pixel positions within the ScreenGui safe-area root.
-- A right-hand lane is reserved for Roblox's built-in jump button.
local Layout = {}
-- Player-selected button footprint. Same layout rules on every device;
-- the smaller choice keeps all essential hit targets >= 28 pixels.
Layout.PRESETS = { "COMPACT", "STANDARD", "LARGE" }
local FACTORS = { COMPACT = 0.92, STANDARD = 1, LARGE = 1.15 }
-- Keep the settings access clear of the score bar and mobile weapon strip.
Layout.SETTINGS_BUTTON = { x = 8, y = 90, w = 52, h = 32 }
Layout.NAMES = {
    "AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife",
    "Sprint", "Slide", "Reload", "Fire", "Aim",
}
local function round(n)
    return math.floor(n + 0.5)
end
local function box(x, y, w, h)
    return { x = round(x), y = round(y), w = round(w), h = round(h) }
end

function Layout.compute(width, height, preset)
    assert(type(width) == "number" and type(height) == "number"
        and width >= 300 and height >= 260, "Invalid touch viewport")
    local factor = FACTORS[preset or "STANDARD"]
    assert(factor, "Unknown touch size preset")
    local scale = math.clamp(math.min(width / 720, height / 400), 0.76, 1.10) * factor
    local right = round(12 * scale)
    local gap = round(7 * scale)
    local weaponW, weaponH = round(46 * scale), round(40 * scale)
    local actionW, actionH = round(67 * scale), round(42 * scale)
    local fireSize = round(94 * scale)
    local aimW, aimH = round(70 * scale), round(63 * scale)

    -- All rows are ABOVE the lower built-in jump button. On compact phones
    -- the weapon strip is just under the score HUD; on tablets the cluster
    -- follows the player's right hand toward the middle of the screen.
    local fireY = math.max(82 + weaponH + gap + actionH + gap,
        round(height - 290 * scale))
    local actionY = fireY - gap - actionH
    local weaponY = actionY - gap - weaponH
    local buttons = {}

    for i, name in ipairs({ "AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife" }) do
        buttons[name] = box(width - right - weaponW - (i - 1) * (weaponW + gap),
            weaponY, weaponW, weaponH)
    end
    for i, name in ipairs({ "Reload", "Slide", "Sprint" }) do
        buttons[name] = box(width - right - actionW - (i - 1) * (actionW + gap),
            actionY, actionW, actionH)
    end

    local fireX = width - right - round(78 * scale) - fireSize
    buttons.Fire = box(fireX, fireY, fireSize, fireSize)
    buttons.Aim = box(fireX - gap - aimW,
        fireY + round((fireSize - aimH) / 2), aimW, aimH)
    return buttons
end

local function intersects(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w
        and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Also reserve a reachable settings button outside the firing cluster.
-- Per-frame runtime cost is zero: this function runs only on resize/preset changes.
function Layout.check(width, height, buttons)
    local settings = Layout.SETTINGS_BUTTON
    if settings.x < 0 or settings.y < 78
        or settings.x + settings.w > width
        or settings.y + settings.h > height then
        return false, "Mobile settings button outside safe viewport"
    end
    for _, name in ipairs(Layout.NAMES) do
        local r = buttons[name]
        if not r or r.w < 28 or r.h < 28 or r.x < 0 or r.y < 78
            or r.x + r.w > width or r.y + r.h > height then
            return false, "Invalid/hidden touch button: " .. name
        end
        if intersects(r, settings) then
            return false, "Touch button overlaps settings: " .. name
        end
    end
    for i = 1, #Layout.NAMES do
        local a = buttons[Layout.NAMES[i]]
        for j = i + 1, #Layout.NAMES do
            local b = buttons[Layout.NAMES[j]]
            if intersects(a, b) then
                return false, "Overlapping touch buttons: "
                    .. Layout.NAMES[i] .. " / " .. Layout.NAMES[j]
            end
        end
    end
    return true
end

return Layout
