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
