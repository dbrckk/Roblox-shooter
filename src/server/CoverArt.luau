-- IRON YARD / collision-independent high-fidelity freight cover panels.
-- MapService owns all cover collision and bullet hits. These are visual-only.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Plan = require(Shared:WaitForChild("CoverSurfacePlan"))
local WorldPbr = require(script.Parent:WaitForChild("WorldPbrMaterials"))
local CoverArt = {}

local PALETTES = {
    CAST_CONCRETE = {
        body = Color3.fromRGB(169, 166, 154), inset = Color3.fromRGB(143, 145, 137),
        metal = Color3.fromRGB(96, 102, 99), warning = Color3.fromRGB(220, 171, 77),
        material = Enum.Material.Concrete,
    },
    ARMED_ROADBLOCK = {
        body = Color3.fromRGB(105, 117, 112), inset = Color3.fromRGB(71, 80, 77),
        metal = Color3.fromRGB(54, 66, 67), warning = Color3.fromRGB(236, 174, 69),
        material = Enum.Material.Metal,
    },
    CARGO_BARRIER = {
        body = Color3.fromRGB(122, 132, 104), inset = Color3.fromRGB(83, 99, 82),
        metal = Color3.fromRGB(63, 70, 70), warning = Color3.fromRGB(225, 179, 78),
        material = Enum.Material.Metal,
    },
}

local function panel(folder, collider, suffix, placement, size, color, material, tier)
    local part = Instance.new("Part")
    part.Name = collider.Name .. " / " .. suffix
    part.Anchored = true
    part.Size = size
    part.CFrame = collider.CFrame * placement
    part.Color = color
    part.Material = material
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part:SetAttribute("NeonArtTier", tier)
    part.Parent = folder
    return part
end

local function stencil(plate, message)
    -- One short freight code on the forward face of important covers.
    -- No global BillboardGui, replicated updates or touch interactions.
    local surface = Instance.new("SurfaceGui")
    surface.Name = "CoverFreightIdentification"
    surface.Face = Enum.NormalId.Front
    surface.CanvasSize = Vector2.new(430, 120)
    surface.LightInfluence = 0.3
    surface.MaxDistance = 85
    surface.Parent = plate

    local label = Instance.new("TextLabel")
    label.Name = "CargoCode"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(47, 55, 53)
    label.Text = message
    label.Parent = surface
end

local function dress(folder, collider, plan)
    local paint = PALETTES[plan.style]
    local x, y, z = plan.length, plan.height, plan.width
    local frames = {
        Front = CFrame.new(0, 0, -z * 0.5),
        Back = CFrame.new(0, 0, z * 0.5) * CFrame.Angles(0, math.pi, 0),
        Left = CFrame.new(-x * 0.5, 0, 0) * CFrame.Angles(0, math.pi * 0.5, 0),
        Right = CFrame.new(x * 0.5, 0, 0) * CFrame.Angles(0, -math.pi * 0.5, 0),
        Top = CFrame.new(0, y * 0.5, 0) * CFrame.Angles(math.pi * 0.5, 0, 0),
    }
    local finishes = {
        body = { paint.body, paint.material },
        inset = { paint.inset, paint.material },
        metal = { paint.metal, Enum.Material.Metal },
        warning = { paint.warning, Enum.Material.SmoothPlastic },
        strike = { paint.metal, Enum.Material.DiamondPlate },
        label = { Color3.fromRGB(234, 227, 198), Enum.Material.SmoothPlastic },
    }
    for _, piece in ipairs(Plan.panels(plan)) do
        if not Plan.withinFace(plan, piece) then continue end
        local finish = finishes[piece.finish]
        local placement = frames[piece.face] * CFrame.new(piece.u, piece.v, -piece.depth)
            * CFrame.Angles(0, 0, piece.roll)
        local part = panel(folder, collider, piece.face .. " " .. piece.name, placement,
            Vector3.new(piece.w, piece.h, piece.thickness), finish[1], finish[2], piece.tier)
        if piece.finish == "body" and finish[2] == Enum.Material.Metal then
            WorldPbr.apply(part, "warehouse_steel")
        end
        if piece.serial then stencil(part, piece.serial) end
    end
end

function CoverArt.build(arena)
    local old = arena:FindFirstChild("IronYardCoverSkins")
    if old then old:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "IronYardCoverSkins"
    folder.Parent = arena
    -- Only direct gameplay colliders. Never decorate the art recursively.
    for _, item in ipairs(arena:GetChildren()) do
        if item:IsA("BasePart") then
            local size = item.Size
            local plan = Plan.forCollider(item.Name, size.X, size.Y, size.Z)
            if plan then dress(folder, item, plan) end
        end
    end
end

return CoverArt
