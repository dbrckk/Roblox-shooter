-- IRON YARD / permanent non-gameplay sector names on the asphalt.
-- The signs are original, high-contrast wayfinding, not spawn objectives.
local Plan = {}

function Plan.zones()
    return {
        { id = "01", x = -52, z = -112, label = "WEST / SOUTH" },
        { id = "02", x = 52, z = -112, label = "EAST / SOUTH" },
        { id = "03", x = -52, z = 112, label = "WEST / NORTH" },
        { id = "04", x = 52, z = 112, label = "EAST / NORTH" },
    }
end

return Plan
