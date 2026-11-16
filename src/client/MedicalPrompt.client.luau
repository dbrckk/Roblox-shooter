-- Keep the native Roblox interaction and show it only to an injured local player.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SupplyRules"))

local player = Players.LocalPlayer
local character
local humanoid
local connections = {}
local characterConnections = {}
local healthConnections = {}
local watchedPrompts = {}

local function disconnectAll(list)
    for _, connection in ipairs(list) do
        connection:Disconnect()
    end
    table.clear(list)
end

local function serverReady(prompt)
    return prompt:GetAttribute(Rules.PROMPT_READY_ATTRIBUTE) == true
end

local function refreshPrompt(prompt, actionText)
    local visible = serverReady(prompt) and actionText ~= nil
    if visible and prompt.ActionText ~= actionText then
        prompt.ActionText = actionText
    end
    if prompt.Enabled ~= visible then
        prompt.Enabled = visible
    end
end

local function recoverActionText()
    if not humanoid or humanoid.Parent ~= character then return nil end
    local health, maxHealth = humanoid.Health, humanoid.MaxHealth
    if not Rules.needsHeal(health, maxHealth) then return nil end
    local _, amount = Rules.healedHealth(health, maxHealth)
    return "RECOVER " .. Rules.formatHealAmount(amount)
end

local function refreshPrompts()
    local actionText = recoverActionText()
    for prompt in pairs(watchedPrompts) do
        refreshPrompt(prompt, actionText)
    end
end

local function unwatch(prompt)
    local signals = watchedPrompts[prompt]
    if not signals then return end
    disconnectAll(signals)
    watchedPrompts[prompt] = nil
    -- Restore the server's presentation if this script or its tag is removed.
    if prompt.Parent then
        prompt.ActionText = "RECOVER " .. Rules.formatHealAmount(Rules.HEAL_AMOUNT)
        prompt.Enabled = serverReady(prompt)
    end
end

local function watch(prompt)
    if not prompt:IsA("ProximityPrompt") or watchedPrompts[prompt] then return end
    local function refresh()
        if watchedPrompts[prompt] then refreshPrompt(prompt, recoverActionText()) end
    end
    watchedPrompts[prompt] = {
        prompt:GetAttributeChangedSignal(Rules.PROMPT_READY_ATTRIBUTE):Connect(refresh),
        -- Server replication may update Enabled after the readiness attribute.
        prompt:GetPropertyChangedSignal("Enabled"):Connect(refresh),
    }
    refresh()
end

local function bindHumanoid()
    disconnectAll(healthConnections)
    humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        table.insert(healthConnections, humanoid.HealthChanged:Connect(refreshPrompts))
        table.insert(healthConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refreshPrompts))
    end
    refreshPrompts()
end

local function bindCharacter(nextCharacter)
    disconnectAll(characterConnections)
    character = nextCharacter
    if character then
        local function onChildChanged(child)
            if child:IsA("Humanoid") then bindHumanoid() end
        end
        table.insert(characterConnections, character.ChildAdded:Connect(onChildChanged))
        table.insert(characterConnections, character.ChildRemoved:Connect(onChildChanged))
    end
    bindHumanoid()
end

table.insert(connections, CollectionService:GetInstanceAddedSignal(Rules.PROMPT_TAG):Connect(watch))
table.insert(connections, CollectionService:GetInstanceRemovedSignal(Rules.PROMPT_TAG):Connect(unwatch))
table.insert(connections, player.CharacterAdded:Connect(bindCharacter))
table.insert(connections, player.CharacterRemoving:Connect(function(removed)
    if removed == character then bindCharacter(nil) end
end))
bindCharacter(player.Character)

for _, prompt in ipairs(CollectionService:GetTagged(Rules.PROMPT_TAG)) do
    watch(prompt)
end

script.Destroying:Connect(function()
    disconnectAll(connections)
    disconnectAll(characterConnections)
    disconnectAll(healthConnections)
    for prompt in pairs(watchedPrompts) do
        unwatch(prompt)
    end
end)
