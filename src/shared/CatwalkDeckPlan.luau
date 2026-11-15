-- IRON YARD / physical platform-matched visual dressing plan.
-- Only recognizes the two real elevated decks and ten real access steps.
-- This module is pure Luau, with no collision or Roblox object creation.
local Plan = {}

local function matches(value, expected)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
        and math.abs(value - expected) <= 0.02
end

function Plan.forCollider(name, width, height, depth)
    if type(name) ~= "string" then return nil end

    local side
    if name == "CATWALK / loading platform -1" then
        side = -1
    elseif name == "CATWALK / loading platform 1" then
        side = 1
    end
    if side then
        if not matches(width, 64) or not matches(height, 3)
            or not matches(depth, 52) then return nil end
        return { kind = "DECK", side = side, number = side == -1 and 1 or 2 }
    end

    local landingSide = name:match("^CATWALK / access landing (%-?1)$")
    if landingSide then
        local landing = Plan.landing(tonumber(landingSide))
        if not matches(width, landing.width) or not matches(height, landing.height)
            or not matches(depth, landing.depth) then return nil end
        return { kind = "LANDING", side = tonumber(landingSide) }
    end

    local sideText, stepText = name:match("^CATWALK / access stair (%-?1):([1-5])$")
    if not sideText or (sideText ~= "-1" and sideText ~= "1") then
        return nil
    end
    local step = tonumber(stepText)
    if not step or not matches(width, 18)
        or not matches(height, step * 2)
        or not matches(depth, 5) then return nil end
    return { kind = "STEP", side = tonumber(sideText), step = step }
end

function Plan.landing(side)
    return { x = side * 85, y = 10.75, z = -5, width = 5, height = 1.5, depth = 5 }
end

function Plan.deckStrips()
    -- Existing railing and drainage guides are built at relative
    -- x = -20, -10, 0, 10, 20. Gaps between six plates respect these.
    return { -25, -15, -5, 5, 15, 25 }
end

return Plan
