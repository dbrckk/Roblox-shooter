-- IRON YARD / full-size authored industrial deck and stair surfacing.
-- All locations use the actual MapService colliders, never a duplicated
-- coordinate list. No floor height, pathfinding, raycast or mantle changes.
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

local function dockLabel(plate, name)
    -- In-world floor stencil: no billboard clutter in the aiming view.
    local gui = Instance.new("SurfaceGui")
    gui.Name = "CatwalkBerthStencil"
    gui.Face = Enum.NormalId.Top
    gui.CanvasSize = Vector2.new(700, 180)
    gui.LightInfluence = 0.3
    gui.Parent = plate
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextColor3 = C.paper
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
        part(folder, "deck perimeter safety paint " .. plan.number .. ":" .. side,
            Vector3.new(62.7, 0.025, 0.37),
            origin * CFrame.new(0, halfH + 0.027, side * 24.75),
            C.yellow, Enum.Material.SmoothPlastic, "Core")
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

    local plate = part(folder, "deck orientation stencil " .. plan.number,
        Vector3.new(17.5, 0.04, 3.8),
        origin * CFrame.new(0, halfH + 0.049, -9),
        C.graphite, Enum.Material.SmoothPlastic, "Core")
    dockLabel(plate, plan.number == 1 and "WEST / LOADING 01" or "EAST / LOADING 02")
end

local function surfaceStep(folder, collider, plan)
    local top = collider.Size.Y * 0.5
    -- An exactly collider-matched walking surface, never a second step.
    part(folder, "stair diamondplate " .. plan.side .. ":" .. plan.step,
        Vector3.new(17.2, 0.016, 4.50),
        collider.CFrame * CFrame.new(0, top + 0.008, 0),
        C.steel, Enum.Material.DiamondPlate, "Core")
    part(folder, "stair warning nose " .. plan.side .. ":" .. plan.step,
        Vector3.new(17.0, 0.02, 0.30),
        collider.CFrame * CFrame.new(0, top + 0.025, -2.22),
        C.yellow, Enum.Material.SmoothPlastic, "Core")
end

function Art.decorate(decor, arena)
    local decks = 0
    local steps = 0
    for _, collider in ipairs(arena:GetChildren()) do
        if collider:IsA("BasePart") then
            local plan = Plan.forCollider(collider.Name,
                collider.Size.X, collider.Size.Y, collider.Size.Z)
            if plan then
                if plan.kind == "DECK" then
                    surfaceDeck(decor, collider, plan)
                    decks += 1
                else
                    surfaceStep(decor, collider, plan)
                    steps += 1
                end
            end
        end
    end
    if decks ~= 2 or steps ~= 10 then
        warn("[IRON YARD] Catwalk visual inventory incomplete: "
            .. tostring(decks) .. " decks, " .. tostring(steps) .. " steps")
    end
end

return Art
