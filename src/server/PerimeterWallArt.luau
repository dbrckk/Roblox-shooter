-- IRON YARD / high-impact original perimeter-wall cladding.
-- Visual only. Reads the four real boundary colliders from MapService;
-- never adds bullet-blockers, movement surfaces or server light sources.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerimeterWallPlan"))
local PerimeterWallArt = {}

local COLORS = {
    graphite = Color3.fromRGB(44, 52, 54),
    steel = Color3.fromRGB(83, 97, 101),
    pale = Color3.fromRGB(172, 173, 160),
    amber = Color3.fromRGB(224, 170, 80),
    olive = Color3.fromRGB(116, 126, 104),
    rust = Color3.fromRGB(157, 101, 78),
}

local function plate(folder, wall, layout, name, along, height, depth, length, tall, thick, color, tier, material)
    -- Depth is measured inward from the actual collision wall's center.
    -- Positive depth means the artwork is visible FROM the playing field.
    local minor = layout.axis == "X" and wall.Size.X or wall.Size.Z
    local offset = layout.side * (minor / 2 + depth)
    local localPosition = layout.axis == "X"
        and Vector3.new(-offset, height, along)
        or Vector3.new(along, height, -offset)
    local size = layout.axis == "X"
        and Vector3.new(thick, tall, length)
        or Vector3.new(length, tall, thick)

    local part = Instance.new("Part")
    part.Name = "PERIMETER / " .. layout.label .. " / " .. name
    part.Size = size
    part.CFrame = wall.CFrame * CFrame.new(localPosition)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = material or Enum.Material.Metal
    part.Color = color
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part:SetAttribute("NeonArtTier", tier)
    part.Parent = folder
    return part
end

local function markSector(part, layout, index)
    -- Text is drawn on the field-facing surface, so the sign is
    -- readable from both Android and PC without lights or image IDs.
    local gui = Instance.new("SurfaceGui")
    gui.Name = "PerimeterSectorID"
    if layout.axis == "X" then
        gui.Face = layout.side > 0 and Enum.NormalId.Left or Enum.NormalId.Right
    else
        gui.Face = layout.side > 0 and Enum.NormalId.Front or Enum.NormalId.Back
    end
    gui.CanvasSize = Vector2.new(660, 220)
    gui.LightInfluence = 0.18
    gui.Parent = part

    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = COLORS.graphite
    backdrop.BorderSizePixel = 0
    backdrop.Parent = gui

    local strip = Instance.new("Frame")
    strip.Size = UDim2.fromScale(0.07, 1)
    strip.BorderSizePixel = 0
    strip.BackgroundColor3 = COLORS.amber
    strip.Parent = backdrop

    local lettering = Instance.new("TextLabel")
    lettering.Name = "Wayfinding"
    lettering.Position = UDim2.fromScale(0.1, 0.06)
    lettering.Size = UDim2.fromScale(0.86, 0.87)
    lettering.BackgroundTransparency = 1
    lettering.Font = Enum.Font.GothamBlack
    lettering.TextScaled = true
    lettering.Text = layout.label .. " / BAY " .. string.format("%02d", index)
    lettering.TextColor3 = Color3.fromRGB(245, 235, 215)
    lettering.Parent = backdrop
end

local function dressWall(decor, wall)
    if not wall:IsA("BasePart") then return end
    local size = wall.Size
    local layout = Plan.layout(wall.Name, size.X, size.Y, size.Z)
    if not layout then
        warn("[IRON YARD] Unexpected perimeter collider: " .. wall.Name .. "; leaving original geometry visible")
        return
    end

    -- One major plate for each 50-stud wall bay: large, visible native-metal
    -- surfaces even on ECO. Micro-details use the existing mobile LOD tiers.
    for _, panel in ipairs(layout.panels) do
        local key = string.format("bay %02d", panel.index)
        local primary = panel.index % 3 == 0 and COLORS.olive
            or (panel.index % 3 == 1 and COLORS.steel or COLORS.rust)
        plate(decor, wall, layout, key .. " / field steel", panel.along, 0,
            0.10, panel.width, 30, 0.13, primary, "Core", Enum.Material.Metal)
        plate(decor, wall, layout, key .. " / overhead girder", panel.along, 13.4,
            0.20, panel.width, 0.58, 0.19, COLORS.graphite, "Core")
        plate(decor, wall, layout, key .. " / safety plinth", panel.along, -12.2,
            0.22, panel.width, 0.85, 0.15, COLORS.amber, "Core")

        -- A large stamped vertical seam gives every panel a recognisable
        -- silhouette; two recessed vents on alternating bays read up close.
        plate(decor, wall, layout, key .. " / vertical frame", panel.along - 22.25, 0,
            0.26, 0.52, 30, 0.16, COLORS.graphite, "Detail")
        if panel.detail then
            for row = 1, 2 do
                plate(decor, wall, layout,
                    key .. " / maintenance louvre " .. row,
                    panel.along + 9, 8.8 + row * 1.15,
                    0.23, 16.5, 0.23, 0.14, COLORS.pale, "Detail")
            end
        end
        if panel.signal then
            local sign = plate(decor, wall, layout,
                key .. " / directional identity",
                panel.along - 4, -1.8, 0.33, 18, 4.3, 0.18,
                COLORS.graphite, "Core")
            markSector(sign, layout, panel.index)
        end
    end
end

function PerimeterWallArt.decorate(decor, arena)
    for _, name in ipairs({
        "BOUNDARY / east-west -1", "BOUNDARY / east-west 1",
        "BOUNDARY / north-south -1", "BOUNDARY / north-south 1",
    }) do
        local boundary = arena:FindFirstChild(name)
        if boundary then
            dressWall(decor, boundary)
        else
            warn("[IRON YARD] Missing physical perimeter wall: " .. name)
        end
    end
end

return PerimeterWallArt
