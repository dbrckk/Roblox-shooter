-- IRON YARD / physical platform-matched visual dressing plan.
-- Matches physical catwalk pieces and shares the ramp opening with arena art.
-- This module is pure Luau, with no collision or Roblox object creation.
local Plan = {}

local deckCenterX = 118
local deckHalfDepth = 26
local deckTopY = 13
local rampOffsetX = 16
local rampWidth = 10
local rampThickness = 0.8

function Plan.ramp(side)
    local topZ = deckHalfDepth - 0.15
    local bottomZ = 57
    local run = bottomZ - topZ
    local pitch = math.atan(deckTopY / run)
    -- The endpoints describe the top face. Offset the center down along
    -- the ramp's local up axis so that face meets the deck and yard floor.
    return {
        x = side * (deckCenterX + rampOffsetX),
        y = (deckTopY - math.cos(pitch) * rampThickness) / 2,
        z = (topZ + bottomZ - math.sin(pitch) * rampThickness) / 2,
        width = rampWidth,
        thickness = rampThickness,
        length = math.sqrt(run * run + deckTopY * deckTopY),
        pitch = pitch,
    }
end

function Plan.deckEdgeSegments(side, edge, halfWidth)
    if edge < 0 then
        return { { center = 0, width = halfWidth * 2 } }
    end

    local center = side * rampOffsetX
    local halfGap = rampWidth / 2 + 0.45
    local left = center - halfGap
    local right = center + halfGap
    return {
        { center = (left - halfWidth) / 2, width = left + halfWidth },
        { center = (right + halfWidth) / 2, width = halfWidth - right },
    }
end

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

    local rampSide = tonumber(name:match("^CATWALK / access ramp (%-?1)$"))
    if rampSide then
        local ramp = Plan.ramp(rampSide)
        if not matches(width, ramp.width) or not matches(height, ramp.thickness)
            or not matches(depth, ramp.length) then return nil end
        return { kind = "RAMP", side = rampSide }
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
