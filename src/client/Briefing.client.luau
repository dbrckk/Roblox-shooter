-- IRON YARD: short, non-blocking match briefing for PC and mobile.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guide = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FirstMatchGuide"))
local GamepadCombatPolicy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GamepadCombatPolicy"))

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "IronYardBriefing"
gui.ResetOnSpawn = false
gui.DisplayOrder = 14
gui.IgnoreGuiInset = false
local playerGui = player:WaitForChild("PlayerGui")
gui.Parent = playerGui
playerGui:SetAttribute("IronYardBriefingOpen", false)

local panel = Instance.new("Frame")
panel.Name = "MissionCard"
panel.AnchorPoint = Vector2.new(0.5, 0)
-- Replace the scoreboard in the top safe lane instead of overlapping
-- weapon-selection buttons that begin below y=82 on compact devices.
panel.Position = UDim2.new(0.5, 0, 0, 8)
panel.Size = UDim2.new(0.9, 0, 0, 58)
panel.BackgroundColor3 = Color3.fromRGB(37, 45, 44)
panel.BackgroundTransparency = 0.10
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(348, 58)
constraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = panel
local stripe = Instance.new("Frame")
stripe.Name = "IndustrialSafetyStripe"
stripe.Size = UDim2.new(0, 5, 1, -10)
stripe.Position = UDim2.fromOffset(6, 5)
stripe.BackgroundColor3 = Color3.fromRGB(224, 177, 82)
stripe.BorderSizePixel = 0
stripe.Parent = panel

local function makeText(name, y, size, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Size = UDim2.new(1, -28, 0, 24)
    label.Position = UDim2.fromOffset(23, y)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextSize = size
    label.TextColor3 = color
    label.Parent = panel
    return label
end
local title = makeText("ObjectiveTitle", 5, 14, Color3.fromRGB(247, 238, 217))
local subtitle = makeText("ObjectiveDetails", 30, 12, Color3.fromRGB(214, 212, 194))
local token = 0
local function controllerActive()
    return GamepadCombatPolicy.isGamepad(UserInputService:GetLastInputType().Name)
end
local playedIntro = false
local hintScheduled = false
local phaseToken = 0
local observedPhase, observedMode
local activeFades = {}

local function matchMode()
    if Workspace:GetAttribute("IronYardDedicatedDuel") == true then return "DUEL" end
    return Workspace:GetAttribute("IronYardMatchMode")
end

local function menuOpen()
    return playerGui:GetAttribute("IronYardSettingsOpen") == true
        or playerGui:GetAttribute("IronYardDuelMenuOpen") == true
end

local function setCardVisible(visible)
    panel.Visible = visible
    playerGui:SetAttribute("IronYardBriefingOpen", visible)
end

local function clearCard()
    token += 1
    for _, fade in ipairs(activeFades) do fade:Cancel() end
    table.clear(activeFades)
    setCardVisible(false)
end

local function display(a, b, timeout)
    if matchMode() ~= "FFA" or menuOpen() then return end
    clearCard()
    local current = token
    title.Text = a
    subtitle.Text = b
    setCardVisible(true)
    panel.BackgroundTransparency = 0.10
    title.TextTransparency = 0
    subtitle.TextTransparency = 0
    if timeout then
        task.delay(timeout, function()
            if token ~= current or not panel.Parent then return end
            local fade = TweenService:Create(panel, TweenInfo.new(0.35), {BackgroundTransparency = 1})
            local fade1 = TweenService:Create(title, TweenInfo.new(0.35), {TextTransparency = 1})
            local fade2 = TweenService:Create(subtitle, TweenInfo.new(0.35), {TextTransparency = 1})
            activeFades = { fade, fade1, fade2 }
            for _, tween in ipairs(activeFades) do tween:Play() end
            fade.Completed:Wait()
            if token == current then
                table.clear(activeFades)
                setCardVisible(false)
            end
        end)
    end
end

-- One short, non-blocking follow-up after the first actual shot.
-- The client increments the attribute only when a live FireWeapon is sent.
local function firstShotHint()
    if not playedIntro or matchMode() ~= "FFA" or menuOpen() or hintScheduled
        or Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then return end
    if (playerGui:GetAttribute("IronYardFirstShots") or 0) < 1 then return end
    hintScheduled = true
    local stats = player:FindFirstChild("leaderstats")
    local kills = stats and stats:FindFirstChild("Eliminations")
    local text = Guide.hint(UserInputService.TouchEnabled, 1,
        kills and kills.Value or 0, controllerActive())
    if text then
        local current = phaseToken
        -- Let the objective card finish; this cue never blocks input.
        task.delay(8.5, function()
            if current == phaseToken and Workspace:GetAttribute("NeonMatchPhase") == "LIVE" then
                display("STAY ALIVE   /   TAKE COVER", text, 5)
            end
        end)
    end
end

local function onPhaseChanged()
    local phase = Workspace:GetAttribute("NeonMatchPhase")
    local mode = matchMode()
    if phase == observedPhase and mode == observedMode then return end
    observedPhase, observedMode = phase, mode
    phaseToken += 1
    clearCard()
    if mode ~= "FFA" then return end
    if phase == "COUNTDOWN" then
        display("IRON YARD   /   PREPARE TO DEPLOY",
            controllerActive() and "RT FIRE • LT AIM • A JUMP"
                or (UserInputService.TouchEnabled and "MOVE • AIM • TAP FIRE"
                    or "SPRINT • SLIDE • USE COVER"))
    elseif Guide.shouldPrompt(phase, playedIntro) and not menuOpen() then
        playedIntro = true
        display("MISSION   /   FREE FOR ALL",
            Guide.objective(Workspace:GetAttribute("NeonMatchScoreLimit")), 8)
        local current = phaseToken
        task.delay(8.5, function()
            if current ~= phaseToken or Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE"
                or hintScheduled then return end
            local hint = Guide.hint(UserInputService.TouchEnabled, 0, 0,
                controllerActive())
            if hint then display("FIRST ENGAGEMENT   /   CONTROLS", hint, 5) end
        end)
    end
end

Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(onPhaseChanged)
Workspace:GetAttributeChangedSignal("IronYardMatchMode"):Connect(onPhaseChanged)
Workspace:GetAttributeChangedSignal("IronYardDedicatedDuel"):Connect(onPhaseChanged)
playerGui:GetAttributeChangedSignal("IronYardFirstShots"):Connect(firstShotHint)
playerGui:GetAttributeChangedSignal("IronYardSettingsOpen"):Connect(function()
    if menuOpen() then clearCard() end
end)
playerGui:GetAttributeChangedSignal("IronYardDuelMenuOpen"):Connect(function()
    if menuOpen() then clearCard() end
end)
onPhaseChanged()
