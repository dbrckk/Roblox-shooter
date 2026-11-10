-- IRON YARD / server-owned cosmetic shot recipient routing.
-- Remote packets are never trusted for hits: only WeaponService and
-- BotService call this AFTER an accepted server-authoritative shot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Audience = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("CombatFxAudience"))

local Relay = {}

local function observerPosition(viewer)
    local character = viewer.Character
    if not character or not character.Parent then return nil, false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil, false end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return nil, false end
    return root.Position, true
end

function Relay.send(remote, payload, origin, shooter)
    if not remote then return end
    local players = Players:GetPlayers()
    if #players == 0 then return end
    local recipients = {}
    for _, viewer in ipairs(players) do
        local position, active = observerPosition(viewer)
        if Audience.wants(origin, position, viewer == shooter, active) then
            recipients[#recipients + 1] = viewer
        end
    end

    -- Preserve FireAllClients for crowded fights where every listener
    -- qualifies: N FireClient calls would cost more than one broadcast.
    local mode = Audience.deliveryMode(#recipients, #players)
    if mode == "ALL" then
        remote:FireAllClients(payload)
    elseif mode == "SOME" then
        for _, viewer in ipairs(recipients) do
            if viewer.Parent == Players then
                remote:FireClient(viewer, payload)
            end
        end
    end
end

return Relay
