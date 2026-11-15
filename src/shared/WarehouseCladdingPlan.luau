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

Plan.MAX_RELIEF = 0.18

-- The exterior uses the actual wall-local basis. Reject mismatched collider
-- dimensions rather than leaving an unsupported panel after a map edit.
function Plan.exteriorFace(name, sx, sy, sz)
    if type(sx) ~= "number" or type(sy) ~= "number" or type(sz) ~= "number" then return nil end
    if not (math.abs(sy - 16) <= 0.02) then return nil end
    if name == "WAREHOUSE / north bulkhead"
        and math.abs(sx - 64) <= 0.02 and math.abs(sz - 3) <= 0.02 then
        return { normalX = 0, normalZ = 1, width = sx, height = sy, halfDepth = sz * 0.5,
            bays = 3, label = "SEALED" }
    end
    if (name == "WAREHOUSE / west wall" or name == "WAREHOUSE / east wall")
        and math.abs(sx - 3) <= 0.02 and math.abs(sz - 72) <= 0.02 then
        local west = name == "WAREHOUSE / west wall"
        return { normalX = west and -1 or 1, normalZ = 0, width = sz, height = sy,
            halfDepth = sx * 0.5, bays = 4, label = west and "WEST SERVICE" or "EAST SERVICE" }
    end
    return nil
end

function Plan.exteriorPanels(face)
    local pieces = {}
    local function add(name, u, v, depth, w, h, thickness, finish, tier, text)
        table.insert(pieces, {
            name = name, u = u, v = v, depth = depth, w = w, h = h, thickness = thickness,
            finish = finish, tier = tier, text = text,
        })
    end
    local spacing = face.width / face.bays
    local rear = face.normalZ == 1
    for i = 1, face.bays do
        local u = (i - (face.bays + 1) * 0.5) * spacing
        add("pressed bay " .. i, u, 0.46, 0.039, spacing - 0.82, 14.2, 0.056,
            i % 2 == 0 and "steel" or "zinc", "Core")
        add("plinth " .. i, u, -6.24, 0.077, spacing - 1.10, 1.62, 0.047, "graphite", "Core")
        if rear then
            add("closed loading shutter " .. i, u, -1.22, 0.081,
                spacing - 4.4, 10.0, 0.064, "graphite", "Core")
            for _, side in ipairs({ -1, 1 }) do
                add("recess track " .. i .. ":" .. side, u + side * (spacing - 4.05) * 0.5, -1.22,
                    0.134, 0.29, 10.0, 0.031, "trim", "Core")
            end
            for row = 0, 3 do
                add("shutter seam " .. i .. ":" .. row, u, -4.68 + row * 2.15,
                    0.127, spacing - 4.96, 0.105, 0.025, "trim", "Detail")
            end
        else
            -- A high vent reads as equipment while the lower wall stays solid.
            add("vent surround " .. i, u, 3.95, 0.089, spacing - 5.4, 2.13, 0.050, "graphite", "Core")
            for slat = -1, 1 do
                add("vent grille " .. i .. ":" .. slat, u, 3.95 + slat * 0.49,
                    0.124, spacing - 6.1, 0.108, 0.027, "trim", "Detail")
            end
        end
        if rear or i == 2 then
            local title = rear and string.format("BAY %02d  /  SEALED", i) or face.label
            add("service plate " .. i, u, rear and 5.08 or -0.35, 0.124,
                rear and 9.30 or 10.4, 1.02, 0.041, "cream", "Core", title)
        end
    end
    for seam = 1, face.bays - 1 do
        add("panel joint " .. seam, (seam - face.bays * 0.5) * spacing, 0.42, 0.069,
            0.24, 14.2, 0.035, "graphite", "Core")
    end
    add("upper beam", 0, 7.45, 0.077, face.width - 0.66, 0.35, 0.054, "graphite", "Core")
    add("safety datum", 0, -6.8, 0.124, face.width - 1.4, 0.19, 0.028, "amber", "Core")
    return pieces
end

function Plan.withinExterior(face, piece)
    return math.abs(piece.u) + piece.w * 0.5 <= face.width * 0.5
        and math.abs(piece.v) + piece.h * 0.5 <= face.height * 0.5
        and piece.depth >= 0 and piece.depth + piece.thickness * 0.5 <= Plan.MAX_RELIEF
end

return Plan
