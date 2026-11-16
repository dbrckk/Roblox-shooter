-- IRON YARD / industrial decking and access route surfacing.
-- All locations use the actual MapService colliders, never a duplicated
-- coordinate list. MapService owns all physical route geometry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CatwalkDeckPlan"))
local Art = {}

local C = {
    steel = Color3.fromRGB(96, 110, 113),
    nickel = Color3.fromRGB(142, 154, 148),
    graphite = Color3.fromRGB(47, 59, 63),
    yellow = Color3.fromRGB(226, 177, 76),
    paper = Color3.fromRGB(236, 231, 209),
}

local function part(folder, name, size, cf, color, material, tier)
    local p = Instance.new("Part")
    p.Name = "CATWALK SURFACE / " .. name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = material or Enum.Material.Metal
    p.Color = color
    p.Size = size
    p.CFrame = cf
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p:SetAttribute("NeonArtTier", tier)
    p.Parent = folder
    return p
end

local function dockLabel(plate, name, face, distance)
    -- World-aligned signage, without a floating UI marker.
    local gui = Instance.new("SurfaceGui")
    gui.Name = "CatwalkBerthStencil"
    gui.Face = face or Enum.NormalId.Top
    gui.MaxDistance = distance or 90
    gui.CanvasSize = Vector2.new(700, 180)
    gui.LightInfluence = 0.3
    gui.Parent = plate
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextColor3 = C.paper
    label.TextStrokeColor3 = C.graphite
    label.TextStrokeTransparency = 0.5
    label.Text = name
    label.Parent = gui
end

local function surfaceDeck(folder, collider, plan)
    local origin = collider.CFrame
    local halfH = collider.Size.Y * 0.5

    -- Six large metal decking sheets on each 64x52 gameplay collider.
    -- Thin skin is intentionally non-queryable; it does not create a
    -- phantom height step, fake cover, or change the gameplay material.
    for index, offsetX in ipairs(Plan.deckStrips()) do
        part(folder, "diamondplate deck " .. plan.number .. ":" .. index,
            Vector3.new(9.30, 0.018, 49.25),
            origin * CFrame.new(offsetX, halfH + 0.008, 0),
            index % 2 == 0 and C.steel or C.nickel,
            Enum.Material.DiamondPlate, "Core")
    end

    -- Substantial fascia and riveted perimeter on the already-solid deck.
    -- Keep rails visually on top of the deck and preserve the existing
    -- hazard paint in ArenaArt.catwalkSafety.
    for _, side in ipairs({ -1, 1 }) do
        part(folder, "deck end girder " .. plan.number .. ":" .. side,
            Vector3.new(63.0, 0.77, 0.19),
            origin * CFrame.new(0, -0.83, side * 26.12),
            C.graphite, Enum.Material.Metal, "Core")
        part(folder, "deck flank girder " .. plan.number .. ":" .. side,
            Vector3.new(0.19, 0.77, 51.6),
            origin * CFrame.new(side * 32.12, -0.83, 0),
            C.graphite, Enum.Material.Metal, "Core")
        for index, segment in ipairs(Plan.deckEdgeSegments(plan.side, side, 31.35)) do
            part(folder, "deck perimeter safety paint " .. plan.number .. ":" .. side .. ":" .. index,
                Vector3.new(segment.width, 0.025, 0.37),
                origin * CFrame.new(segment.center, halfH + 0.027, side * 24.75),
                C.yellow, Enum.Material.SmoothPlastic, "Core")
        end
        part(folder, "deck lower beam " .. plan.number .. ":" .. side,
            Vector3.new(61, 0.24, 0.36),
            origin * CFrame.new(0, -1.57, side * 19),
            C.steel, Enum.Material.Metal, "Detail")
    end

    -- Deliberately few underside purlins: 6 added Detail parts, 0 loops
    -- and no new replicated DynamicLight or attachment per platform.
    for _, offsetX in ipairs({ -20, 0, 20 }) do
        part(folder, "deck underside stiffener " .. plan.number .. ":" .. offsetX,
            Vector3.new(0.35, 0.20, 50.8),
            origin * CFrame.new(offsetX, -1.56, 0),
            C.graphite, Enum.Material.Metal, "Detail")
    end

    local exit = part(folder, "deck ramp exit " .. plan.number,
        Vector3.new(8, 0.035, 2.65),
        origin * CFrame.new(Plan.ramp(plan.side).x - origin.Position.X, halfH + 0.049, 22.6)
            * CFrame.Angles(0, math.pi, 0),
        C.graphite, Enum.Material.SmoothPlastic, "Core")
    dockLabel(exit, "YARD RAMP", Enum.NormalId.Top, 55)

    local plate = part(folder, "deck orientation stencil " .. plan.number,
        Vector3.new(17.5, 0.04, 3.8),
        origin * CFrame.new(0, halfH + 0.049, -9),
        C.graphite, Enum.Material.SmoothPlastic, "Core")
    dockLabel(plate, plan.number == 1 and "WEST / LOADING 01" or "EAST / LOADING 02")
end

