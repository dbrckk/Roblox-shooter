-- IRON YARD / industrial motion is cosmetic, simulated locally.
-- Four overhead crane trolleys with coherent lift cables and tiny amber
-- warning beacons; NEVER modifies server colliders, hitboxes or navigation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Motion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GantryMotion"))
local arena = Workspace:WaitForChild("NeonStrikeArena", 30)
local decor = arena and arena:WaitForChild("NeonStrikeDecor", 30)
if not decor then
    warn("[IRON YARD] Optional gantry motion disabled: arena art unavailable")
    return
end

local rigs = setmetatable({}, { __mode = "k" })

local function register(candidate)
    if not candidate:IsA("Model")
        or candidate:GetAttribute("IronYardGantryMover") ~= true
        or rigs[candidate] then return end
    local index = candidate:GetAttribute("IronYardGantryIndex")
    if typeof(index) ~= "number" or index < 1 or index > 4 then return end
    local beacon = candidate:FindFirstChild("GANTRY / beacon " .. tostring(index), true)
    if not beacon or not beacon:IsA("BasePart") then return end
    -- GetPivot is read only once: moving this Model's offset must never
    -- accumulate drift or influence collision geometry.
    rigs[candidate] = {
        base = candidate:GetPivot(),
        index = index,
        beacon = beacon,
        light = nil,
        moving = false,
    }
end

for _, candidate in ipairs(decor:GetChildren()) do register(candidate) end
decor.ChildAdded:Connect(function(candidate)
    if candidate:IsA("Model") then
        -- Streaming may deliver child Mesh/Parts a frame after their Model.
        task.defer(register, candidate)
    end
end)
decor.DescendantAdded:Connect(function(candidate)
    if candidate:GetAttribute("IronYardGantryBeacon") then
        local parent = candidate.Parent
        if parent and parent:IsA("Model") then register(parent) end
    end
end)

local accumulated = 0
local interval = UserInputService.TouchEnabled and 1 / 15 or 1 / 24
RunService.Heartbeat:Connect(function(dt)
    accumulated += dt
    if accumulated < interval then return end
    accumulated = 0
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local cameraPosition = camera.CFrame.Position
    local quality = player:GetAttribute("IronYardGraphicsPreset") or "BALANCED"
    local elapsed = Workspace:GetServerTimeNow()

    for model, rig in pairs(rigs) do
        if not model:IsDescendantOf(decor) then
            if rig.light then rig.light:Destroy() end
            rigs[model] = nil
        else
            local distance = (rig.base.Position - cameraPosition).Magnitude
            local travel, lift, pulse = Motion.pose(elapsed, rig.index, quality, distance)
            if travel ~= 0 or lift ~= 0 then
                model:PivotTo(rig.base * CFrame.new(travel, lift, 0))
                rig.moving = true
            elseif rig.moving then
                model:PivotTo(rig.base)
                rig.moving = false
            end

            local active = pulse > 0
            rig.beacon.Transparency = active and math.clamp(0.74 - pulse * 0.68, 0.15, 0.85)
                or 0.55
            if quality == "QUALITY" and distance < 150 then
                if not rig.light then
                    -- A per-client light only when high settings and close;
                    -- no server-side dynamic lighting or replicated updates.
                    local lamp = Instance.new("PointLight")
                    lamp.Name = "LocalCraneBeaconLight"
                    lamp.Color = Color3.fromRGB(251, 175, 79)
                    lamp.Range = 11
                    lamp.Shadows = false
                    lamp.Parent = rig.beacon
                    rig.light = lamp
                end
                rig.light.Enabled = true
                rig.light.Brightness = 0.25 + pulse * 0.70
            elseif rig.light then
                rig.light.Enabled = false
            end
        end
    end
end)
