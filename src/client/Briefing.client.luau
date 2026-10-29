-- IRON YARD: short, non-blocking match briefing for PC and mobile.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
panel.Position = UDim2.new(0.5, 0, 0, 94)
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
local playedIntro = false

local function setCardVisible(visible)
    panel.Visible = visible
    playerGui:SetAttribute("IronYardBriefingOpen", visible)
end

local function display(a, b, timeout)
    token += 1
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
            fade:Play()
            fade1:Play()
            fade2:Play()
            fade.Completed:Wait()
            if token == current then setCardVisible(false) end
        end)
    end
end

local function onPhaseChanged()
    local phase = Workspace:GetAttribute("NeonMatchPhase")
    if phase == "COUNTDOWN" then
        display("IRON YARD   /   PREPARE TO DEPLOY",
            UserInputService.TouchEnabled and "MOVE • AIM • TAP FIRE" or "SPRINT • SLIDE • USE COVER")
    elseif phase == "LIVE" then
        if not playedIntro then
            playedIntro = true
            display("MISSION   /   FREE FOR ALL", "FIRST TO 15 ELIMINATIONS", 8)
        else
            token += 1
            setCardVisible(false)
        end
    else
        token += 1
        setCardVisible(false)
    end
end

Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(onPhaseChanged)
onPhaseChanged()
