-- IRON YARD / exact whitelist for freight combat-cover material faces.
-- Pure Luau; MapService owns collision and raycasts. Never accept arbitrary
-- prefixed parts or modified dimensions as a legitimate combat cover.
local CoverSurfacePlan = {}

local function dimension(value, expected)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
        and math.abs(value - expected) <= 0.02
end

local function roadblockExists(index)
    if index < 1 or index > 16 or index % 1 ~= 0 then return false end
    -- Exactly mirrors the existing static MapService arena placement gate.
    local angle = index * math.pi / 8
    local radius = 57 + index % 3 * 10
    local x, z = math.cos(angle) * radius, math.sin(angle) * radius
    return z > -46 or math.abs(x) > 35
end

function CoverSurfacePlan.forCollider(name, x, y, z)
    if type(name) ~= "string" then return nil end
    local style, serial, marked

    local rowText, colText, flankText = name:match(
        "^COVER / concrete barrier (%-?%d+):(%-?%d+):(%-?%d+)$")
    if rowText then
        local row, column, flank = tonumber(rowText), tonumber(colText), tonumber(flankText)
        if not row or not column or not flank
            or tostring(row) ~= rowText or tostring(column) ~= colText
            or tostring(flank) ~= flankText
            or math.abs(row) > 1 or math.abs(column) > 1
            or (row == 0 and column == 0)
            or math.abs(flank) ~= 1
            or not dimension(x, 13) or not dimension(y, 5.5)
            or not dimension(z, 6) then return nil end
        style = "CAST_CONCRETE"
        local freightIndex = (row + 1) * 3 + column + 2
        serial = string.format("IY / BAY %02d", freightIndex)
        marked = flank == 1
    else
        local roadText = name:match("^COVER / movable roadblock (%d+)$")
        if roadText then
            local index = tonumber(roadText)
            if not index or tostring(index) ~= roadText
                or not roadblockExists(index)
                or not dimension(x, 13) or not dimension(y, 5)
                or not dimension(z, 5) then return nil end
            style = "ARMED_ROADBLOCK"
            serial = string.format("IY / ROAD %02d", index)
            marked = index % 3 == 1
        else
            local sideText = name:match("^WAREHOUSE / cover (%-?%d+)$")
            if sideText then
                local side = tonumber(sideText)
                if not side or tostring(side) ~= sideText
                    or math.abs(side) ~= 1
                    or not dimension(x, 9) or not dimension(y, 4.3)
                    or not dimension(z, 12) then return nil end
                style = "CARGO_BARRIER"
                serial = side == -1 and "IY / WEST CARGO" or "IY / EAST CARGO"
                marked = true
            elseif name == "VAULT / packing station" then
                if not dimension(x, 14) or not dimension(y, 5)
                    or not dimension(z, 9) then return nil end
                style = "CARGO_BARRIER"
                serial = "IY / PACKING"
                marked = true
            else
                return nil
            end
        end
    end

    return {
        style = style,
        length = x,
        height = y,
        width = z,
        faceLength = x - 0.8,
        faceHeight = y - 0.65,
        stripeCount = math.clamp(math.floor(x / 4), 2, 5),
        surfaceOffset = z * 0.5 + 0.038,
        serial = marked and serial or nil,
    }
end

return CoverSurfacePlan
