-- IRON YARD / authoritative combat medal notifications for one player.
-- Round and session XP are ephemeral until persistent progression is implemented.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrecisionNet")).getRemotes(false)

local gui = Instance.new("ScreenGui")
gui.Name = "IronYardCombatAwards"
gui.DisplayOrder = 18
gui.IgnoreGuiInset = false
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "CombatMedal"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 165)
panel.Size = UDim2.new(0.88, 0, 0, 59)
panel.BackgroundColor3 = Color3.fromRGB(34, 40, 40)
panel.BackgroundTransparency = 0.11
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(310, 59)
sizeLimit.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 7)
corner.Parent = panel
local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(208, 161, 87)
border.Thickness = 1
border.Transparency = 0.25
border.Parent = panel

local function text(name, position, size, fontSize, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = color
    label.TextSize = fontSize
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Parent = panel
    return label
end

local title = text("MedalTitle", UDim2.fromOffset(10, 5),
    UDim2.new(1, -20, 0, 28), 17, Color3.fromRGB(242, 204, 137))
local detail = text("MedalDetail", UDim2.fromOffset(10, 31),
    UDim2.new(1, -20, 0, 20), 11, Color3.fromRGB(242, 236, 214))
local revision = 0
local active = {}

local function notify(message)
    if typeof(message) ~= "table" or message.kind ~= "CombatAward"
        or typeof(message.points) ~= "number" or typeof(message.medal) ~= "string" then return end
    revision += 1
    local current = revision
    for _, tween in ipairs(active) do tween:Cancel() end
    table.clear(active)

    title.Text = string.sub(message.medal, 1, 30) .. "  /  +" .. math.floor(message.points) .. " XP"
    detail.Text = string.format("STREAK %d   |   ROUND %d XP   |   SESSION %d XP",
        math.max(0, tonumber(message.streak) or 0),
        math.max(0, tonumber(message.roundXP) or 0),
        math.max(0, tonumber(message.sessionXP) or 0))
    title.TextTransparency = 0
    detail.TextTransparency = 0
    panel.BackgroundTransparency = 0.11
    border.Transparency = 0.25
    panel.Visible = true

    task.delay(2.45, function()
        if current ~= revision or not panel.Parent then return end
        local info = TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local fadePanel = TweenService:Create(panel, info, { BackgroundTransparency = 1 })
        local fadeTitle = TweenService:Create(title, info, { TextTransparency = 1 })
        local fadeDetail = TweenService:Create(detail, info, { TextTransparency = 1 })
        local fadeBorder = TweenService:Create(border, info, { Transparency = 1 })
        active = { fadePanel, fadeTitle, fadeDetail, fadeBorder }
        for _, tween in ipairs(active) do tween:Play() end
        fadePanel.Completed:Wait()
        if current == revision then panel.Visible = false end
    end)
end

remotes.WeaponFeedback.OnClientEvent:Connect(notify)
Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(function()
    if Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then
        revision += 1
        for _, tween in ipairs(active) do tween:Cancel() end
        table.clear(active)
        panel.Visible = false
    end
end)
