-- IRON YARD: server-owned medical stations, using native mobile ProximityPrompt.
-- Every visual is non-collidable, non-queryable and cannot block projectiles.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(shared:WaitForChild("SupplyRules"))
local Objective = require(shared:WaitForChild("BotMedicalObjective"))
local remotes = require(shared:WaitForChild("PrecisionNet")).getRemotes(true)
local Service = {}
local stations = {}
local started = false

local COLOR = {
    dark = Color3.fromRGB(39, 52, 51),
    shell = Color3.fromRGB(82, 123, 121),
    pale = Color3.fromRGB(158, 175, 167),
    amber = Color3.fromRGB(242, 190, 92),
    white = Color3.fromRGB(237, 239, 224),
    green = Color3.fromRGB(123, 212, 155),
    slate = Color3.fromRGB(168, 187, 193),
}
local STATUS = {
    READY = { text = "+" .. Rules.HEAL_AMOUNT .. " HP  /  READY", color = COLOR.green },
    RECHARGING = { text = "RECHARGING", color = COLOR.amber },
    STANDBY = { text = "OPENS IN MATCH", color = COLOR.slate },
    DUEL_CLOSED = { text = "CLOSED IN DUEL", color = COLOR.slate },
}

local function stationState(now, readyAt)
    return Rules.stationState(Workspace:GetAttribute("IronYardMatchMode"),
        Workspace:GetAttribute("NeonMatchPhase"), now, readyAt)
end

local function hasClearAccess(character, root, station)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character, station.model }
    params.RespectCanCollide = true
    params.IgnoreWater = true
    local origin = root.Position + Vector3.new(0, 0.2, 0)
    return not Workspace:Raycast(origin, station.console.Position - origin, params)
end

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
    block(model, "Anchored kickplate", Vector3.new(4.6, 0.24, 3.3),
        base * CFrame.new(0, 0.12, 0), COLOR.dark, Enum.Material.DiamondPlate)
    block(model, "Steel cabinet", Vector3.new(3.58, 1.72, 2.4),
        base * CFrame.new(0, 1.10, 0), COLOR.shell)
    local console = block(model, "Console", Vector3.new(3.25, 0.87, 2.1),
        base * CFrame.new(0, 2.19, 0), COLOR.dark)
    block(model, "Canopy", Vector3.new(4.02, 0.20, 2.72),
        base * CFrame.new(0, 2.86, 0), COLOR.dark)
    local signal = block(model, "Status band", Vector3.new(3.78, 0.18, 2.49),
        base * CFrame.new(0, 2.68, 0), COLOR.slate)
    for _, side in ipairs({ -1, 1 }) do
        block(model, "Corner brace " .. side, Vector3.new(0.28, 2.5, 2.5),
            base * CFrame.new(side * 1.86, 1.49, 0), COLOR.pale)
        block(model, "Hatch " .. side, Vector3.new(2.48, 1.55, 0.08),
            base * CFrame.new(0, 1.15, side * 1.24), COLOR.dark)
        block(model, "Cabinet pull " .. side, Vector3.new(0.83, 0.14, 0.10),
            base * CFrame.new(0, 1.64, side * 1.30), COLOR.pale)
        block(model, "Medical cross upright " .. side, Vector3.new(0.23, 0.72, 0.08),
            base * CFrame.new(0, 2.21, side * 1.105), COLOR.white, Enum.Material.SmoothPlastic)
        block(model, "Medical cross arm " .. side, Vector3.new(0.72, 0.23, 0.085),
            base * CFrame.new(0, 2.21, side * 1.108), COLOR.white, Enum.Material.SmoothPlastic)
        block(model, "Side case trim " .. side, Vector3.new(0.08, 0.15, 1.8),
            base * CFrame.new(side * 2.02, 1.16, 0), COLOR.white)
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "Heal"
    prompt.ActionText = "RECOVER +" .. Rules.HEAL_AMOUNT .. " HP"
    prompt.ObjectText = "FIELD MEDICAL"
    prompt.HoldDuration = 0.4
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = true
    prompt.Enabled = false
    prompt.Parent = console

    local sign = Instance.new("BillboardGui")
    sign.Name = "MedicalSign"
    sign.Adornee = console
    sign.Size = UDim2.fromOffset(154, 40)
    sign.StudsOffsetWorldSpace = Vector3.new(0, 1.55, 0)
    sign.MaxDistance = 64
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
    local function refresh()
        local state = stationState(Workspace:GetServerTimeNow(), station.readyAt)
        local status = STATUS[state]
        prompt.Enabled = state == "READY"
        signal.Color = status.color
        signal.Material = state == "READY" and Enum.Material.Neon or Enum.Material.SmoothPlastic
        label.TextColor3 = status.color
        label.Text = "MEDICAL " .. string.format("%02d", index) .. "\n" .. status.text
        model:SetAttribute("IronYardMedicalReadyAt", station.readyAt)
    end
    station.reset = function()
        station.revision += 1
        station.readyAt = 0
        refresh()
    end
    station.reset()
    Workspace:GetAttributeChangedSignal("IronYardMatchMode"):Connect(refresh)
    Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(refresh)

    -- One non-yielding supply transaction is shared by humans and AI.
    -- A globally consumed station cannot be redeemed twice in one tick.
    station.use = function(character, humanoid, root, player)
        if not character or not character.Parent or not humanoid or not root
            or not humanoid:IsDescendantOf(character)
            or not root:IsDescendantOf(Workspace) then return false end
        local now = Workspace:GetServerTimeNow()
        local distance = (root.Position - console.Position).Magnitude
        if stationState(now, station.readyAt) ~= "READY"
            or not Rules.canUse(Workspace:GetAttribute("NeonMatchPhase"),
                humanoid.Health, humanoid.MaxHealth, distance, now, station.readyAt)
            or not hasClearAccess(character, root, station) then
            return false
        end
        local health, amount = Rules.healedHealth(humanoid.Health, humanoid.MaxHealth)
        if amount <= 0 then return false end
        station.readyAt = now + Rules.COOLDOWN
        station.revision += 1
        local revision = station.revision
        refresh()
        humanoid.Health = health
        audio:Play()
        if player then
            remotes.WeaponFeedback:FireClient(player, { kind = "MedicalHeal", amount = amount })
        end
        local function finishCooldown()
            if station.revision ~= revision or not model.Parent then return end
            local remaining = station.readyAt - Workspace:GetServerTimeNow()
            if remaining > 0 then
                task.delay(remaining, finishCooldown)
                return
            end
            station.reset()
        end
        task.delay(Rules.COOLDOWN, finishCooldown)
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

