-- IRON YARD / server-authoritative, session-only combat awards.
-- Cosmetics and XP never determine weapon damage, wins or matchmaking.
-- No persistent economy is implied until a separate, tested DataStore is added.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PrecisionNet = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrecisionNet"))
local CombatAwards = {}
local states = {}
local started = false
local remotes

local CHAIN_WINDOW_SECONDS = 7.0

local function stateFor(player)
    local state = states[player]
    if not state then
        state = {
            sessionXP = 0,
            roundXP = 0,
            streak = 0,
            chain = 0,
            lastEliminationAt = -math.huge,
        }
        states[player] = state
        player:SetAttribute("IronYardSessionXP", state.sessionXP)
        player:SetAttribute("IronYardRoundXP", state.roundXP)
        player:SetAttribute("IronYardKillStreak", state.streak)
    end
    return state
end

local function medalFor(chain, streak, headshot)
    if chain >= 4 then return "MULTI-KILL" end
    if chain == 3 then return "TRIPLE KILL" end
    if chain == 2 then return "DOUBLE KILL" end
    if streak == 10 then return "UNSTOPPABLE" end
    if streak == 7 then return "DOMINATING" end
    if streak == 5 then return "RAMPAGE" end
    if streak == 3 then return "ON A ROLL" end
    if headshot then return "HEADSHOT" end
    return "ELIMINATION"
end

function CombatAwards.recordElimination(player, headshot)
    if not player or not player:IsA("Player") or not player.Parent then return end
    if Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then return end
    local state = stateFor(player)
    local now = os.clock()
    if now - state.lastEliminationAt <= CHAIN_WINDOW_SECONDS then
        state.chain += 1
    else
        state.chain = 1
    end
    state.lastEliminationAt = now
    state.streak += 1
    -- Session-only XP balances regular eliminations, precision and multi-kills.
    local points = 100 + (headshot and 35 or 0)
        + math.min(75, (state.chain - 1) * 25)
        + (state.streak >= 5 and 20 or 0)
    state.roundXP += points
    state.sessionXP += points
    player:SetAttribute("IronYardRoundXP", state.roundXP)
    player:SetAttribute("IronYardSessionXP", state.sessionXP)
    player:SetAttribute("IronYardKillStreak", state.streak)
    if remotes then
        remotes.WeaponFeedback:FireClient(player, {
            kind = "CombatAward",
            medal = medalFor(state.chain, state.streak, headshot == true),
            points = points,
            roundXP = state.roundXP,
            sessionXP = state.sessionXP,
            streak = state.streak,
        })
    end
end

function CombatAwards.recordDeath(player)
    local state = states[player]
    if not state then return end
    state.streak = 0
    state.chain = 0
    state.lastEliminationAt = -math.huge
    if player.Parent then player:SetAttribute("IronYardKillStreak", 0) end
end

function CombatAwards.resetRound()
    for player, state in pairs(states) do
        state.roundXP = 0
        state.streak = 0
        state.chain = 0
        state.lastEliminationAt = -math.huge
        if player.Parent then
            player:SetAttribute("IronYardRoundXP", 0)
            player:SetAttribute("IronYardKillStreak", 0)
        end
    end
end

function CombatAwards.start()
    if started then return end
    started = true
    remotes = PrecisionNet.getRemotes(true)
    Players.PlayerAdded:Connect(stateFor)
    Players.PlayerRemoving:Connect(function(player)
        states[player] = nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        stateFor(player)
    end
end

return CombatAwards
