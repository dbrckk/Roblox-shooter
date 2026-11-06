-- IRON YARD: responsive defeat card; lethal damage attribution is server-authored.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local WeaponConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponConfig"))

local gui = Instance.new("ScreenGui")
gui.Name = "IronYardDefeatScreen"
gui.DisplayOrder = 26 -- Official RoundResults appears above at 30.
gui.IgnoreGuiInset = false
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local shade = Instance.new("Frame")
shade.Name = "DefeatShade"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(15, 21, 21)
shade.BackgroundTransparency = 0.34
shade.BorderSizePixel = 0
shade.Visible = false
shade.Parent = gui

local card = Instance.new("Frame")
card.Name = "DefeatCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.49)
card.Size = UDim2.new(0.90, 0, 0, 182)
card.BackgroundColor3 = Color3.fromRGB(31, 39, 38)
card.BackgroundTransparency = 0.035
card.BorderSizePixel = 0
card.Parent = shade
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(388, 182)
limit.Parent = card
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 11)
corner.Parent = card
local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(211, 163, 91)
border.Transparency = 0.08
border.Thickness = 1.6
border.Parent = card
local stripe = Instance.new("Frame")
stripe.Name = "IndustrialSafetyStripe"
stripe.Position = UDim2.fromOffset(15, 12)
stripe.Size = UDim2.new(0, 4, 1, -24)
stripe.BackgroundColor3 = Color3.fromRGB(219, 164, 91)
stripe.BorderSizePixel = 0
stripe.Parent = card

local function makeLine(name, y, height, size, color)
    local text = Instance.new("TextLabel")
    text.Name = name
    text.Position = UDim2.new(0, 30, 0, y)
    text.Size = UDim2.new(1, -44, 0, height)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextSize = size
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextTruncate = Enum.TextTruncate.AtEnd
    text.TextColor3 = color
    text.Parent = card
    return text
end

local title = makeLine("Title", 15, 27, 20, Color3.fromRGB(246, 233, 210))
local attacker = makeLine("Killer", 51, 24, 14, Color3.fromRGB(247, 244, 235))
local cause = makeLine("Cause", 81, 21, 12, Color3.fromRGB(217, 175, 111))
local countdown = makeLine("Redeploy", 115, 25, 15, Color3.fromRGB(244, 226, 190))
local hint = makeLine("Shield", 148, 21, 11, Color3.fromRGB(177, 194, 184))
title.Text = "ELIMINATED"
hint.Text = "SPAWN SHIELD 2.5s  /  SHOOT TO CANCEL"

local activeCharacter = nil
local deathConnection = nil
local attributeConnections = {}
local dead = false
local diedAt = nil
local epoch = 0

local function update()
    local show = dead and activeCharacter == player.Character
        and Workspace:GetAttribute("NeonMatchPhase") == "LIVE"
    shade.Visible = show
    if not show then return end

    local name = activeCharacter:GetAttribute("IronYardDefeatAttacker")
    local weaponId = activeCharacter:GetAttribute("IronYardDefeatWeapon")
    local headshot = activeCharacter:GetAttribute("IronYardDefeatHeadshot") == true
    if typeof(name) == "string" and name ~= "" then
        attacker.Text = "DEFEATED BY  " .. name
        local definition = typeof(weaponId) == "string" and WeaponConfig.get(weaponId) or nil
        local weaponName = definition and definition.displayName
            or (weaponId == "VX" and "OPERATOR RIFLE" or "UNKNOWN WEAPON")
        cause.Text = (headshot and "HEADSHOT  /  " or "WEAPON  /  ") .. weaponName
    else
        attacker.Text = "ELIMINATED IN THE ARENA"
        cause.Text = "ENVIRONMENT OR UNATTRIBUTED DAMAGE"
    end

    local stamp = activeCharacter:GetAttribute("IronYardDefeatAt")
    local startedAt = typeof(stamp) == "number" and stamp > 0 and stamp or diedAt
    local elapsed = startedAt and math.max(0, Workspace:GetServerTimeNow() - startedAt) or 0
    local remaining = math.max(0, math.ceil(Players.RespawnTime - elapsed))
    countdown.Text = remaining > 0 and ("REDEPLOY IN  " .. remaining .. "s")
        or "REDEPLOYING..."
end

local function onDeath()
    if activeCharacter ~= player.Character or dead then return end
    dead = true
    diedAt = Workspace:GetServerTimeNow()
    update()
    local token = epoch
    task.spawn(function()
        while token == epoch and dead do
            update()
            task.wait(0.15)
        end
    end)
end

local function watchCharacter(character)
    epoch += 1
    if deathConnection then deathConnection:Disconnect() end
    deathConnection = nil
    for _, conn in ipairs(attributeConnections) do conn:Disconnect() end
    table.clear(attributeConnections)
    activeCharacter = character
    dead = false
    diedAt = nil
    shade.Visible = false
    for _, key in ipairs({
        "IronYardDefeatAttacker", "IronYardDefeatWeapon",
        "IronYardDefeatHeadshot", "IronYardDefeatAt",
    }) do
        table.insert(attributeConnections, character:GetAttributeChangedSignal(key):Connect(update))
    end
    local humanoid = character:WaitForChild("Humanoid", 10)
    if activeCharacter ~= character then return end
    if humanoid then
        deathConnection = humanoid.Died:Connect(onDeath)
        if humanoid.Health <= 0 then onDeath() end
    end
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then task.defer(watchCharacter, player.Character) end
Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(update)
