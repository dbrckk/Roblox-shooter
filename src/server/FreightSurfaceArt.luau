-- IRON YARD / original Roblox-native freight finish and grounded yard wear.
-- These are art layers, NOT uploaded PBR texture sets or physics geometry.
-- MapService remains sole owner of bullet/movement collision.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FreightSurfacePlan"))
local WorldPbr = require(script.Parent:WaitForChild("WorldPbrMaterials"))
local FreightSurfaceArt = {}

local COLORS = {
    graphite = Color3.fromRGB(47, 58, 60),
    iron = Color3.fromRGB(92, 103, 100),
    paleSteel = Color3.fromRGB(169, 174, 161),
    salt = Color3.fromRGB(184, 173, 153),
    amber = Color3.fromRGB(228, 180, 93),
    weatheredRust = Color3.fromRGB(117, 80, 66),
    repairedRoad = Color3.fromRGB(82, 88, 86),
    aggregate = Color3.fromRGB(144, 141, 126),
}

local function skin(folder, name, size, cf, color, material, tier, transparency)
    local p = Instance.new("Part")
    p.Name = "SURFACE / " .. name
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.Metal
    p.Transparency = transparency or 0
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p:SetAttribute("NeonArtTier", tier)
    if string.find(name, "yard asphalt patch ", 1, true) == 1 then
        WorldPbr.apply(p, "yard_asphalt")
    end
    p.Parent = folder
    return p
end

local function containerFinish(folder, item)
    local x, z, h = item.x, item.z, item.height
    local color = item.variant % 2 == 0 and COLORS.amber or COLORS.paleSteel

    -- A coherent large side stripe and lower oxide patina ground each
    -- 24x22 freight body. Sides are outside the collider face but remain
    -- physically untouchable and are independently distance-culled.
    for _, side in ipairs({ -1, 1 }) do
        local faceX = x + side * 12.22
        skin(folder, "freight painted stripe " .. item.id .. ":" .. side,
            Vector3.new(0.075, 0.58, 19.1),
            CFrame.new(faceX, h * 0.64, z),
            color, Enum.Material.SmoothPlastic, "Core", 0.16)
        skin(folder, "freight lower oxidation " .. item.id .. ":" .. side,
            Vector3.new(0.036, 3.1, 6.5),
            CFrame.new(x + side * 12.26, 2.62,
                z + (side * (item.variant % 2 == 0 and 3.4 or -3.4))),
            COLORS.weatheredRust, Enum.Material.SmoothPlastic, "Detail", 0.52)
        for _, endSide in ipairs({ -1, 1 }) do
            -- ISO-style corner castings remain within the base collider
            -- footprint: their shape is never additional mantle cover.
            for _, elevation in ipairs({ 0.45, h - 0.45 }) do
                skin(folder, "freight corner casting " .. item.id .. ":"
                    .. side .. ":" .. endSide .. ":" .. elevation,
                    Vector3.new(0.50, 0.72, 0.62),
                    CFrame.new(x + side * 11.97, elevation, z + endSide * 10.75),
                    COLORS.graphite, Enum.Material.Metal, "Core", 0)
            end
        end
    end

    -- The roofs are often viewed from catwalks. These raised low-profile
    -- service strips give the top face visible material scale without
    -- adding any new walkable height or physics collision.
    for _, side in ipairs({ -1, 1 }) do
        skin(folder, "freight roof service runner " .. item.id .. ":" .. side,
            Vector3.new(1.8, 0.065, 18.4),
            CFrame.new(x + side * 7.5, h + 0.042, z),
            COLORS.iron, Enum.Material.DiamondPlate, "Detail", 0.10)
    end
    -- Door-end markings supplement existing rods and serial plates.
    for _, endSide in ipairs({ -1, 1 }) do
        skin(folder, "freight end safety marker " .. item.id .. ":" .. endSide,
            Vector3.new(3.5, 0.30, 0.06),
            CFrame.new(x - 7.4, 1.63, z + endSide * 11.34),
            COLORS.amber, Enum.Material.SmoothPlastic, "Detail", 0.12)
    end
end

local function yardRepairs(folder)
    -- A dozen large-scale asphalt repairs, each with one seam; ~24 total
    -- non-queryable parts and no decals, textures, or update loops.
    for index, info in ipairs(Plan.repairs()) do
        local cf = CFrame.new(info.x, 0.024, info.z)
            * CFrame.Angles(0, info.rotation, 0)
        skin(folder, "yard asphalt patch " .. index,
            Vector3.new(info.width, 0.015, info.length),
            cf, COLORS.repairedRoad, Enum.Material.Concrete, "Detail", 0.25)
        skin(folder, "yard repaired seam " .. index,
            Vector3.new(info.width - 0.55, 0.015, 0.14),
            cf * CFrame.new(0, 0.009, -info.length * 0.40),
            COLORS.aggregate, Enum.Material.Concrete, "Detail", 0.32)
    end
end

function FreightSurfaceArt.decorate(decor)
    for _, item in ipairs(Plan.containers()) do
        containerFinish(decor, item)
    end
    yardRepairs(decor)
end

return FreightSurfaceArt
