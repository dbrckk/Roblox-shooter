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
        active = nil,
        lastPreset = nil,
        nextUpdateAt = 0,
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
local isTouch = UserInputService.TouchEnabled
local interval = UserInputService.TouchEnabled and 1 / 15 or 1 / 24
RunService.Heartbeat:Connect(function(dt)
    accumulated += dt
    if accumulated < interval then return end
    -- Drop excess backlog after a slow frame, never burst animations to
    -- catch up with old positions. Individual rigs track their own cadence.
    accumulated = math.min(accumulated - interval, interval)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local cameraPosition = camera.CFrame.Position
    local quality = player:GetAttribute("IronYardGraphicsPreset") or "BALANCED"
    local now = os.clock()
    local elapsed = nil -- GetServerTimeNow is needed only if a rig actually animates.

    for model, rig in pairs(rigs) do
        if not model:IsDescendantOf(decor)
            or not rig.beacon:IsDescendantOf(model) then
            -- Streaming can remove only the beacon and leave the rig Model.
            -- Remove its local light; the DescendantAdded hook re-registers
            -- the replacement beacon when it becomes available again.
            if model:IsDescendantOf(decor) and rig.moving then
                model:PivotTo(rig.base)
            end
            if rig.light then rig.light:Destroy() end
            rigs[model] = nil
        else
            local offset = rig.base.Position - cameraPosition
            local distanceSquared = offset:Dot(offset)
            local period, active = Motion.sampleInterval(
                quality, isTouch, distanceSquared)
            local modeChanged = rig.active ~= active or rig.lastPreset ~= quality
            rig.active = active
            rig.lastPreset = quality
            if modeChanged then rig.nextUpdateAt = 0 end

            if not active then
                -- ECO and fully culled cranes are reset only once. Avoid
                -- reparenting, PivotTo, opacity changes and dynamic lights
                -- on every Heartbeat for an already-inactive distant rig.
                if rig.moving then
                    model:PivotTo(rig.base)
                    rig.moving = false
                end
                if modeChanged then rig.beacon.Transparency = 0.55 end
                if rig.light and rig.light.Enabled then
                    rig.light.Enabled = false
                end
            elseif now + 0.004 >= rig.nextUpdateAt then
                rig.nextUpdateAt = now + period
                if not elapsed then elapsed = Workspace:GetServerTimeNow() end
                local distance = math.sqrt(distanceSquared)
                local travel, lift, pulse = Motion.pose(elapsed, rig.index, quality, distance)
                if travel ~= 0 or lift ~= 0 then
                    model:PivotTo(rig.base * CFrame.new(travel, lift, 0))
                    rig.moving = true
                elseif rig.moving then
                    model:PivotTo(rig.base)
                    rig.moving = false
                end

                rig.beacon.Transparency =
                    math.clamp(0.74 - pulse * 0.68, 0.15, 0.85)
                -- Mobile QUALITY keeps the illuminated amber material,
                -- but does not allocate a costly dynamic PointLight.
                if not isTouch and quality == "QUALITY" and distance < 150 then
                    if not rig.light then
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
                elseif rig.light and rig.light.Enabled then
                    rig.light.Enabled = false
                end
            elseif rig.light and rig.light.Enabled and
                (isTouch or quality ~= "QUALITY" or distanceSquared >= 150 * 150) then
                -- Disable lighting immediately when the camera leaves the
                -- near light range, even on a reduced-frequency animation.
                rig.light.Enabled = false
            end
        end
    end
end)
