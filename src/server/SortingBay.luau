-- IRON YARD / sorting hall built on demand for a duel series.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DuelSpawnPlan"))
local WorldPbr = require(script.Parent:WaitForChild("WorldPbrMaterials"))

local SortingBay = {}
local model
local bay = Plan.SortingBay

local INK = Color3.fromRGB(49, 62, 65)
local STEEL = Color3.fromRGB(100, 125, 129)
local CONCRETE = Color3.fromRGB(168, 176, 164)
local AMBER = Color3.fromRGB(237, 177, 86)
local BLUE = Color3.fromRGB(112, 182, 195)
local WHITE = Color3.fromRGB(234, 242, 222)
local origin = Vector3.new(bay.originX, 0, 0)

function SortingBay.build()
    if model and model.Parent == Workspace then return end

    local hall = Instance.new("Model")
    hall.Name = "IRON YARD | Sorting Bay"
    hall.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

    local function part(name, size, offset, color, material, decoration)
        local block = Instance.new("Part")
        block.Name = name
        block.Anchored = true
        block.CanTouch = false
        block.CanCollide = not decoration
        block.CanQuery = not decoration
        block.CastShadow = not decoration
        block.Size = size
        block.Position = origin + offset
        block.Color = color
        block.Material = material
        block.Parent = hall
        return block
    end

    local width, depth, height = bay.halfWidth * 2, bay.halfDepth * 2, bay.height
    local floor = part("Sorting floor", Vector3.new(width + 4, 2, depth + 4),
        Vector3.new(0, -1, 0), CONCRETE, Enum.Material.Concrete)
    WorldPbr.apply(floor, "yard_asphalt")

    for _, side in ipairs({ -1, 1 }) do
        local color = side == 1 and AMBER or BLUE
        local wall = part("Service bulkhead", Vector3.new(2, height, depth),
            Vector3.new(side * bay.halfWidth, height / 2, 0), STEEL, Enum.Material.Metal)
        WorldPbr.apply(wall, "warehouse_steel")
        local endWall = part("Dispatch wall", Vector3.new(width + 2, height, 2),
            Vector3.new(0, height / 2, side * bay.halfDepth), STEEL, Enum.Material.Metal)
        WorldPbr.apply(endWall, "warehouse_steel")
        local shutter = part("Dispatch shutter", Vector3.new(24, 16, 0.18),
            Vector3.new(0, 8, side * (bay.halfDepth - 1.12)), INK, Enum.Material.Metal, true)
        WorldPbr.apply(shutter, "warehouse_steel")
        for index = 1, 8 do
            part("Shutter rib", Vector3.new(24, 0.12, 0.26),
                Vector3.new(0, index * 1.75, side * (bay.halfDepth - 1.22)), STEEL, Enum.Material.Metal, true)
        end

        local signPlate = part("Dock wayfinding", Vector3.new(27, 4.2, 0.28),
            Vector3.new(0, 19, side * (bay.halfDepth - 1.20)), INK, Enum.Material.Metal, true)
        local sign = Instance.new("SurfaceGui")
        sign.Face = side == 1 and Enum.NormalId.Front or Enum.NormalId.Back
        sign.CanvasSize = Vector2.new(540, 84)
        sign.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        sign.LightInfluence = 0.2
        sign.Parent = signPlate
        local title = Instance.new("TextLabel")
        title.Size = UDim2.fromScale(1, 1)
        title.BackgroundTransparency = 1
        title.Text = side == 1 and "SORTING BAY  /  SOUTH DISPATCH" or "SORTING BAY  /  NORTH INTAKE"
        title.Font = Enum.Font.GothamBold
        title.TextScaled = true
        title.TextColor3 = color
        title.Parent = sign

        -- Two long, open service routes read differently from the central cover.
        part("Service lane edge", Vector3.new(0.25, 0.05, depth - 12),
            Vector3.new(side * 39, 0.035, 0), color, Enum.Material.SmoothPlastic, true)
        part("Gate threshold", Vector3.new(28, 0.05, 0.5),
            Vector3.new(0, 0.04, side * 69), color, Enum.Material.SmoothPlastic, true)
        for _, z in ipairs({ -56, -28, 0, 28, 56 }) do
            part("Bulkhead column", Vector3.new(1.4, height, 2.4),
                Vector3.new(side * (bay.halfWidth - 1.6), height / 2, z), INK, Enum.Material.Metal, true)
        end

        local roof = part("Roof decking", Vector3.new(40, 1, depth + 2),
            Vector3.new(side * 36, height + 0.5, 0), STEEL, Enum.Material.Metal)
        WorldPbr.apply(roof, "warehouse_steel")
    end

    local skylight = part("Skylight", Vector3.new(32, 1, depth + 2),
        Vector3.new(0, height + 0.5, 0), WHITE, Enum.Material.Glass)
    skylight.Transparency = 0.50
    skylight.CastShadow = false

    for _, z in ipairs({ -58, -29, 0, 29, 58 }) do
        part("Roof truss", Vector3.new(width, 1.0, 1.3), Vector3.new(0, height - 1.3, z),
            INK, Enum.Material.Metal, true)
        local fixture = part("Sort line lighting", Vector3.new(33, 0.22, 0.65),
            Vector3.new(0, height - 2, z), WHITE, Enum.Material.Neon, true)
        local light = Instance.new("SurfaceLight")
        light.Face = Enum.NormalId.Bottom
        light.Angle = 115
        light.Range = 32
        light.Color = WHITE
        light.Brightness = 1.9
        light.Parent = fixture
    end

    for index, cover in ipairs(bay.covers) do
        local count = index == 1 and 1 or 2
        for mirror = 1, count do
            local side = mirror == 1 and 1 or -1
            local center = Vector3.new(cover.x * side, cover.h / 2, cover.z * side)
            local size = Vector3.new(cover.w, cover.h, cover.d)
            local tint = index == 1 and STEEL or (side == 1 and Color3.fromRGB(156, 112, 68)
                or Color3.fromRGB(76, 119, 138))
            local main = part(cover.name, size, center, tint, Enum.Material.Metal)
            main:SetAttribute("MantleTarget", true)
            WorldPbr.apply(main, cover.material)
            part("Folded steel cap", Vector3.new(cover.w + 0.16, 0.24, cover.d + 0.16),
                center + Vector3.new(0, cover.h / 2 - 0.13, 0), INK, Enum.Material.Metal, true)
            for _, face in ipairs({ -1, 1 }) do
                part("Handling stripe", Vector3.new(cover.w - 0.6, 0.22, 0.12),
                    center + Vector3.new(0, -cover.h * 0.22, face * (cover.d / 2 + 0.04)),
                    AMBER, Enum.Material.SmoothPlastic, true)
            end
        end
    end

    hall.Parent = Workspace
    model = hall
end

return SortingBay
