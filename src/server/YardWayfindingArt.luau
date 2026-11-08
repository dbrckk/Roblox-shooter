-- IRON YARD / four lightweight floor identity marks for navigation.
-- Never alter movement floor material, server raycasts, collision or AI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("YardWayfindingPlan"))
local Art = {}

local STEEL = Color3.fromRGB(48, 59, 62)
local AMBER = Color3.fromRGB(232, 185, 90)
local PAPER = Color3.fromRGB(248, 237, 211)

local function stamp(folder, info)
    -- Top surface of MapService's physical 356-stud floor is exactly y=0.
    local part = Instance.new("Part")
    part.Name = "YARD / SECTOR " .. info.id .. " / lane stamp"
    part.Size = Vector3.new(24, 0.016, 7)
    part.CFrame = CFrame.new(info.x, 0.018, info.z)
    part.Material = Enum.Material.SmoothPlastic
    part.Color = STEEL
    part.Transparency = 0.07
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    -- These are intentionally Core so the sector name is still readable
    -- on ECO mobile; only four geometry parts are used in the whole yard.
    part:SetAttribute("NeonArtTier", "Core")
    part.Parent = folder

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

function Art.decorate(folder)
    for _, info in ipairs(Plan.zones()) do
        stamp(folder, info)
    end
end

return Art
