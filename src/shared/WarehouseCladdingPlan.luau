-- IRON YARD / deterministic inner warehouse cladding layout.
-- MapService owns every wall collision volume; these coordinates only
-- decorate its existing 3-stud-thick walls and sealed north bulkhead.
local Plan = {}
Plan.INNER_FACE_X = 28.5
Plan.BULKHEAD_FACE_Z = 59.5

function Plan.sidePanels()
    local panels = {}
    for _, side in ipairs({ -1, 1 }) do
        for bay = 1, 4 do
            table.insert(panels, {
                side = side,
                bay = bay,
                x = side * (Plan.INNER_FACE_X - 0.18),
                y = 8.45,
                z = -16 + (bay - 1) * 18,
                height = 13.7,
                length = 17.25,
            })
        end
    end
    return panels
end

function Plan.bulkheadPanels()
    local panels = {}
    for bay = 1, 3 do
        table.insert(panels, {
            bay = bay,
            x = (bay - 2) * 20,
            y = 7.85,
            z = Plan.BULKHEAD_FACE_Z - 0.22,
            height = 12.7,
            length = 18.5,
        })
    end
    return panels
end

return Plan