-- Stable, bounded objective selection prevents repeatedly navigating
-- to a blocked medical station. No hidden enemy coordinates are consulted.
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

function Service.resetBotGoal(bot)
    bot.medicalTargetId = nil
    bot.medicalHoldUntil = 0
    bot.medicalFailedId = nil
    bot.medicalFailedUntil = 0
    bot.medicalGoalActive = false
end

function Service.reportBotStuck(bot)
    if not bot.medicalGoalActive or not bot.medicalTargetId then return end
    bot.medicalFailedId = bot.medicalTargetId
    bot.medicalFailedUntil = os.clock() + Objective.AVOID_SECONDS
    bot.medicalTargetId = nil
    bot.medicalHoldUntil = 0
    bot.medicalGoalActive = false
end

function Service.botGoal(bot)
    if not bot or not bot.model then return nil end
    local humanoid, root = botState(bot.model)
    if not humanoid or stationState(Workspace:GetServerTimeNow(), 0) ~= "READY" then
        bot.medicalTargetId = nil
        return nil
    end
    local now = os.clock()
    local serverNow = Workspace:GetServerTimeNow()
    local seen = bot.lastKnownTargetPosition
    -- An enemy position may influence safety for 9 s after actual sighting;
    -- do not inspect currently hidden players or other bots' observations.
    local threat = typeof(seen) == "Vector3"
        and now - (bot.lastTargetSeenAt or -math.huge) <= 9
        and seen or nil
    local choices = {}
    for index, station in ipairs(stations) do
        local p = station.console.Position
        table.insert(choices, {
            id = index,
            available = station.readyAt <= serverNow
                and math.abs(root.Position.Y - p.Y - 1.2) <= 4,
            distance = (root.Position - p).Magnitude,
            dangerDistance = threat and (p - threat).Magnitude or nil,
        })
    end
    local selected = Objective.choose(choices, now, bot.medicalTargetId,
        bot.medicalHoldUntil or 0, bot.medicalFailedId, bot.medicalFailedUntil or 0)
    if not selected then
        bot.medicalTargetId = nil
        return nil
    end
    if bot.medicalTargetId ~= selected or now >= (bot.medicalHoldUntil or 0) then
        bot.medicalHoldUntil = now + Objective.HOLD_SECONDS
        bot.medicalTargetId = selected
    end
    local position = stations[selected].console.Position
    return Vector3.new(position.X, root.Position.Y, position.Z)
end

function Service.tryHealBot(character)
    local humanoid, root = botState(character)
    if not humanoid then return false end
    local now = Workspace:GetServerTimeNow()
    if stationState(now, 0) ~= "READY" then return false end
    for _, station in ipairs(stations) do
        if station.readyAt <= now
            and (root.Position - station.console.Position).Magnitude <= BOT_USE_DISTANCE
            and station.use(character, humanoid, root, nil) then
            return true
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
