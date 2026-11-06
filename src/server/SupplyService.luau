-- IRON YARD: server-owned medical stations, using native mobile ProximityPrompt.
-- Every visual is non-collidable, non-queryable and cannot block projectiles.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(shared:WaitForChild("SupplyRules"))
local remotes = require(shared:WaitForChild("PrecisionNet")).getRemotes(true)
local Service = {}
local stations = {}
local started = false

local COLOR = {
    dark = Color3.fromRGB(39, 52, 51),
    shell = Color3.fromRGB(92, 107, 101),
    gold = Color3.fromRGB(220, 168, 82),
    white = Color3.fromRGB(237, 239, 224),
    green = Color3.fromRGB(123, 212, 155),
    off = Color3.fromRGB(98, 122, 114),
}
local function block(parent, name, size, cf, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Material = material or Enum.Material.Metal
    p.Color = color
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p:SetAttribute("NeonArtTier", "Core")
    p.Parent = parent
    return p
end

local function create(parent, index, x, z)
    local model = Instance.new("Model")
    model.Name = "MEDICAL STATION / " .. index
    model.Parent = parent
    local base = CFrame.new(x, 0, z)
    block(model, "Mount", Vector3.new(4.6, 0.22, 3.3),
        base * CFrame.new(0, 0.12, 0), COLOR.dark)
    block(model, "Case", Vector3.new(3.5, 1.6, 2.4),
        base * CFrame.new(0, 1.02, 0), COLOR.shell)
    local console = block(model, "Console", Vector3.new(3.1, 0.9, 2.1),
        base * CFrame.new(0, 2.19, 0), COLOR.dark)
    for _, side in ipairs({-1, 1}) do
        block(model, "Safety rail", Vector3.new(0.22, 2.2, 2.6),
            base * CFrame.new(side * 1.88, 1.38, 0), COLOR.gold)
    end
    block(model, "Medical cross vertical", Vector3.new(0.25, 0.76, 0.13),
        base * CFrame.new(0, 2.18, -1.12), COLOR.white, Enum.Material.SmoothPlastic)
    block(model, "Medical cross horizontal", Vector3.new(0.76, 0.25, 0.14),
        base * CFrame.new(0, 2.18, -1.13), COLOR.white, Enum.Material.SmoothPlastic)
    local light = block(model, "Supply indicator", Vector3.new(0.85, 0.18, 0.12),
        base * CFrame.new(0, 2.68, -1.12), COLOR.green, Enum.Material.Neon)

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "Heal"
    prompt.ActionText = "RECOVER +" .. Rules.HEAL_AMOUNT .. " HP"
    prompt.ObjectText = "FIELD MEDICAL"
    prompt.HoldDuration = 0.4
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = true
    prompt.Parent = console

    local sign = Instance.new("BillboardGui")
    sign.Name = "MedicalSign"
    sign.Adornee = console
    sign.Size = UDim2.fromOffset(190, 46)
    sign.StudsOffsetWorldSpace = Vector3.new(0, 2.9, 0)
    sign.MaxDistance = 80
    sign.Parent = console
    local label = Instance.new("TextLabel")
    label.Name = "Status"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = COLOR.dark
    label.BackgroundTransparency = 0.12
    label.BorderSizePixel = 0
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextWrapped = true
    label.Parent = sign
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    local audio = Instance.new("Sound")
    audio.Name = "MedicalSound"
    audio.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    audio.RollOffMaxDistance = 48
    audio.Volume = 0.36
    audio.Parent = console

    local station = { model = model, console = console, readyAt = 0, revision = 0 }
    local function setReady(ready)
        prompt.Enabled = ready
        light.Color = ready and COLOR.green or COLOR.off
        label.TextColor3 = ready and COLOR.green or COLOR.white
        label.Text = ready and "MEDICAL  /  +40 HP\nREADY"
            or "MEDICAL  /  +40 HP\nRECHARGING"
        model:SetAttribute("IronYardMedicalReadyAt", station.readyAt)
    end
    station.reset = function()
        station.revision += 1
        station.readyAt = 0
        setReady(true)
    end
    station.reset()

    -- One non-yielding supply transaction is shared by humans and AI.
    -- A globally consumed station cannot be redeemed twice in one tick.
    station.use = function(character, humanoid, root, player)
        if not character or not character.Parent or not humanoid or not root
            or not humanoid:IsDescendantOf(character)
            or not root:IsDescendantOf(Workspace) then return false end
        local now = Workspace:GetServerTimeNow()
        local distance = (root.Position - console.Position).Magnitude
        if not Rules.canUse(Workspace:GetAttribute("NeonMatchPhase"),
            humanoid.Health, humanoid.MaxHealth, distance, now, station.readyAt) then
            return false
        end
        local health, amount = Rules.healedHealth(humanoid.Health, humanoid.MaxHealth)
        if amount <= 0 then return false end
        station.readyAt = now + Rules.COOLDOWN
        station.revision += 1
        local revision = station.revision
        setReady(false)
        humanoid.Health = health
        audio:Play()
        if player then
            remotes.WeaponFeedback:FireClient(player, { kind = "MedicalHeal", amount = amount })
        end
        task.delay(Rules.COOLDOWN, function()
            if station.revision ~= revision or not model.Parent then return end
            station.reset()
        end)
        return true
    end

    prompt.Triggered:Connect(function(player)
        if not player or not player:IsA("Player") or player.Parent ~= Players then return end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        station.use(character, humanoid, root, player)
    end)
    table.insert(stations, station)
end

-- Medical objectives for wounded NPCs use the SAME 40 HP / 24 s pool.
local BOT_SEARCH_RADIUS = 65
local BOT_USE_DISTANCE = 7.5
local function botState(character)
    if not character or not character.Parent
        or character:GetAttribute("IsArenaBot") ~= true then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or not root:IsDescendantOf(Workspace)
        or not Rules.botNeedsHeal(humanoid.Health, humanoid.MaxHealth) then
        return nil
    end
    return humanoid, root
end

function Service.botGoal(character)
    local humanoid, root = botState(character)
    if not humanoid or Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then
        return nil
    end
    local now = Workspace:GetServerTimeNow()
    local best, bestDistance = nil, BOT_SEARCH_RADIUS
    for _, station in ipairs(stations) do
        local console = station.console
        local distance = (root.Position - console.Position).Magnitude
        if station.readyAt <= now
            and math.abs(root.Position.Y - console.Position.Y - 1.2) <= 4
            and distance < bestDistance then
            best, bestDistance = console.Position, distance
        end
    end
    return best and Vector3.new(best.X, root.Position.Y, best.Z) or nil
end

function Service.tryHealBot(character)
    local humanoid, root = botState(character)
    if not humanoid or Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then
        return false
    end
    local now = Workspace:GetServerTimeNow()
    for _, station in ipairs(stations) do
        local console = station.console
        if station.readyAt <= now
            and (root.Position - console.Position).Magnitude <= BOT_USE_DISTANCE then
            -- Never allow AI to heal through physical cover.
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { character, station.model }
            params.RespectCanCollide = true
            params.IgnoreWater = true
            local origin = root.Position + Vector3.new(0, 0.2, 0)
            if not Workspace:Raycast(origin, console.Position - origin, params)
                and station.use(character, humanoid, root, nil) then
                return true
            end
        end
    end
    return false
end

function Service.resetRound()
    for _, station in ipairs(stations) do station.reset() end
end

function Service.start()
    if started then return end
    started = true
    local folder = Instance.new("Folder")
    folder.Name = "IronYardMedicalStations"
    folder.Parent = Workspace
    for i, position in ipairs({
        Vector2.new(-48, -126), Vector2.new(48, -126),
        Vector2.new(-48, 126), Vector2.new(48, 126),
    }) do
        create(folder, i, position.X, position.Y)
    end
end
return Service
