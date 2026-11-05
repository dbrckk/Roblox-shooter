-- IRON YARD: authoritative elimination ticker.
-- Entries arrive from the server only; clients cannot forge another player's kill.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrecisionNet")).getRemotes(false)
local gui = Instance.new("ScreenGui")
gui.Name = "NeonStrikeKillFeed"
gui.DisplayOrder = 17
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local touch = UserInputService.TouchEnabled
local frame = Instance.new("Frame")
frame.Name = "Feed"
frame.AnchorPoint = touch and Vector2.new(0, 0) or Vector2.new(1, 0)
frame.Position = touch and UDim2.fromOffset(12, 113) or UDim2.new(1, -12, 0, 92)
frame.Size = touch and UDim2.fromOffset(200, 72) or UDim2.fromOffset(290, 165)
frame.BackgroundTransparency = 1
frame.Parent = gui

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = touch and Enum.HorizontalAlignment.Left
    or Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.Padding = UDim.new(0, 5)
layout.Parent = frame

local entries = {}
local serial = 0
local MAX_ENTRIES = touch and 2 or 4

local function updateFeedLayout()
    if not touch then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local width = math.min(234, math.max(136, math.floor(viewport.X * 0.38)))
    frame.Size = UDim2.fromOffset(width, 72)
    -- In very narrow portrait displays, priority goes to weapon controls.
    frame.Visible = viewport.X >= 360
        and Workspace:GetAttribute("NeonMatchPhase") == "LIVE"
        and gui.Parent:GetAttribute("IronYardBriefingOpen") ~= true
end
Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(updateFeedLayout)
gui.Parent:GetAttributeChangedSignal("IronYardBriefingOpen"):Connect(updateFeedLayout)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local camera = Workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFeedLayout)
    end
    updateFeedLayout()
end)
local camera = Workspace.CurrentCamera
if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFeedLayout) end
updateFeedLayout()

local function addEntry(info)
    if typeof(info) ~= "table" or typeof(info.attacker) ~= "string" or typeof(info.target) ~= "string" then
        return
    end
    serial += 1
    local row = Instance.new("Frame")
    row.Name = "Elimination"
    row.LayoutOrder = -serial
    row.Size = touch and UDim2.new(1, -4, 0, 31)
        or UDim2.fromOffset(270, 31)
    row.BackgroundColor3 = Color3.fromRGB(43, 48, 47)
    row.BackgroundTransparency = 0.15
    row.BorderSizePixel = 0
    row.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = row
    local stroke = Instance.new("UIStroke")
    stroke.Color = info.headshot and Color3.fromRGB(255, 178, 92) or Color3.fromRGB(185, 181, 156)
    stroke.Thickness = 1
    stroke.Transparency = 0.35
    stroke.Parent = row

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, -14, 1, 0)
    text.Position = UDim2.fromOffset(7, 0)
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = Color3.fromRGB(255, 251, 236)
    text.TextSize = 11
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextTruncate = Enum.TextTruncate.AtEnd
    local tag = info.headshot and " [HEADSHOT]" or ""
    text.Text = string.sub(info.attacker, 1, 18) .. "  >  " .. string.sub(info.target, 1, 18) .. tag
    text.Parent = row

    table.insert(entries, 1, row)
    while #entries > MAX_ENTRIES do
        local removed = table.remove(entries)
        if removed then removed:Destroy() end
    end

    task.delay(5, function()
        if not row.Parent then return end
        local tween = TweenService:Create(row, TweenInfo.new(0.28), { BackgroundTransparency = 1 })
        local fade = TweenService:Create(text, TweenInfo.new(0.28), { TextTransparency = 1 })
        tween:Play()
        fade:Play()
        tween.Completed:Wait()
        local index = table.find(entries, row)
        if index then table.remove(entries, index) end
        row:Destroy()
    end)
end

remotes.KillFeed.OnClientEvent:Connect(addEntry)
