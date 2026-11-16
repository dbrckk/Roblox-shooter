-- IRON YARD / permanent non-gameplay sector names on the asphalt.
-- The signs are original, high-contrast wayfinding, not spawn objectives.
local LoadingDeck = require(script and script.Parent.LoadingDeckPlan or "./LoadingDeckPlan")
local Plan = {}

function Plan.zones()
    return {
        { id = "01", x = -52, z = -112, label = "WEST / SOUTH" },
        { id = "02", x = 52, z = -112, label = "EAST / SOUTH" },
        { id = "03", x = -52, z = 112, label = "WEST / NORTH" },
        { id = "04", x = 52, z = 112, label = "EAST / NORTH" },
    }
end

function Plan.transferRoutes()
    local ramp = LoadingDeck.ramp()
    local rampFootZ = ramp.z + math.sin(ramp.pitch) * ramp.height / 2
        + math.cos(ramp.pitch) * ramp.length / 2
    local turnZ = LoadingDeck.z + LoadingDeck.depth / 2 - 1.5
    local westLane = -16.5
    return {
        {
            id = "RAMP",
            label = "RAMP / UP",
            x = ramp.x,
            z = rampFootZ + 8,
            arrows = {
                { x = ramp.x, z = rampFootZ + 5, yaw = 0 },
                { x = ramp.x, z = rampFootZ + 2.4, yaw = 0 },
            },
        },
        {
            id = "UNDERPASS",
            label = "UNDERPASS",
            x = westLane,
            z = rampFootZ + 8,
            arrows = {
                { x = westLane, z = 119, yaw = 0 },
                { x = westLane, z = 107, yaw = 0 },
                { x = westLane, z = 96, yaw = 0 },
                -- Go around the container before turning below the deck.
                { x = westLane, z = turnZ, yaw = -math.pi / 2 },
                { x = -6, z = turnZ, yaw = -math.pi / 2 },
                { x = 3.5, z = turnZ, yaw = -math.pi / 2 },
                { x = LoadingDeck.x - 3.4, z = turnZ, yaw = 0 },
                { x = LoadingDeck.x - 3.4, z = LoadingDeck.z, yaw = 0 },
            },
        },
    }
end

return Plan
