-- IRON YARD: short, non-blocking match briefing for PC and mobile.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
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
local COUNTDOWN_CONTROLS = {
    gamepad = "RT FIRE • LT AIM • A JUMP",
    touch = "TAP FIRE • HOLD JUMP TO BOOST",
    keyboard = "SPRINT • SLIDE • USE COVER",
}
local function inputDevice()
    local lastInput = UserInputService:GetLastInputType()
    if GamepadCombatPolicy.isGamepad(lastInput.Name) then return "gamepad" end
    if UserInputService.TouchEnabled and lastInput ~= Enum.UserInputType.Keyboard
        and not string.find(lastInput.Name, "Mouse", 1, true) then
        return "touch"
    end
    return "keyboard"
end

local token = 0
local guideDeadline
local guideEnded = false
local activeCard
local observedPhase, observedMode
local activeFades = {}
local shown = {}
local completed = {
    DUEL = playerGui:GetAttribute("IronYardDuelMenuOpen") == true,
}
local updateGuide

local function matchMode()
    if Workspace:GetAttribute("IronYardDedicatedDuel") == true then return "DUEL" end
    return Workspace:GetAttribute("IronYardMatchMode")
end

local function menuOpen()
    return GuiService.MenuIsOpen or playerGui:GetAttribute("IronYardSettingsOpen") == true
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
    activeCard = nil
    setCardVisible(false)
end

local function display(card, a, b, timeout)
    clearCard()
    local current = token
    activeCard = card
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
                clearCard()
                updateGuide()
            end
        end)
    end
end

updateGuide = function()
    local phase = Workspace:GetAttribute("NeonMatchPhase")
    if menuOpen() or matchMode() ~= "FFA" then
        if activeCard then clearCard() end
        return
    end
    if phase == "COUNTDOWN" then
        if not activeCard then
            display("COUNTDOWN", "IRON YARD   /   PREPARE TO DEPLOY", COUNTDOWN_CONTROLS[inputDevice()])
        end
        return
    end
    if phase ~= "LIVE" or guideEnded or not guideDeadline then return end
    local remaining = guideDeadline - os.clock()
    if remaining <= 0 then return end
    if not shown.OBJECTIVE then
        shown.OBJECTIVE = true
        display("OBJECTIVE", "MISSION   /   FREE FOR ALL",
            Guide.objective(Workspace:GetAttribute("NeonMatchScoreLimit")), math.min(5, remaining))
        return
    end
    completed.FIRE = (playerGui:GetAttribute("IronYardFirstShots") or 0) > 0
    completed.RELOAD = playerGui:GetAttribute("IronYardFirstReload") == true
    if activeCard and not completed[activeCard] then return end
    if activeCard then clearCard() end
    local action = Guide.nextAction(completed, shown)
    if action then
        shown[action] = true
        local heading, control = Guide.prompt(action, inputDevice())
        display(action, heading, control, math.min(5, remaining))
    end
end

local function onPhaseChanged()
    local phase = Workspace:GetAttribute("NeonMatchPhase")
    local mode = matchMode()
    if phase == observedPhase and mode == observedMode then return end
    if observedPhase == "LIVE" and observedMode == "FFA" then guideEnded = true end
    observedPhase, observedMode = phase, mode
    clearCard()
    if not guideDeadline and phase == "LIVE" and mode == "FFA" then guideDeadline = os.clock() + 60 end
    updateGuide()
end

Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(onPhaseChanged)
Workspace:GetAttributeChangedSignal("IronYardMatchMode"):Connect(onPhaseChanged)
Workspace:GetAttributeChangedSignal("IronYardDedicatedDuel"):Connect(onPhaseChanged)
playerGui:GetAttributeChangedSignal("IronYardFirstShots"):Connect(updateGuide)
playerGui:GetAttributeChangedSignal("IronYardFirstReload"):Connect(updateGuide)
playerGui:GetAttributeChangedSignal("IronYardSettingsOpen"):Connect(updateGuide)
playerGui:GetAttributeChangedSignal("IronYardDuelMenuOpen"):Connect(function()
    if playerGui:GetAttribute("IronYardDuelMenuOpen") == true then completed.DUEL = true end
    updateGuide()
end)
GuiService.MenuOpened:Connect(updateGuide)
GuiService.MenuClosed:Connect(updateGuide)
UserInputService.LastInputTypeChanged:Connect(function()
    if activeCard == "COUNTDOWN" then
        subtitle.Text = COUNTDOWN_CONTROLS[inputDevice()]
    elseif activeCard and activeCard ~= "OBJECTIVE" then
        local _, control = Guide.prompt(activeCard, inputDevice())
        subtitle.Text = control
    end
end)
onPhaseChanged()
