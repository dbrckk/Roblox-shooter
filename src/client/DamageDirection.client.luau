-- IRON YARD / compact incoming-fire indicator.
-- Damage origin is stamped by the server after confirmed combat damage.
-- Purely cosmetic: does not affect hit registration, aiming or movement.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Direction = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DamageDirectionPolicy"))
local RENDER_BINDING = "IronYardDamageDirection"

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
    wing.Position = UDim2.fromOffset(17 + side * 6, 10)
    wing.AnchorPoint = Vector2.new(0.5, 0.5)
    wing.Rotation = side == -1 and 38 or -38
    wing.BackgroundColor3 = Color3.fromRGB(255, 148, 99)
    wing.BackgroundTransparency = 0
    wing.BorderSizePixel = 0
    wing.Parent = pointer
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 2)
    corner.Parent = wing
    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(30, 23, 22)
    outline.Thickness = 1.5
    outline.Parent = wing
    table.insert(wings, {fill = wing, outline = outline})
end

local hitSource
local startedAt = 0

local function clearIndicator()
    if hitSource then RunService:UnbindFromRenderStep(RENDER_BINDING) end
    hitSource = nil
    pointer.Visible = false
end

local function updateIndicator()
    local elapsed = os.clock() - startedAt
    if elapsed >= Direction.DURATION then
        clearIndicator()
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        pointer.Visible = false
        return
    end
    local cf = camera.CFrame
    local offset = hitSource - cf.Position
    local look, right = cf.LookVector, cf.RightVector
    local x, y = Direction.project(offset.X, offset.Z, look.X, look.Z, right.X, right.Z)
    if x == nil then
        pointer.Visible = false
        return
    end

    local viewport = camera.ViewportSize
    local radius = math.clamp(math.min(viewport.X, viewport.Y) * 0.17, 52, 96)
    local position = UDim2.new(0.5, math.round(x * radius), 0.5, math.round(y * radius))
    local rotation = math.round(math.deg(math.atan2(x, -y)))
    if pointer.Position ~= position then pointer.Position = position end
    if pointer.Rotation ~= rotation then pointer.Rotation = rotation end

    local alpha = Direction.transparency(elapsed, GuiService.ReducedMotionEnabled)
    for _, wing in ipairs(wings) do
        if wing.fill.BackgroundTransparency ~= alpha then
            wing.fill.BackgroundTransparency = alpha
            wing.outline.Transparency = alpha
        end
    end
    pointer.Visible = true
end

local function showDamage(source)
    if typeof(source) ~= "Vector3" or Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then return end
    local wasActive = hitSource ~= nil
    hitSource = source
    startedAt = os.clock()
    if not wasActive then
        RunService:BindToRenderStep(RENDER_BINDING, Enum.RenderPriority.Camera.Value + 3, updateIndicator)
    end
    updateIndicator()
end

local hitConnection = nil
local boundCharacter = nil

local function releaseCharacter()
    if hitConnection then
        hitConnection:Disconnect()
        hitConnection = nil
    end
    boundCharacter = nil
    clearIndicator()
end

local function bindCharacter(character)
    releaseCharacter()
    if not character or character ~= player.Character then return end
    boundCharacter = character
    hitConnection = character:GetAttributeChangedSignal(
        "IronYardLastHitTime"):Connect(function()
        if boundCharacter ~= character or player.Character ~= character then return end
        showDamage(character:GetAttribute("IronYardLastHitPosition"))
    end)
end

local addedConnection = player.CharacterAdded:Connect(bindCharacter)
local removingConnection = player.CharacterRemoving:Connect(function(character)
    if boundCharacter == character then releaseCharacter() end
end)
if player.Character then bindCharacter(player.Character) end

local phaseConnection = Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(function()
    if Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then clearIndicator() end
end)

script.Destroying:Connect(function()
    addedConnection:Disconnect()
    removingConnection:Disconnect()
    phaseConnection:Disconnect()
    releaseCharacter()
    gui:Destroy()
end)
