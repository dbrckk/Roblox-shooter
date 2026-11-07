-- IRON YARD / pure deterministic freight surface placement.
-- Match the eight authoritative MapService container colliders exactly.
-- Decorations are cosmetic only; they may never modify these colliders.
local Plan = {}

function Plan.containers()
    local list = {}
    for row = -1, 1 do
        for column = -1, 1 do
            if row ~= 0 or column ~= 0 then
                table.insert(list, {
                    id = string.format("%d:%d", row, column),
                    x = column * 100,
                    z = row * 103,
                    height = 15 + ((row + column + 6) % 3) * 6,
                    variant = (row + 1) * 3 + (column + 1),
                })
            end
        end
    end
    return list
end

-- Asphalt patch locations are within the main 356x356 level but outside
-- the solid 64-stud-wide central warehouse and major container collider
-- footprints. These never become footstep geometry or raycast surfaces.
function Plan.repairs()
    local repairs = {}
    for _, side in ipairs({ -1, 1 }) do
        for index = 1, 6 do
            table.insert(repairs, {
                x = side * (49 + (index % 2) * 8),
                z = -129 + (index - 1) * 51,
                rotation = (index % 3 - 1) * 0.075,
                width = 9 + (index % 2) * 2,
                length = 6.6 + (index % 3),
            })
        end
    end
    return repairs
end

return Plan
