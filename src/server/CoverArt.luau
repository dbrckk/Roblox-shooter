-- IRON YARD / collision-independent high-fidelity freight cover panels.
-- MapService owns all cover collision and bullet hits. These are visual-only.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Plan = require(Shared:WaitForChild("CoverSurfacePlan"))
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

local function panel(folder, collider, suffix, offset, size, color, material, tier, spin)
    local part = Instance.new("Part")
    part.Name = collider.Name .. " / " .. suffix
    part.Anchored = true
    part.Size = size
    part.CFrame = collider.CFrame * CFrame.new(offset)
        * (spin and CFrame.Angles(0, 0, spin) or CFrame.new())
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
    for _, side in ipairs({ -1, 1 }) do
        local face = side * plan.surfaceOffset
        panel(folder, collider, "pressed armor " .. side,
            Vector3.new(0, 0, face),
            Vector3.new(plan.faceLength, plan.faceHeight, 0.075),
            paint.body, paint.material, "Core")
        panel(folder, collider, "inset stamping " .. side,
            Vector3.new(0, 0.04, face + side * 0.044),
            Vector3.new(x * 0.58, y * 0.57, 0.046),
            paint.inset, paint.material, "Detail")
        panel(folder, collider, "toe flange " .. side,
            Vector3.new(0, -y * 0.38, face + side * 0.09),
            Vector3.new(x - 0.5, 0.21, 0.11),
            paint.metal, Enum.Material.Metal, "Detail")
        for _, endSide in ipairs({ -1, 1 }) do
            panel(folder, collider, "upright " .. side .. ":" .. endSide,
                Vector3.new(endSide * (x * 0.5 - 0.26), 0, face + side * 0.09),
                Vector3.new(0.3, y * 0.77, 0.16),
                paint.metal, Enum.Material.Metal, "Core")
        end
        -- Style-specific surface language, always attached to a real solid
        -- cover. These overlays are invisible to physical and weapon rays.
        if plan.style == "CAST_CONCRETE" then
            panel(folder, collider, "cast expansion seam " .. side,
                Vector3.new(x * 0.21, 0, face + side * 0.13),
                Vector3.new(0.14, y * 0.72, 0.06),
                paint.inset, Enum.Material.Concrete, "Detail")
        elseif plan.style == "ARMED_ROADBLOCK" then
            panel(folder, collider, "diamondplate strike shield " .. side,
                Vector3.new(0, y * 0.12, face + side * 0.13),
                Vector3.new(x * 0.52, y * 0.38, 0.085),
                paint.metal, Enum.Material.DiamondPlate, "Core")
        elseif plan.style == "CARGO_BARRIER" then
            for rib = 1, 3 do
                panel(folder, collider, "cargo shutter rib " .. side .. ":" .. rib,
                    Vector3.new(0, (rib - 2) * y * 0.24, face + side * 0.12),
                    Vector3.new(x - 1.2, 0.16, 0.09),
                    paint.metal, Enum.Material.Metal, "Detail")
            end
        end
        -- Retain a strong two-color silhouette after distant cosmetic LOD.
        for i = 1, plan.stripeCount do
            local at = (i - (plan.stripeCount + 1) * 0.5)
                * (x - 2) / plan.stripeCount
            panel(folder, collider, "safety bar " .. side .. ":" .. i,
                Vector3.new(at, -y * 0.26, face + side * 0.11),
                Vector3.new(0.35, math.min(0.86, y * 0.25), 0.11),
                paint.warning, Enum.Material.SmoothPlastic, "Detail",
                (i % 2 == 0 and -0.28 or 0.28))
        end
    end
    panel(folder, collider, "cast top beam",
        Vector3.new(0, y * 0.5 - 0.055, 0),
        Vector3.new(x - 0.14, 0.19, z - 0.13),
        paint.metal, Enum.Material.Metal, "Core")

    -- Sixteen strategically placed identifiers across 32 actual covers:
    -- one per concrete freight cluster, selected roadblocks, and the three
    -- warehouse obstacles. Front faces -Z, independent of collider yaw.
    if plan.serial then
        local plate = panel(folder, collider, "freight serial plate",
            Vector3.new(x * 0.24, y * 0.31, -plan.surfaceOffset - 0.24),
            Vector3.new(math.min(5.0, x * 0.50), 0.86, 0.14),
            Color3.fromRGB(234, 227, 198), Enum.Material.Metal, "Core")
        stencil(plate, plan.serial)
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
