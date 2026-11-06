-- Small, client-only acknowledgment from a real server medical pickup.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("PrecisionNet")).getRemotes(false)
local gui = Instance.new("ScreenGui")
gui.Name = "IronYardHealingFeedback"
gui.DisplayOrder = 24
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local card = Instance.new("TextLabel")
card.Name = "HealthRestored"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.70)
card.Size = UDim2.new(0.72, 0, 0, 42)
card.BackgroundColor3 = Color3.fromRGB(28, 53, 46)
card.BackgroundTransparency = 0.12
card.TextColor3 = Color3.fromRGB(182, 239, 194)
card.Font = Enum.Font.GothamBold
card.TextSize = 17
card.BorderSizePixel = 0
card.Visible = false
card.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(260, 42)
limit.Parent = card
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = card
local token = 0
Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(function()
    if Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then
        token += 1
        card.Visible = false
    end
end)
remotes.WeaponFeedback.OnClientEvent:Connect(function(msg)
    if typeof(msg) ~= "table" or msg.kind ~= "MedicalHeal"
        or typeof(msg.amount) ~= "number"
        or Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then return end
    token += 1
    local current = token
    card.Text = "FIELD MEDICAL  /  +" .. math.clamp(math.floor(msg.amount + 0.5), 1, 40) .. " HP"
    card.TextTransparency = 0
    card.BackgroundTransparency = 0.12
    card.Visible = true
    task.delay(1.1, function()
        if current ~= token or not card.Parent then return end
        local fade = TweenService:Create(card, TweenInfo.new(0.35), {
            TextTransparency = 1, BackgroundTransparency = 1,
        })
        fade:Play()
        fade.Completed:Wait()
        if current == token then card.Visible = false end
    end)
end)
