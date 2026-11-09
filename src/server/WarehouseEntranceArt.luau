-- IRON YARD / premium warehouse approach, using REAL MapService colliders.
-- Decoration is never treated as real cover or a traversable entrance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WarehouseEntrancePlan"))
local Entrance = {}

local C = {
    slate = Color3.fromRGB(48, 58, 61),
    steel = Color3.fromRGB(104, 118, 120),
    amber = Color3.fromRGB(231, 174, 79),
    paper = Color3.fromRGB(239, 229, 203),
    olive = Color3.fromRGB(115, 127, 107),
}

local function visual(folder, name, size, cf, color, material, tier, alpha)
    local p = Instance.new("Part")
    p.Name = "ENTRY / " .. name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.Metal
    p.Transparency = alpha or 0
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p:SetAttribute("NeonArtTier", tier or "Detail")
    p.Parent = folder
    return p
end

local function signOnFront(part, primary, secondary)
    local sign = Instance.new("SurfaceGui")
    sign.Name = "IronYardEntranceWayfinding"
    sign.Face = Enum.NormalId.Front
    sign.CanvasSize = Vector2.new(1024, 256)
    sign.LightInfluence = 0.12
    sign.Parent = part

    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = C.slate
    background.BorderSizePixel = 0
    background.Parent = sign

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromScale(0, 0.02)
    bar.Size = UDim2.fromScale(0.025, 0.96)
    bar.BackgroundColor3 = C.amber
    bar.BorderSizePixel = 0
    bar.Parent = background

    local title = Instance.new("TextLabel")
    title.Name = "TerminalName"
    title.Position = UDim2.fromScale(0.055, 0.07)
    title.Size = UDim2.fromScale(0.90, 0.48)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextScaled = true
    title.TextColor3 = C.paper
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = primary
    title.Parent = background

    local sub = Instance.new("TextLabel")
    sub.Name = "SectorDirection"
    sub.Position = UDim2.fromScale(0.058, 0.61)
    sub.Size = UDim2.fromScale(0.88, 0.31)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.GothamBold
    sub.TextScaled = true
    sub.TextColor3 = C.amber
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = secondary
    sub.Parent = background
end

local function describe(wall)
    return {
        name = wall.Name,
        x = wall.Position.X, y = wall.Position.Y, z = wall.Position.Z,
        sx = wall.Size.X, sy = wall.Size.Y, sz = wall.Size.Z,
        pitch = wall.Orientation.X, yaw = wall.Orientation.Y,
        roll = wall.Orientation.Z,
    }
end

function Entrance.decorate(decor, arena)
    local west = arena:FindFirstChild("WAREHOUSE / west wall")
    local east = arena:FindFirstChild("WAREHOUSE / east wall")
    local rear = arena:FindFirstChild("WAREHOUSE / north bulkhead")
    if not (west and east and rear
        and west:IsA("BasePart") and east:IsA("BasePart")
        and rear:IsA("BasePart")) then
        warn("[IRON YARD] Warehouse entrance requires three existing physical walls")
        return
    end
    local layout = Plan.layout(describe(west), describe(east), describe(rear))
    if not layout then
        warn("[IRON YARD] Warehouse collider geometry changed; entry art not applied")
        return
    end
    local x, z, y = layout.centerX, layout.frontZ, layout.eaveY
    local width = layout.openingWidth

    -- Large silhouette and readable central sign above the genuine OPEN
    -- entrance. These do not block bullets, players or robot navigation.
    visual(decor, "structural header", Vector3.new(width + 3, 1.35, 1.75),
        CFrame.new(x, y, z - 0.35), C.slate, Enum.Material.Metal, "Core")
    visual(decor, "overhanging weather hood", Vector3.new(width + 4, 0.42, 3.2),
        CFrame.new(x, y + 1.14, z - 1.15), C.olive, Enum.Material.Metal, "Core")
    visual(decor, "signal rule", Vector3.new(width - 3, 0.38, 0.16),
        CFrame.new(x, y - 1.0, z - 1.32), C.amber,
        Enum.Material.SmoothPlastic, "Core")
    for _, side in ipairs({ -1, 1 }) do
        local sx = side == -1 and layout.westX or layout.eastX
        visual(decor, "entry pier " .. tostring(side),
            Vector3.new(1.18, 20.7, 2.0),
            CFrame.new(sx, 10.35, z - 0.15),
            C.slate, Enum.Material.Metal, "Core")
        visual(decor, "vertical safety band " .. tostring(side),
            Vector3.new(0.26, 13.5, 0.22),
            CFrame.new(sx - side * 0.5, 8.5, z - 1.28),
            C.amber, Enum.Material.Metal, "Detail")
        visual(decor, "portal knee brace " .. tostring(side),
            Vector3.new(4.2, 0.48, 1.00),
            CFrame.new(sx - side * 2.0, y - 2.25, z - 0.45)
                * CFrame.Angles(0, 0, side * math.rad(-37)),
            C.steel, Enum.Material.Metal, "Detail")
    end

    local board = visual(decor, "terminal nameplate",
        Vector3.new(34, 3.0, 0.19),
        CFrame.new(x, y + 0.02, z - 1.31),
        C.slate, Enum.Material.Metal, "Core")
    signOnFront(board, "IRON YARD", "FREIGHT PROCESSING  /  TERMINAL 01")

    -- Three approach lanes highlight the open route for a first-time player
    -- without turning the decorations into new walkable/collidable geometry.
    for _, lane in ipairs(layout.lanes) do
        local id = lane.id
        local cx = lane.x
        visual(decor, "approach stripe " .. id,
            Vector3.new(0.40, 0.018, 16.4),
            CFrame.new(cx, 0.035, layout.approachZ),
            C.amber, Enum.Material.SmoothPlastic, "Detail", 0.12)
        for _, direction in ipairs({ -1, 1 }) do
            visual(decor, "directional chevron " .. id .. ":" .. direction,
                Vector3.new(0.50, 0.018, 5.0),
                CFrame.new(cx + direction * 1.55, 0.037, layout.approachZ + 5.1)
                    * CFrame.Angles(0, direction * math.rad(38), 0),
                C.paper, Enum.Material.SmoothPlastic, "Detail", 0.18)
        end
    end
end

return Entrance
