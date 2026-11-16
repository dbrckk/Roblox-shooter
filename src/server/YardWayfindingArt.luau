-- IRON YARD / painted floor signage for the yard and transfer deck.
-- Never alter movement floor material, server raycasts, collision or AI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("YardWayfindingPlan"))
local Art = {}

local STEEL = Color3.fromRGB(48, 59, 62)
local AMBER = Color3.fromRGB(232, 185, 90)
local PAPER = Color3.fromRGB(248, 237, 211)

local ROUTE_PAINT = {
    RAMP = AMBER,
    UNDERPASS = Color3.fromRGB(150, 216, 224),
}

local function paint(folder, name, frame, size, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = frame
    part.Material = Enum.Material.SmoothPlastic
    part.Color = color
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part:SetAttribute("NeonArtTier", "Core")
    part.Parent = folder
    return part
end

local function stamp(folder, info)
    local part = paint(folder, "YARD / SECTOR " .. info.id .. " / lane stamp",
        CFrame.new(info.x, 0.018, info.z), Vector3.new(24, 0.016, 7), STEEL)
    part.Transparency = 0.07

    local surface = Instance.new("SurfaceGui")
    surface.Name = "YardSectorStamp"
    surface.Face = Enum.NormalId.Top
    surface.CanvasSize = Vector2.new(720, 210)
    surface.LightInfluence = 0.32
    surface.Parent = part

    local backing = Instance.new("Frame")
    backing.Size = UDim2.fromScale(1, 1)
    backing.BackgroundTransparency = 1
    backing.Parent = surface

    local marker = Instance.new("Frame")
    marker.BackgroundColor3 = AMBER
    marker.BorderSizePixel = 0
    marker.Position = UDim2.fromScale(0, 0.05)
    marker.Size = UDim2.fromScale(0.10, 0.90)
    marker.Parent = backing

    local label = Instance.new("TextLabel")
    label.Name = "SectorName"
    label.Size = UDim2.fromScale(0.87, 0.88)
    label.Position = UDim2.fromScale(0.12, 0.06)
    label.BackgroundTransparency = 1
    label.Text = "SECTOR " .. info.id .. "   " .. info.label
    label.TextColor3 = PAPER
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = backing
end

local function transferRoute(folder, route)
    local prefix = "TRANSFER / " .. route.id
    local color = ROUTE_PAINT[route.id]
    local base = paint(folder, prefix .. " / floor label", CFrame.new(route.x, 0.057, route.z),
        Vector3.new(9.2, 0.024, 3.8), STEEL)
    local surface = Instance.new("SurfaceGui")
    surface.Name = "TransferRouteStamp"
    surface.Face = Enum.NormalId.Top
    surface.CanvasSize = Vector2.new(460, 190)
    surface.LightInfluence = 0.32
    surface.MaxDistance = 76
    surface.Parent = base

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(0.92, 0.9)
    label.Position = UDim2.fromScale(0.04, 0.05)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = route.label
    label.TextColor3 = color
    label.TextScaled = true
    label.Parent = surface

    for index, arrow in ipairs(route.arrows) do
        local frame = CFrame.new(arrow.x, 0.061, arrow.z) * CFrame.Angles(0, arrow.yaw, 0)
        for _, side in ipairs({ -1, 1 }) do
            paint(folder, prefix .. " / chevron " .. index .. ":" .. side,
                frame * CFrame.new(side * 0.52, 0, 0)
                    * CFrame.Angles(0, side * math.rad(37), 0),
                Vector3.new(1.68, 0.025, 0.25), color)
        end
    end
end

function Art.decorate(folder)
    for _, info in ipairs(Plan.zones()) do
        stamp(folder, info)
    end
    for _, route in ipairs(Plan.transferRoutes()) do
        transferRoute(folder, route)
    end
end

return Art
