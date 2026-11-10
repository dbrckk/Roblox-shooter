-- IRON YARD / server-owned cosmetic shot recipient routing.
-- No client can author the recipients, weapon origin, damage or AI hearing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Audience = require(ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("CombatFxAudience"))

local Relay = {}
local roster = {}
local rosterAt = nil
local rosterDirty = true

local function invalidateRoster()
    -- Discard references to players/characters immediately on join/leave.
    roster = {}
    rosterDirty = true
end

Players.PlayerAdded:Connect(invalidateRoster)
Players.PlayerRemoving:Connect(invalidateRoster)

local function refreshRoster()
    local now = os.clock()
    if not Audience.needsRosterRefresh(now, rosterAt, rosterDirty) then
        return roster
    end

    -- The expensive Instance lookups happen at most every 150ms, not for
    -- every bot/rifle shot. Roots and health are NEVER snapshotted:
    -- movement, death and active/spectator changes are read at dispatch.
    local fresh = {}
    for _, viewer in ipairs(Players:GetPlayers()) do
        local character = viewer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        fresh[#fresh + 1] = {
            viewer = viewer,
            character = character,
            humanoid = humanoid,
            root = root and root:IsA("BasePart") and root or nil,
        }
    end
    roster = fresh
    rosterAt = now
    rosterDirty = false
    return roster
end

local function observerPosition(entry)
    local viewer = entry.viewer
    local character = entry.character
    if viewer.Character ~= character then
        -- Fail open for a replaced character, and rebuild before next shot.
        rosterDirty = true
        return nil, false
    end
    if not character or not character.Parent then return nil, false end
    local humanoid = entry.humanoid
    local root = entry.root
    if not humanoid or humanoid.Parent ~= character
        or not root or root.Parent ~= character then
        rosterDirty = true
        return nil, false
    end
    if humanoid.Health <= 0 then return nil, false end
    return root.Position, true
end

function Relay.send(remote, payload, origin, shooter)
    if not remote then return end
    local players = refreshRoster()
    if #players == 0 then return end
    local recipients = {}
    for _, entry in ipairs(players) do
        local viewer = entry.viewer
        local position, active = observerPosition(entry)
        if Audience.wants(origin, position, viewer == shooter, active) then
            recipients[#recipients + 1] = viewer
        end
    end

    -- If all listeners qualify, keep Roblox's single broadcast primitive.
    -- In split lobbies only, dispatch to nearby active participants and
    -- to all spectators/respawning players (unknown camera position).
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
