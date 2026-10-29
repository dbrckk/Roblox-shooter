-- IRON YARD / compact incoming-fire indicator.
-- Damage origin is stamped by the server after confirmed combat damage.
-- Purely cosmetic: does not affect hit registration, aiming or movement.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("IronYardDamageDirection")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "IronYardDamageDirection"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 28
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local pointer = Instance.new("Frame")
pointer.Name = "IncomingDirection"
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Size = UDim2.fromOffset(34, 34)
pointer.BackgroundTransparency = 1
pointer.Visible = false
pointer.Parent = gui

local wings = {}
for side = -1, 1, 2 do
    local wing = Instance.new("Frame")
    wing.Name = side == -1 and "ArrowLeft" or "ArrowRight"
    wing.Size = UDim2.fromOffset(5, 20)
    wing.Position = UDim2.fromOffset(17 + side * 6, 8)
    wing.AnchorPoint = Vector2.new(0.5, 0.5)
    wing.Rotation = side == -1 and -36 or 36
    wing.BackgroundColor3 = Color3.fromRGB(247, 131, 84)
    wing.BackgroundTransparency = 0.08
    wing.BorderSizePixel = 0
    wing.Parent = pointer
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 2)
    corner.Parent = wing
    table.insert(wings, wing)
end

local activeTweens = {}
local revision = 0
local function showDamage(source)
    if typeof(source) ~= "Vector3" then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local offset = source - camera.CFrame.Position
    local flat = Vector3.new(offset.X, 0, offset.Z)
    if flat.Magnitude < 0.5 then return end

    local relative = camera.CFrame:VectorToObjectSpace(flat.Unit)
    local x, y = relative.X, relative.Z
    local magnitude = math.sqrt(x * x + y * y)
    if magnitude < 0.01 then return end
    x, y = x / magnitude, y / magnitude

    local viewport = camera.ViewportSize
    local radius = math.clamp(math.min(viewport.X, viewport.Y) * 0.17, 52, 96)
    pointer.Position = UDim2.new(0.5, math.floor(x * radius), 0.5, math.floor(y * radius))
    pointer.Rotation = math.deg(math.atan2(x, -y))
    pointer.Visible = true

    revision += 1
    local thisRevision = revision
    for _, tween in ipairs(activeTweens) do tween:Cancel() end
    table.clear(activeTweens)
    for _, wing in ipairs(wings) do
        wing.BackgroundTransparency = 0.08
        local tween = TweenService:Create(wing, TweenInfo.new(0.72,
            Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 1,
        })
        table.insert(activeTweens, tween)
        tween:Play()
    end
    task.delay(0.76, function()
        if revision == thisRevision and pointer.Parent then pointer.Visible = false end
    end)
end

local function bindCharacter(character)
    character:GetAttributeChangedSignal("IronYardLastHitTime"):Connect(function()
        if player.Character ~= character then return end
        showDamage(character:GetAttribute("IronYardLastHitPosition"))
    end)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end
