-- One medical hint at low health. No network requests.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SupplyRules"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "IronYardMedicalGuide"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 16
gui.Parent = playerGui

local mint = Color3.fromRGB(184, 234, 199)
local amber = Color3.fromRGB(242, 190, 92)
local card = Instance.new("Frame")
card.Name = "NearbyMedical"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 94)
card.Size = UDim2.fromOffset(154, 28)
card.BackgroundColor3 = Color3.fromRGB(31, 49, 45)
card.BackgroundTransparency = 0.14
card.BorderSizePixel = 0
card.Visible = false
card.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = card

local pointer = Instance.new("Frame")
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Position = UDim2.fromOffset(16, 14)
pointer.Size = UDim2.fromOffset(16, 16)
pointer.BackgroundTransparency = 1
pointer.Visible = true
pointer.Parent = card
for _, side in ipairs({ -1, 1 }) do
    local wing = Instance.new("Frame")
    wing.AnchorPoint = Vector2.new(0.5, 0.5)
    wing.Position = UDim2.fromOffset(8 + side * 2.6, 7)
    wing.Size = UDim2.fromOffset(2.4, 8)
    wing.Rotation = side * -40
    wing.BackgroundColor3 = mint
    wing.BorderSizePixel = 0
    wing.Parent = pointer
end

local label = Instance.new("TextLabel")
label.Position = UDim2.fromOffset(29, 0)
label.Size = UDim2.new(1, -33, 1, 0)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextSize = 12
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextColor3 = mint
label.Parent = card

local function nearestReady(position, previousPrompt)
    local best, bestDelta, bestName
    local distanceSquared = math.huge
    local previousDelta, previousSquared
    for _, prompt in ipairs(CollectionService:GetTagged(Rules.PROMPT_TAG)) do
        if not prompt:IsA("ProximityPrompt") or not prompt:IsDescendantOf(Workspace)
            or prompt:GetAttribute(Rules.PROMPT_READY_ATTRIBUTE) ~= true then continue end
        local anchor = prompt.Parent
        if not anchor or not anchor:IsA("BasePart") then continue end
        local delta = anchor.Position - position
        local squared = delta:Dot(delta)
        if prompt == previousPrompt then
            previousDelta, previousSquared = delta, squared
        end
        local name = anchor.Parent and anchor.Parent.Name or anchor.Name
        if squared < distanceSquared or (bestName and squared == distanceSquared and name < bestName) then
            best, bestDelta, distanceSquared, bestName = prompt, delta, squared, name
        end
    end
    if previousPrompt ~= best and Rules.keepGuideTarget(previousSquared, distanceSquared) then
        return previousPrompt, previousDelta, previousSquared
    end
    return best, bestDelta, distanceSquared
end

local openMenus = {
    "IronYardBriefingOpen",
    "IronYardSettingsOpen",
    "IronYardDuelMenuOpen",
}
local shownPrompts = {}
local targetPrompt
local function showHint(text, bearing, isRecharging)
    local directional = bearing ~= nil
    if pointer.Visible ~= directional then
        pointer.Visible = directional
        label.Position = UDim2.fromOffset(directional and 29 or 4, 0)
        label.Size = UDim2.new(1, directional and -33 or -8, 1, 0)
        label.TextXAlignment = directional and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
    end
    if directional then pointer.Rotation = bearing end
    local color = isRecharging and amber or mint
    if label.TextColor3 ~= color then label.TextColor3 = color end
    if label.Text ~= text then label.Text = text end
    card.Visible = true
end

local function rechargeSeconds()
    local folder = Workspace:FindFirstChild(Rules.STATIONS_FOLDER)
    local deadline = folder and folder:GetAttribute(Rules.NEXT_OPENING_ATTRIBUTE)
    return Rules.rechargeSeconds(Workspace:GetServerTimeNow(), deadline)
end

local function update()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not humanoid or not root or not camera
        or not Rules.shouldGuide(Workspace:GetAttribute("IronYardMatchMode"),
            Workspace:GetAttribute("NeonMatchPhase"), humanoid.Health, humanoid.MaxHealth) then
        targetPrompt = nil
        card.Visible = false
        return
    end
    for _, attribute in ipairs(openMenus) do
        if playerGui:GetAttribute(attribute) == true then
            card.Visible = false
            return
        end
    end

    local seconds = rechargeSeconds()
    if seconds > 0 then
        targetPrompt = nil
        showHint(string.format("MEDICAL  /  NEXT IN %ds", seconds), nil, true)
        return
    end

    local prompt, delta, distanceSquared = nearestReady(root.Position, targetPrompt)
    targetPrompt = prompt
    if not prompt or next(shownPrompts) ~= nil then
        card.Visible = false
        return
    end
    if delta.X * delta.X + delta.Z * delta.Z < 1 then
        -- There is no stable compass heading directly above or below a station.
        if math.abs(delta.Y) < 1 then
            showHint("MEDICAL  /  NEARBY", nil)
        else
            showHint(delta.Y > 0 and "MEDICAL  /  ABOVE" or "MEDICAL  /  BELOW", nil)
        end
        return
    end
    local right = camera.CFrame.RightVector
    local bearing = Rules.guideBearing(delta.X, delta.Z, right.X, right.Z)
    local text = string.format("MEDICAL  /  %d st", math.floor(math.sqrt(distanceSquared) + 0.5))
    showHint(text, bearing)
end

local connections = {
    ProximityPromptService.PromptShown:Connect(function(prompt)
        if CollectionService:HasTag(prompt, Rules.PROMPT_TAG) then
            shownPrompts[prompt] = true
            update()
        end
    end),
    ProximityPromptService.PromptHidden:Connect(function(prompt)
        if shownPrompts[prompt] then
            shownPrompts[prompt] = nil
            update()
        end
    end),
    CollectionService:GetInstanceRemovedSignal(Rules.PROMPT_TAG):Connect(function(prompt)
        local wasShown = shownPrompts[prompt] == true
        shownPrompts[prompt] = nil
        if targetPrompt == prompt then targetPrompt = nil end
        if wasShown or card.Visible then update() end
    end),
    player.CharacterRemoving:Connect(function()
        targetPrompt = nil
        table.clear(shownPrompts)
        card.Visible = false
    end),
    Workspace:GetAttributeChangedSignal("IronYardMatchMode"):Connect(update),
    Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(update),
}
for _, attribute in ipairs(openMenus) do
    table.insert(connections, playerGui:GetAttributeChangedSignal(attribute):Connect(update))
end

local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.2 then return end
    elapsed = 0
    update()
end))
script.Destroying:Connect(function()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    gui:Destroy()
end)
