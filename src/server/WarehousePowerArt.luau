-- IRON YARD / enclosed power converters fitted to the two warehouse covers.
local Art = {}

local palette = {
    graphite = Color3.fromRGB(46, 55, 56),
    gasket = Color3.fromRGB(30, 38, 41),
    slate = Color3.fromRGB(82, 104, 115),
    blue = Color3.fromRGB(112, 137, 147),
    nickel = Color3.fromRGB(160, 169, 162),
    amber = Color3.fromRGB(223, 156, 57),
    ivory = Color3.fromRGB(242, 230, 203),
}

local function piece(model, name, frame, x, y, z, w, h, d, finish, material, isDetail)
    local item = Instance.new("Part")
    item.Name = name
    item.Size = Vector3.new(w, h, d)
    item.CFrame = frame * CFrame.new(x, y, z)
    item.Color = palette[finish]
    item.Material = material or Enum.Material.Metal
    item.Anchored = true
    item.CanCollide = false
    item.CanTouch = false
    item.CanQuery = false
    item.CastShadow = false
    item.TopSurface = Enum.SurfaceType.Smooth
    item.BottomSurface = Enum.SurfaceType.Smooth
    item:SetAttribute("NeonArtTier", isDetail and "Detail" or "Core")
    item.Parent = model
    return item
end

local function sign(item, message, face)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "Power converter identifier"
    gui.Face = face
    gui.CanvasSize = Vector2.new(600, 120)
    gui.LightInfluence = 0.45
    gui.MaxDistance = 70
    local label = Instance.new("TextLabel")
    label.Text = message
    label.TextColor3 = palette.ivory
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Parent = gui
    gui.Parent = item
end

function Art.build(folder, collider, side)
    local model = Instance.new("Model")
    local sector = side == -1 and "WEST" or "EAST"
    model.Name = "POWER CONVERTER / " .. sector
    model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    -- Turn the asset so the door face is on the main approach to the warehouse.
    local origin = collider.CFrame * CFrame.Angles(0, math.pi, 0)
    piece(model, "Steel enclosure", origin, 0, -0.04, 0, 8.96, 3.54, 11.96, "slate")
    piece(model, "Reinforced plinth", origin, 0, -1.94, 0, 9, 0.42, 12, "graphite").CastShadow = true
    piece(model, "Roof rim", origin, 0, 1.94, 0, 9, 0.378, 12, "graphite").CastShadow = true
    piece(model, "Textured roof deck", origin, 0, 2.132, 0,
        8.15, 0.034, 11.2, "graphite", Enum.Material.DiamondPlate)
    for _, x in ipairs({ -3.95, 3.95 }) do
        piece(model, "Roof caution stripe", origin, x, 2.145, 0,
            0.18, 0.01, 10.3, "amber", Enum.Material.SmoothPlastic)
    end

    for _, direction in ipairs({ -1, 1 }) do
        local front = direction == -1
        local frame = origin * CFrame.new(0, 0, direction * 6)
            * CFrame.Angles(0, front and 0 or math.pi, 0)
        piece(model, "Face perimeter frame", frame, 0, -0.12, -0.015, 8.68, 3.16, 0.065, "gasket")
        for _, x in ipairs({ -2.13, 2.13 }) do
            piece(model, front and "Control door" or "Service hatch", frame,
                x, -0.25, -0.055, 3.98, 2.69, 0.067, front and "blue" or "slate")
            if not front then
                piece(model, "Rear latch seam", frame, x, -0.36, -0.095, 3.28, 0.11, 0.022, "gasket")
            end
            local edge = x * 0.49
            piece(model, "Handle recess", frame, edge, -0.46, -0.092, 0.32, 0.84, 0.026, "gasket")
            piece(model, "Recessed nickel pull", frame, edge, -0.46, -0.118,
                0.096, 0.57, 0.033, "nickel", nil, true)
            local hinge = x * 1.76
            for _, height in ipairs({ -1.27, 0.64 }) do
                piece(model, "Steel hinge", frame, hinge, height, -0.112,
                    0.16, 0.31, 0.04, "nickel", nil, true)
            end
            if front and x < 0 then
                local label = piece(model, "Power bay serial", frame, x, 0.59, -0.095,
                    2.45, 0.41, 0.04, "graphite")
                sign(label, sector .. " / POWER", Enum.NormalId.Front)
            end
        end
        piece(model, "Amber service stripe", frame, 0, -1.37, -0.095,
            7.65, 0.16, 0.024, "amber", Enum.Material.SmoothPlastic)
    end

    for _, flank in ipairs({ -1, 1 }) do
        local frame = origin * CFrame.new(flank * 4.5, 0, 0) * CFrame.Angles(0, -flank * math.pi / 2, 0)
        piece(model, "Heat exchanger frame", frame, 0, 0.21, -0.021, 11.48, 2.50, 0.072, "graphite")
        for _, bank in ipairs({ -1, 0, 1 }) do
            local x = bank * 3.6
            piece(model, "Radiator bank", frame, x, 0.22, -0.074, 3.33, 1.97, 0.045, "gasket")
            for fin = -2, 2 do
                piece(model, "Silver cooling fin", frame, x + fin * 0.49, 0.22, -0.105,
                    0.19, 1.62, 0.037, "nickel")
            end
        end
        piece(model, "Painted lower sill", frame, 0, -1.28, -0.05, 10.98, 0.39, 0.04, "blue")
    end

    model.Parent = folder
    collider.Transparency = 1
    collider.CastShadow = false
end

return Art