local function surfaceStep(folder, collider, plan)
    local top = collider.Size.Y * 0.5
    local key = plan.side .. ":" .. plan.step
    -- An exactly collider-matched walking surface, never a second step.
    part(folder, "stair diamondplate " .. key,
        Vector3.new(17.2, 0.016, 4.50),
        collider.CFrame * CFrame.new(0, top + 0.008, 0),
        C.steel, Enum.Material.DiamondPlate, "Core")
    part(folder, "stair warning nose " .. key,
        Vector3.new(17.0, 0.02, 0.30),
        collider.CFrame * CFrame.new(0, top + 0.025, -2.22),
        C.yellow, Enum.Material.SmoothPlastic, "Core")
    for _, edge in ipairs({ -1, 1 }) do
        part(folder, "tread edge " .. key .. ":" .. edge,
            Vector3.new(0.18, 0.018, 4.0),
            collider.CFrame * CFrame.new(edge * 8.3, top + 0.024, 0),
            C.yellow, Enum.Material.SmoothPlastic, "Core")
    end
    if plan.step == 5 then
        local root = collider.CFrame * CFrame.new(plan.side * 5.8, top + 0.039, 0)
        part(folder, "turn arrow shaft " .. key, Vector3.new(2.8, 0.012, 0.22),
            root, C.yellow, Enum.Material.SmoothPlastic, "Core")
        for _, side in ipairs({ -1, 1 }) do
            part(folder, "turn arrow head " .. key .. ":" .. side,
                Vector3.new(1.36, 0.012, 0.22),
                root * CFrame.new(plan.side * 1.06, 0.004, side * 0.40)
                    * CFrame.Angles(0, plan.side * side * math.rad(38), 0),
                C.yellow, Enum.Material.SmoothPlastic, "Core")
        end
    end
    if plan.step == 1 then
        local marker = part(folder, "stair access marker " .. plan.side,
            Vector3.new(10.8, 1.32, 0.025),
            collider.CFrame * CFrame.new(0, 0, -2.52),
            C.graphite, Enum.Material.SmoothPlastic, "Core")
        dockLabel(marker, plan.side == -1 and "WEST CATWALK  /  01" or "EAST CATWALK  /  02",
            Enum.NormalId.Front, 105)
    end
end

local function surfaceLanding(folder, collider, plan)
    local edge = collider.Size.X * 0.5
    local top = collider.Size.Y * 0.5
    part(folder, "landing diamondplate " .. plan.side, Vector3.new(4.7, 0.016, 4.7),
        collider.CFrame * CFrame.new(0, top + 0.009, 0),
        C.nickel, Enum.Material.DiamondPlate, "Core")
    part(folder, "landing warning edge " .. plan.side, Vector3.new(0.24, 0.018, 4.2),
        collider.CFrame * CFrame.new(-plan.side * (edge - 0.24), top + 0.025, 0),
        C.yellow, Enum.Material.SmoothPlastic, "Core")
end

local function surfaceRamp(folder, collider, plan)
    local size = collider.Size
    local top = size.Y / 2
    for _, side in ipairs({ -1, 1 }) do
        part(folder, "ramp edge paint " .. plan.side .. ":" .. side,
            Vector3.new(0.24, 0.02, size.Z - 0.55),
            collider.CFrame * CFrame.new(side * (size.X / 2 - 0.24), top + 0.018, 0),
            C.yellow, Enum.Material.SmoothPlastic, "Core")
    end

    local approach = collider.CFrame * CFrame.new(0, top + 0.025, size.Z / 2 - 5)
    local marker = part(folder, "ramp access marker " .. plan.side,
        Vector3.new(8, 0.03, 2.55), approach,
        C.graphite, Enum.Material.SmoothPlastic, "Core")
    dockLabel(marker, plan.side == -1 and "WEST CATWALK / 01" or "EAST CATWALK / 02",
        Enum.NormalId.Top, 64)

    for _, side in ipairs({ -1, 1 }) do
        part(folder, "ramp ascent chevron " .. plan.side .. ":" .. side,
            Vector3.new(1.62, 0.02, 0.22),
            approach * CFrame.new(side * 0.56, 0, -2.05)
                * CFrame.Angles(0, -side * math.rad(34), 0),
            C.yellow, Enum.Material.SmoothPlastic, "Core")
    end
end

function Art.decorate(decor, arena)
    local decks = 0
    local steps = 0
    local landings = 0
    local ramps = 0
    for _, collider in ipairs(arena:GetChildren()) do
        if collider:IsA("BasePart") then
            local plan = Plan.forCollider(collider.Name,
                collider.Size.X, collider.Size.Y, collider.Size.Z)
            if plan then
                if plan.kind == "DECK" then
                    surfaceDeck(decor, collider, plan)
                    decks += 1
                elseif plan.kind == "LANDING" then
                    surfaceLanding(decor, collider, plan)
                    landings += 1
                elseif plan.kind == "RAMP" then
                    surfaceRamp(decor, collider, plan)
                    ramps += 1
                else
                    surfaceStep(decor, collider, plan)
                    steps += 1
                end
            end
        end
    end
    if decks ~= 2 or steps ~= 10 or landings ~= 2 or ramps ~= 2 then
        warn("[IRON YARD] Catwalk visual inventory incomplete: "
            .. tostring(decks) .. " decks, " .. tostring(steps) .. " steps, "
            .. tostring(landings) .. " landings, " .. tostring(ramps) .. " ramps")
    end
end

return Art
