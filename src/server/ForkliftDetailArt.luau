-- IRON YARD / authored safety cabin and powertrain mechanical dressing.
-- Follows the actual forklift collider and fleet orientation. This module
-- contributes NO hitbox, bullet query, navigation blocker or live light.
local DetailArt = {}

local T = {
    carbon = Color3.fromRGB(42, 48, 50),
    steel = Color3.fromRGB(111, 122, 120),
    zinc = Color3.fromRGB(173, 179, 174),
    amber = Color3.fromRGB(223, 173, 80),
    glass = Color3.fromRGB(219, 224, 214),
    olive = Color3.fromRGB(105, 126, 94),
}

local function paint(parent, name, size, cf, color, material, tier)
    local p = Instance.new("Part")
    p.Name = "FORKLIFT / " .. name
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Color = color
    p.Material = material or Enum.Material.Metal
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p:SetAttribute("NeonArtTier", tier)
    p.Parent = parent
    return p
end

function DetailArt.decorate(folder, collider, plan)
    local base = collider.CFrame * CFrame.new(0, -collider.Size.Y * 0.5, 0)
        * CFrame.Angles(0, plan.yaw, 0)
    local function panel(name, size, offset, color, tier, material)
        return paint(folder, plan.label .. " / " .. name, size,
            base * CFrame.new(offset), color,
            material or Enum.Material.Metal, tier)
    end

    -- Readable cabin layout and front work lighting housings. There are
    -- no actual PointLights, server loops, custom meshes, or network events.
    panel("operator diamondplate footwell",
        Vector3.new(5.6, 0.16, 3.1), Vector3.new(0, 2.92, -1.02),
        T.carbon, "Core", Enum.Material.DiamondPlate)
    panel("weatherproof dashboard", Vector3.new(5.0, 0.70, 0.62),
        Vector3.new(0, 4.55, -2.68), T.steel, "Core")
    panel("instrument dial backing", Vector3.new(2.5, 0.43, 0.12),
        Vector3.new(0, 4.70, -2.25), T.carbon, "Detail")
    for _, side in ipairs({ -1, 1 }) do
        panel("operator roof side brace " .. side,
            Vector3.new(0.29, 0.44, 7.0),
            Vector3.new(side * 3.50, 7.02, 0.10), T.carbon, "Core")
        panel("operator foot protection " .. side,
            Vector3.new(0.17, 1.0, 2.9),
            Vector3.new(side * 3.52, 3.40, -0.8), T.carbon, "Detail")
        panel("work lamp housing " .. side,
            Vector3.new(0.90, 0.64, 0.19),
            Vector3.new(side * 2.48, 6.32, -3.22), T.carbon, "Core")
        panel("work lamp lens " .. side,
            Vector3.new(0.66, 0.42, 0.10),
            Vector3.new(side * 2.48, 6.32, -3.34),
            T.glass, "Detail", Enum.Material.Glass)
    end

    if plan.kind == "FREIGHT_LIFTER" then
        -- Heavy yellow material lift: mechanical crosshead, hydraulic
        -- manifold and rear finned cooling armor.
        panel("freight lifting crosshead",
            Vector3.new(5.75, 0.95, 0.54),
            Vector3.new(0, 3.58, -5.14), T.amber, "Core")
        panel("freight hydraulic manifold",
            Vector3.new(5.5, 0.39, 0.55),
            Vector3.new(0, 7.90, -4.99), T.carbon, "Core")
        panel("freight radiator protection",
            Vector3.new(5.85, 1.62, 0.17),
            Vector3.new(0, 2.42, 5.53), T.carbon,
            "Core", Enum.Material.DiamondPlate)
        for _, side in ipairs({ -1, 1 }) do
            panel("freight lifting guide " .. side,
                Vector3.new(0.22, 2.75, 0.42),
                Vector3.new(side * 2.63, 4.2, -4.91), T.steel, "Detail")
            panel("freight rear mudguard " .. side,
                Vector3.new(0.29, 0.62, 2.1),
                Vector3.new(side * 3.69, 3.03, 3.0),
                collider.Color, "Core")
        end
        for i = 1, 4 do
            panel("freight radiator fin " .. i,
                Vector3.new(4.70, 0.12, 0.10),
                Vector3.new(0, 1.82 + i * 0.25, 5.65),
                T.steel, "Detail")
        end
    elseif plan.kind == "YARD_HANDLER" then
        -- Olive utility machine: weather cover, side engine louvers
        -- and rollbar visibly distinct from the freight lifter.
        panel("yard reinforced counterweight",
            Vector3.new(6.45, 1.15, 0.72),
            Vector3.new(0, 2.84, 5.54), T.olive, "Core")
        panel("yard operator overhead rollbar",
            Vector3.new(6.9, 0.39, 0.52),
            Vector3.new(0, 7.03, -3.09), T.steel, "Core")
        for _, side in ipairs({ -1, 1 }) do
            panel("yard service hatch " .. side,
                Vector3.new(0.13, 1.1, 2.15),
                Vector3.new(side * 3.81, 2.55, 3.0), T.steel, "Core")
            for i = 1, 3 do
                panel("yard cooling louver " .. side .. ":" .. i,
                    Vector3.new(0.11, 0.12, 1.82),
                    Vector3.new(side * 3.92, 2.17 + i * 0.23, 3.0),
                    T.carbon, "Detail")
            end
        end
        panel("yard handling mast plate",
            Vector3.new(5.36, 0.42, 0.41),
            Vector3.new(0, 6.72, -5.10), T.amber, "Detail")
    end
end

return DetailArt
