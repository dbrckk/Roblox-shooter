-- IRON YARD: adaptive mobile FPS input geometry, without Roblox dependencies.
-- Bounds are pixel positions within the ScreenGui safe-area root.
-- A right-hand lane is reserved for Roblox's built-in jump button.
local Layout = {}
-- Player-selected button footprint. Same layout rules on every device;
-- the smaller choice keeps all essential hit targets >= 28 pixels.
Layout.PRESETS = { "COMPACT", "STANDARD", "LARGE" }
local FACTORS = { COMPACT = 0.92, STANDARD = 1, LARGE = 1.15 }
Layout.MIN_WIDTH = 260
Layout.MIN_HEIGHT = 210
Layout.MENU_BUTTONS = {
    Settings = { x = 8, y = 90, w = 44, h = 42 },
    Duel = { x = 8, y = 138, w = 44, h = 42 },
    CancelDuelSearch = { x = 8, y = 182, w = 44, h = 28 },
}
Layout.NAMES = {
    "AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife",
    "Sprint", "Slide", "Reload", "Fire", "Aim",
}
local WEAPONS = { "AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife" }
local ACTIONS = { "Reload", "Slide", "Sprint" }
local AIM_AND_FIRE = { "Fire", "Aim" }
local JUMP_CLEARANCE = 6

local function round(n)
    return math.floor(n + 0.5)
end
local function box(x, y, w, h)
    return { x = round(x), y = round(y), w = round(w), h = round(h) }
end

local function intersects(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w
        and a.y < b.y + b.h and b.y < a.y + a.h
end

local function clearJumpButton(buttons, row, jump, gap)
    local overlaps = false
    local totalWidth = 0
    local leftLimit = 0
    for _, name in ipairs(row) do
        local rect = buttons[name]
        overlaps = overlaps or intersects(rect, jump)
        totalWidth += rect.w
        for _, menu in pairs(Layout.MENU_BUTTONS) do
            if rect.y < menu.y + menu.h and menu.y < rect.y + rect.h then
                leftLimit = math.max(leftLimit, menu.x + menu.w + gap)
            end
        end
    end
    if not overlaps then return end

    local rightEdge = math.floor(jump.x)
    local minWidth = 28 * #row
    local available = rightEdge - leftLimit - gap * (#row - 1)
    -- Keep the existing row usable if the native geometry leaves too little
    -- space for its minimum hit targets. The other rows can still move.
    if available < minWidth then return end
    local scale = totalWidth > available and (available - minWidth) / (totalWidth - minWidth) or 1
    for _, name in ipairs(row) do
        local rect = buttons[name]
        rect.w = 28 + math.floor((rect.w - 28) * scale)
        rect.x = rightEdge - rect.w
        rightEdge = rect.x - gap
    end
end

function Layout.compute(width, height, preset, nativeJump)
    assert(type(width) == "number" and type(height) == "number"
        and width >= Layout.MIN_WIDTH and height >= Layout.MIN_HEIGHT, "Invalid touch viewport")
    local factor = FACTORS[preset or "STANDARD"]
    assert(factor, "Unknown touch size preset")
    local preferred = math.clamp(math.min(width / 720, height / 400), 0.76, 1.10) * factor
    -- Cap the full stack against the inset viewport, including compact
    -- landscape phones with Roblox's top bar and system insets applied.
    local heightBudget = height - 90
    local stackScale = heightBudget / 208
    -- At the smallest sizes the two utility rows and their gaps have
    -- a fixed 71-pixel minimum, including the bottom margin.
    local fireScale = (heightBudget - 71) / 94
    local scale = math.min(preferred, stackScale, fireScale, (width - 62) / 269)
    local right = round(10 * scale)
    local gap = math.max(5, round(7 * scale))
    local weaponW, weaponH = math.max(28, round(46 * scale)), math.max(28, round(40 * scale))
    local actionW, actionH = math.max(35, round(67 * scale)), math.max(28, round(42 * scale))
    local fireSize = math.max(45, round(94 * scale))
    local aimW, aimH = math.max(33, round(70 * scale)), math.max(32, round(63 * scale))

    -- Leave the left menu lane clear, and reserve the right edge for the
    -- native jump control. On wide screens the controls sit below center.
    local weaponY = math.clamp(round(height * 0.24), 90, height - 86)
    local actionY = weaponY + weaponH + gap
    local fireY = actionY + actionH + gap
    local overflow = math.max(0, fireY + fireSize + 6 - height)
    weaponY -= overflow
    actionY -= overflow
    fireY -= overflow
    local buttons = {}

    for i, name in ipairs(WEAPONS) do
        buttons[name] = box(width - right - weaponW - (i - 1) * (weaponW + gap),
            weaponY, weaponW, weaponH)
    end
    for i, name in ipairs(ACTIONS) do
        buttons[name] = box(width - right - actionW - (i - 1) * (actionW + gap),
            actionY, actionW, actionH)
    end

    local fireX = width - right - math.max(65, round(78 * scale)) - fireSize
    buttons.Fire = box(fireX, fireY, fireSize, fireSize)
    buttons.Aim = box(fireX - gap - aimW,
        fireY + round((fireSize - aimH) / 2), aimW, aimH)
    if nativeJump and nativeJump.w > 0 and nativeJump.h > 0 then
        local jump = {
            x = nativeJump.x - JUMP_CLEARANCE, y = nativeJump.y - JUMP_CLEARANCE,
            w = nativeJump.w + JUMP_CLEARANCE * 2, h = nativeJump.h + JUMP_CLEARANCE * 2,
        }
        clearJumpButton(buttons, WEAPONS, jump, gap)
        clearJumpButton(buttons, ACTIONS, jump, gap)
        clearJumpButton(buttons, AIM_AND_FIRE, jump, gap)
    end
    return buttons
end

-- Also reserve a reachable settings button outside the firing cluster.
-- Per-frame runtime cost is zero: this function runs only on resize/preset changes.
function Layout.check(width, height, buttons)
    for menuName, menu in pairs(Layout.MENU_BUTTONS) do
        if menu.x < 0 or menu.y < 88 or menu.x + menu.w > width or menu.y + menu.h > height then
            return false, "Mobile menu button outside safe viewport"
        end
        for otherName, other in pairs(Layout.MENU_BUTTONS) do
            if menuName < otherName and intersects(menu, other) then
                return false, "Mobile menu buttons overlap"
            end
        end
    end
    for _, name in ipairs(Layout.NAMES) do
        local r = buttons[name]
        if not r or r.w < 28 or r.h < 28 or r.x < 0 or r.y < 88
            or r.x + r.w > width or r.y + r.h > height then
            return false, "Invalid/hidden touch button: " .. name
        end
        for _, menu in pairs(Layout.MENU_BUTTONS) do
            if intersects(r, menu) then
                return false, "Touch button overlaps a menu: " .. name
            end
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
