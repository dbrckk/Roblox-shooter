-- IRON YARD / authored freight warehouse material layers, not gameplay walls.
-- Core colliders, mantle surfaces, pathfinding, and bullet raycasts remain
-- owned by MapService. No SurfaceAppearance/asset IDs are claimed here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WarehouseCladdingPlan"))
local Cladding = {}

local P = {
    steel = Color3.fromRGB(113, 124, 122),
    zinc = Color3.fromRGB(147, 148, 139),
    graphite = Color3.fromRGB(59, 71, 73),
    patina = Color3.fromRGB(123, 101, 81),
    rust = Color3.fromRGB(155, 99, 74),
    amber = Color3.fromRGB(224, 169, 75),
    cream = Color3.fromRGB(234, 225, 198),
}

local function panel(folder, name, size, cf, color, material, tier)
    local p = Instance.new("Part")
    p.Name = "CLADDING / " .. name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = material or Enum.Material.Metal
    p.Color = color or P.steel
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Size = size
    p.CFrame = cf
    p:SetAttribute("NeonArtTier", tier or "Detail")
    p.Parent = folder
    return p
end

local function sideWalls(folder)
    for _, bay in ipairs(Plan.sidePanels()) do
        local id = tostring(bay.side) .. ":" .. tostring(bay.bay)
        local face = bay.x - bay.side * 0.15
        local finish = bay.bay % 2 == 0 and P.steel or P.zinc

        -- Large stamped sheets communicate their scale even when Detail
        -- tier is hidden on low-end phones.
        panel(folder, "interior steel sheet " .. id,
            Vector3.new(0.13, bay.height, bay.length),
            CFrame.new(bay.x, bay.y, bay.z),
            finish, Enum.Material.Metal, "Core")
        for _, y in ipairs({ 5.1, 10.1, 14.2 }) do
            panel(folder, "pressed fold " .. id .. ":" .. y,
                Vector3.new(0.18, 0.15, bay.length - 0.50),
                CFrame.new(face, y, bay.z),
                P.graphite, Enum.Material.Metal, "Detail")
        end
        -- Patina is restrained so opponents still contrast with the wall.
        local abrasion = panel(folder, "weathered base " .. id,
            Vector3.new(0.045, 2.0, 6.3),
            CFrame.new(face - bay.side * 0.08, 2.9,
                bay.z + (bay.bay % 2 == 0 and 3.0 or -3.0)),
            bay.bay % 2 == 0 and P.patina or P.rust,
            Enum.Material.SmoothPlastic, "Detail")
        abrasion.Transparency = 0.61
        for _, edge in ipairs({ -1, 1 }) do
            panel(folder, "rivet head " .. id .. ":" .. edge,
                Vector3.new(0.22, 0.22, 0.22),
                CFrame.new(face - bay.side * 0.12, 12.5, bay.z + edge * 7.2),
                P.graphite, Enum.Material.Metal, "Detail")
        end
    end

    -- Existing side wall extents: x=+/-30, thickness=3, z=-25..47.
    for _, side in ipairs({ -1, 1 }) do
        local x = side * (Plan.INNER_FACE_X - 0.34)
        for frame = 0, 4 do
            panel(folder, "inner wall upright " .. side .. ":" .. frame,
                Vector3.new(0.30, 14.5, 0.37),
                CFrame.new(x, 8.35, -25 + frame * 18),
                P.graphite, Enum.Material.Metal, "Core")
        end
        panel(folder, "steel base kickplate " .. side,
            Vector3.new(0.21, 1.03, 70.5), CFrame.new(x, 0.66, 11),
            P.graphite, Enum.Material.Metal, "Core")
        panel(folder, "roof bearing stringer " .. side,
            Vector3.new(0.27, 0.42, 71.6), CFrame.new(x, 15.5, 11),
            P.graphite, Enum.Material.Metal, "Core")
    end
end

local function serialPlate(folder, bay)
    local plate = panel(folder, "sealed berth badge " .. bay.bay,
        Vector3.new(5.3, 1.45, 0.12),
        CFrame.new(bay.x, 13.2, bay.z - 0.24),
        P.cream, Enum.Material.Metal, "Core")
    local surface = Instance.new("SurfaceGui")
    surface.Name = "WarehouseBerthSerial"
    surface.Face = Enum.NormalId.Front
    surface.CanvasSize = Vector2.new(380, 105)
    surface.LightInfluence = 0.3
    surface.Parent = plate
    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextScaled = true
    text.TextColor3 = P.graphite
    text.Text = string.format("BAY %02d / SEALED", bay.bay)
    text.Parent = surface
end

local function bulkhead(folder)
    -- North bulkhead is solid at z=61, near combat-facing surface z=59.5.
    -- These plated bays are visibly sealed, never fake passages.
    for _, bay in ipairs(Plan.bulkheadPanels()) do
        local finish = bay.bay == 2 and P.steel or P.zinc
        panel(folder, "bulkhead pressed plate " .. bay.bay,
            Vector3.new(bay.length, bay.height, 0.14),
            CFrame.new(bay.x, bay.y, bay.z),
            finish, Enum.Material.Metal, "Core")
        for _, y in ipairs({ 4.4, 8.4, 11.8 }) do
            panel(folder, "bulkhead fold " .. bay.bay .. ":" .. y,
                Vector3.new(bay.length - 0.6, 0.18, 0.15),
                CFrame.new(bay.x, y, bay.z - 0.15),
                P.graphite, Enum.Material.Metal, "Detail")
        end
        for _, edge in ipairs({ -1, 1 }) do
            panel(folder, "berth vertical seam " .. bay.bay .. ":" .. edge,
                Vector3.new(0.36, bay.height + 0.4, 0.21),
                CFrame.new(bay.x + edge * 9.30, bay.y, bay.z - 0.15),
                P.graphite, Enum.Material.Metal, "Core")
        end
        panel(folder, "berth hazard band " .. bay.bay,
            Vector3.new(bay.length - 1.0, 0.43, 0.13),
            CFrame.new(bay.x, 2.0, bay.z - 0.18),
            P.amber, Enum.Material.SmoothPlastic, "Detail")
        serialPlate(folder, bay)
    end
end

function Cladding.decorate(decor)
    -- The supplied folder is the existing visual-LOD-managed arena decor.
    sideWalls(decor)
    bulkhead(decor)
end

return Cladding
