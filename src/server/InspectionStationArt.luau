-- IRON YARD / native freight inspection station fitted to the existing vault cover.
local Art = {}

local colors = {
    case = Color3.fromRGB(99, 108, 78),
    panel = Color3.fromRGB(120, 128, 94),
    darkerPanel = Color3.fromRGB(84, 93, 69),
    graphite = Color3.fromRGB(46, 53, 52),
    gasket = Color3.fromRGB(29, 37, 37),
    nickel = Color3.fromRGB(148, 153, 137),
    amber = Color3.fromRGB(229, 162, 53),
    rust = Color3.fromRGB(190, 65, 37),
    paper = Color3.fromRGB(230, 225, 203),
}

local function plate(parent, name, cf, w, h, d, color, material, tier, castsShadow)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = Vector3.new(w, h, d)
    part.CFrame = cf
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = castsShadow == true
    part.Color = colors[color]
    part.Material = material or Enum.Material.Metal
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part:SetAttribute("NeonArtTier", tier or "Core")
    part.Parent = parent
    return part
end

local function stencil(part, text, color)
    local sign = Instance.new("SurfaceGui")
    sign.Name = "Freight stencil"
    sign.Face = Enum.NormalId.Front
    sign.CanvasSize = Vector2.new(420, 110)
    sign.LightInfluence = 0.7
    sign.MaxDistance = 75
    sign.Parent = part
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextScaled = true
    label.TextColor3 = colors[color]
    label.Parent = sign
end

local function bolts(panel, x, y, w, h)
    for _, side in ipairs({ -1, 1 }) do
        for _, edge in ipairs({ -1, 1 }) do
            panel("Recessed fastener", x + side * w, y + edge * h, 0.13, 0.13, "nickel", 0.075, "Detail")
        end
    end
end

local function vents(panel, x, y, w, count)
    panel("Cooling grille", x, y, w + 0.25, count * 0.27 + 0.18, "gasket", 0.066)
    for slot = 1, count do
        panel("Cooling louver", x, y + (slot - (count + 1) / 2) * 0.27,
            w, 0.1, "graphite", 0.103)
    end
end

local function front(panel)
    panel("Left access skin", -5.0, -0.04, 3.43, 3.48, "darkerPanel")
    panel("Scanner face", 0.3, -0.04, 6.93, 3.48, "panel")
    panel("Operator service skin", 5.26, -0.04, 2.76, 3.48, "darkerPanel")
    bolts(panel, -5.0, -0.04, 1.49, 1.53)
    bolts(panel, 0.3, -0.04, 3.2, 1.53)
    vents(panel, -5, -0.06, 2.35, 3)
    panel("Indicator gasket", 0.95, 1.12, 4.8, 0.54, "gasket", 0.089)
    panel("Amber status strip", 0.95, 1.12, 4.42, 0.19, "amber", 0.12)
    local marker = panel("Inspection legend", 0.42, -0.43, 4.7, 0.73, "darkerPanel", 0.085)
    stencil(marker, "FREIGHT / 04", "amber")
    panel("Operator console", 5.18, -0.05, 2.57, 2.11, "gasket", 0.09)
    local display = panel("Operator display", 4.87, 0.12, 1.4, 1.07, "graphite", 0.115)
    stencil(display, "SCAN", "paper")
    panel("Control bezel", 6.02, -0.49, 0.42, 0.43, "amber", 0.127)
    panel("Emergency control", 6.02, -0.49, 0.26, 0.27, "rust", 0.15)
    for i = 0, 2 do
        panel("Selector key", 5.79 + i * 0.19, 0.46, 0.1, 0.14, "nickel", 0.125, "Detail")
    end
end

local function rear(panel)
    for i = 1, 2 do
        local x = -6.8 + i * 3.9
        panel("Service hatch seal " .. i, x, -0.02, 3.71, 3.14, "gasket")
        panel("Service hatch " .. i, x, -0.02, 3.49, 2.94, "graphite", 0.082)
        bolts(panel, x, -0.02, 1.54, 1.22)
        local id = panel("Service identification " .. i, x, 0.95, 1.83, 0.4, "graphite", 0.108)
        stencil(id, "S-0" .. i, "paper")
        panel("Recessed handle " .. i, x, -0.94, 0.96, 0.29, "gasket", 0.108)
        panel("Handle pull " .. i, x, -0.97, 0.74, 0.08, "nickel", 0.141)
        for _, h in ipairs({ -0.79, 0.78 }) do
            panel("Hinge " .. i, x - 1.59, h, 0.22, 0.49, "nickel", 0.13, "Detail")
        end
    end
    panel("Rear cooling bay", 4.9, -0.02, 3.43, 3.4, "darkerPanel")
    vents(panel, 4.9, 0.08, 2.75, 5)
end

local function flank(panel)
    panel("Lower side panel", 0, -0.97, 8.43, 1.47, "panel")
    panel("Louver housing", 0, 0.7, 7.17, 1.79, "darkerPanel")
    vents(panel, 0, 0.7, 6.49, 5)
    bolts(panel, 0, -0.97, 3.89, 0.47)
    for _, x in ipairs({ -3.88, 3.88 }) do
        panel("Side lamp gasket", x, 0.88, 0.38, 1.19, "gasket")
        panel("Side amber marker", x, 0.88, 0.19, 0.91, "amber", 0.102)
    end
end

function Art.decorate(decor, arena)
    local cover = arena:FindFirstChild("VAULT / packing station")
    if not cover or not cover:IsA("BasePart") or cover.Size ~= Vector3.new(14, 5, 9) then
        return
    end

    local model = Instance.new("Model")
    model.Name = "FREIGHT / Inspection station 04"
    model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    local origin = cover.CFrame
    plate(model, "Armored housing", origin * CFrame.new(0, 0.2, 0),
        13.96, 3.86, 8.96, "case", Enum.Material.Metal, "Core", true)
    plate(model, "Grounded steel plinth", origin * CFrame.new(0, -2.13, 0),
        14, 0.74, 9, "graphite", Enum.Material.Metal, "Core", true)
    plate(model, "Steel perimeter cap", origin * CFrame.new(0, 2.313, 0),
        14, 0.374, 9, "graphite", Enum.Material.Metal, "Core", true)
    plate(model, "Top deck inlay", origin * CFrame.new(0, 2.491, 0),
        12.98, 0.016, 7.98, "nickel", Enum.Material.DiamondPlate)

    for _, face in ipairs({
        { angle = math.pi, depth = 4.45, build = front },
        { angle = 0, depth = 4.45, build = rear },
        { angle = math.pi / 2, depth = 6.95, build = flank },
        { angle = -math.pi / 2, depth = 6.95, build = flank },
    }) do
        local faceFrame = origin * CFrame.Angles(0, face.angle, 0) * CFrame.new(0, 0, -face.depth)
        face.build(function(name, x, y, w, h, color, offset, tier)
            return plate(model, name, faceFrame * CFrame.new(-x, y, -(offset or 0.037)),
                w, h, 0.045, color, Enum.Material.Metal, tier)
        end)
    end

    -- Keep the original server hitbox, mantle target and raycast surface.
    -- Switch its display only when the complete authored shell is available.
    model.Parent = decor
    cover.Transparency = 1
    cover.CastShadow = false
end

return Art
