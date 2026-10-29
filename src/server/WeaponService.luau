local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))
local PrecisionNet = require(shared:WaitForChild("PrecisionNet"))

local SpawnService = require(script.Parent:WaitForChild("SpawnService"))
local WeaponService = {}

local remotes = nil
local playerState = {}
local started = false
local weaponRandom = Random.new()

local function getState(player)
    local state = playerState[player]
    if not state then
        state = {
            equippedWeaponId = "AssaultRifle",
            lastFireAt = {},
            magazines = {},
            reloadUntil = {},
            reloadTokens = {},
        }
        playerState[player] = state
    end

    return state
end

local function getLiveCharacter(player)
    local character = player.Character
    if not character then
        return nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not head or humanoid.Health <= 0 then
        return nil
    end

    return character, humanoid, head, root
end

local function getHumanoidFromHit(part)
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") then
            local humanoid = current:FindFirstChildOfClass("Humanoid")
            if humanoid then
                return humanoid, current
            end
        end

        current = current.Parent
    end

    return nil, nil
end

local function getAimDirection(payload)
    if typeof(payload) ~= "table" or typeof(payload.direction) ~= "Vector3" then
        return nil
    end

    local direction = payload.direction
    -- Reject non-finite client vectors before multiplying them into a server Raycast.
    for _, coordinate in ipairs({ direction.X, direction.Y, direction.Z }) do
        if coordinate ~= coordinate or math.abs(coordinate) > 1e6 then
            return nil
        end
    end
    if direction.Magnitude < 0.001 then
        return nil
    end

    return direction.Unit
end

local function makeRaycastParams(ignoreInstances)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreInstances
    params.IgnoreWater = true
    return params
end

local function sendFeedback(player, message)
    if remotes then
        remotes.WeaponFeedback:FireClient(player, message)
    end
end

local function broadcastFireFx(player, weaponId, origin)
    if not remotes then
        return
    end

    remotes.WeaponFx:FireAllClients({
        kind = "FireSound",
        shooterUserId = player.UserId,
        weaponId = weaponId,
        origin = origin,
    })
end

local function damageHit(attacker, weaponId, config, raycastResult, origin)
    if workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then
        return false
    end
    if not raycastResult then
        sendFeedback(attacker, {
            kind = "Miss",
            weaponId = weaponId,
        })
        return false
    end

    local targetHumanoid, targetCharacter = getHumanoidFromHit(raycastResult.Instance)
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        sendFeedback(attacker, {
            kind = "Miss",
            weaponId = weaponId,
        })
        return false
    end

    if targetCharacter == attacker.Character then
        return false
    end

    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    -- Only the match's combatants can be hurt by public fire requests.
    if not targetPlayer and targetCharacter:GetAttribute("IsArenaBot") ~= true then
        sendFeedback(attacker, { kind = "Miss", weaponId = weaponId })
        return false
    end
    if targetPlayer == attacker then
        return false
    end

    -- Avoid spawn-camping. Server-only protection is removed when its owner fires.
    if SpawnService.isProtected(targetCharacter) then
        sendFeedback(attacker, { kind = "Miss", weaponId = weaponId })
        return false
    end
    local headshot = raycastResult.Instance.Name == "Head"
    local damage = headshot and config.headshotDamage or config.damage
    local healthBefore = targetHumanoid.Health
    targetHumanoid:TakeDamage(damage)
    if targetPlayer and targetHumanoid.Health < healthBefore then
        targetCharacter:SetAttribute("IronYardLastHitPosition", origin)
        targetCharacter:SetAttribute("IronYardLastHitTime", workspace:GetServerTimeNow())
    end

    sendFeedback(attacker, {
        kind = "Hit",
        weaponId = weaponId,
        targetName = targetPlayer and targetPlayer.DisplayName or targetCharacter.Name,
        damage = damage,
        headshot = headshot,
        killed = healthBefore > 0 and targetHumanoid.Health <= 0,
        distance = origin and (raycastResult.Position - origin).Magnitude or 0,
    })

    -- Training targets still provide impact feedback, but cannot win PvP rounds.
    if healthBefore > 0 and targetHumanoid.Health <= 0
        and (targetPlayer ~= nil or targetCharacter:GetAttribute("IsArenaBot") == true) then
        local stats = attacker:FindFirstChild("leaderstats")
        local kills = stats and stats:FindFirstChild("Eliminations")
        if kills then kills.Value += 1 end
        remotes.KillFeed:FireAllClients({
            attacker = attacker.DisplayName,
            target = targetPlayer and targetPlayer.DisplayName or targetCharacter.Name,
            weapon = weaponId,
            headshot = headshot,
        })
    end
    return true
end

-- Client ammo is display-only: magazine counts and reload timings live here.
local function getLoaded(state, weaponId, config)
    if not config.magazineSize then return nil end
    local current = state.magazines[weaponId]
    if current == nil then
        current = config.magazineSize
        state.magazines[weaponId] = current
    end
    return current
end

local function sendAmmo(player, weaponId)
    local config = WeaponConfig.get(weaponId)
    if not config or not remotes then return end
    local state = getState(player)
    remotes.WeaponFeedback:FireClient(player, {
        kind = "Ammo", weaponId = weaponId,
        loaded = getLoaded(state, weaponId, config) or -1,
        capacity = config.magazineSize or -1,
        reloading = (state.reloadUntil[weaponId] or 0) > os.clock(),
        reloadSeconds = config.reloadSeconds or 0,
    })
end

local function cancelReload(state, weaponId)
    state.reloadTokens[weaponId] = (state.reloadTokens[weaponId] or 0) + 1
    state.reloadUntil[weaponId] = nil
end

local function reloadWeapon(player, weaponId)
    if typeof(weaponId) ~= "string" then return end
    if workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then return end
    local state = getState(player)
    local config = WeaponConfig.get(weaponId)
    if not config or not config.magazineSize or state.equippedWeaponId ~= weaponId then return end
    local character = getLiveCharacter(player)
    if not character then return end
    local loaded = getLoaded(state, weaponId, config)
    if loaded >= config.magazineSize or (state.reloadUntil[weaponId] or 0) > os.clock() then return end

    cancelReload(state, weaponId)
    local token = state.reloadTokens[weaponId]
    state.reloadUntil[weaponId] = os.clock() + config.reloadSeconds
    sendAmmo(player, weaponId)

    task.delay(config.reloadSeconds, function()
        if player.Character ~= character or state ~= playerState[player]
            or state.reloadTokens[weaponId] ~= token
            or state.equippedWeaponId ~= weaponId then return end
        local _, humanoid = getLiveCharacter(player)
        if not humanoid or workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then
            cancelReload(state, weaponId)
            sendAmmo(player, weaponId)
            return
        end
        state.magazines[weaponId] = config.magazineSize
        state.reloadUntil[weaponId] = nil
        sendAmmo(player, weaponId)
    end)
end

local function canFire(player, weaponId, config)
    local state = getState(player)
    if state.equippedWeaponId ~= weaponId then return false end
    local now = os.clock()
    if now - (state.lastFireAt[weaponId] or -math.huge) < config.fireCooldown then
        return false
    end
    if (state.reloadUntil[weaponId] or 0) > now then return false end

    local loaded = getLoaded(state, weaponId, config)
    if loaded ~= nil then
        if loaded <= 0 then
            remotes.WeaponFeedback:FireClient(player, { kind = "OutOfAmmo", weaponId = weaponId })
            sendAmmo(player, weaponId)
            return false
        end
        state.magazines[weaponId] = loaded - 1
        sendAmmo(player, weaponId)
    end
    state.lastFireAt[weaponId] = now
    return true
end

-- Server-side cone sampling: the client never selects individual pellets.
local function randomSpread(direction, spreadDegrees)
    if not spreadDegrees or spreadDegrees <= 0 then return direction end
    local theta = weaponRandom:NextNumber(0, 2 * math.pi)
    local radius = math.sqrt(weaponRandom:NextNumber()) * math.rad(spreadDegrees)
    return (CFrame.lookAt(Vector3.zero, direction)
        * CFrame.Angles(math.cos(theta) * radius, math.sin(theta) * radius, 0)).LookVector
end

local function fireRaycastWeapon(player, weaponId, config, direction)
    local character, _, head = getLiveCharacter(player)
    if not character then
        return
    end

    local origin = head.Position
    local params = makeRaycastParams({ character })
    broadcastFireFx(player, weaponId, origin)

    local result = workspace:Raycast(origin, randomSpread(direction, config.spreadDegrees) * config.range, params)
    damageHit(player, weaponId, config, result, origin)
end

local function firePelletWeapon(player, weaponId, config, direction)
    local character, _, head = getLiveCharacter(player)
    if not character then return end
    local origin = head.Position
    local params = makeRaycastParams({ character })
    local victims = {}
    broadcastFireFx(player, weaponId, origin)

    for _ = 1, config.pellets do
        local ray = workspace:Raycast(origin, randomSpread(direction, config.spreadDegrees) * config.range, params)
        if ray then
            local humanoid, model = getHumanoidFromHit(ray.Instance)
            if humanoid and humanoid.Health > 0 and model ~= character then
                local opponent = Players:GetPlayerFromCharacter(model)
                if (opponent or model:GetAttribute("IsArenaBot") == true)
                    and not SpawnService.isProtected(model) then
                    local entry = victims[humanoid]
                    if not entry then
                        entry = { model = model, player = opponent, damage = 0, headshots = 0, distance = config.range }
                        victims[humanoid] = entry
                    end
                    local headshot = ray.Instance.Name == "Head"
                    local distance = (ray.Position - origin).Magnitude
                    local falloff = math.clamp(1 - distance / config.range * 0.55, 0.45, 1)
                    entry.damage += (headshot and config.headshotDamage or config.damage) * falloff
                    if headshot then entry.headshots += 1 end
                    entry.distance = math.min(entry.distance, distance)
                end
            end
        end
    end

    local anyHit = false
    for humanoid, entry in pairs(victims) do
        if humanoid.Health > 0 and entry.model.Parent and not SpawnService.isProtected(entry.model) then
            local damage = math.max(1, math.floor(entry.damage + 0.5))
            local oldHealth = humanoid.Health
            humanoid:TakeDamage(damage)
            if entry.player and humanoid.Health < oldHealth then
                entry.model:SetAttribute("IronYardLastHitPosition", origin)
                entry.model:SetAttribute("IronYardLastHitTime", workspace:GetServerTimeNow())
            end
            local killed = oldHealth > 0 and humanoid.Health <= 0
            anyHit = true
            sendFeedback(player, {
                kind = "Hit", weaponId = weaponId,
                targetName = entry.player and entry.player.DisplayName or entry.model.Name,
                damage = damage, headshot = entry.headshots > 0,
                killed = killed, distance = entry.distance,
            })
            if killed then
                local stats = player:FindFirstChild("leaderstats")
                local score = stats and stats:FindFirstChild("Eliminations")
                if score then score.Value += 1 end
                remotes.KillFeed:FireAllClients({
                    attacker = player.DisplayName,
                    target = entry.player and entry.player.DisplayName or entry.model.Name,
                    weapon = weaponId, headshot = entry.headshots > 0,
                })
            end
        end
    end
    if not anyHit then sendFeedback(player, { kind = "Miss", weaponId = weaponId }) end
end

local function createKnifeVisual(origin, direction)
    local knife = Instance.new("Part")
    knife.Name = "PrecisionKnife"
    knife.Anchored = true
    knife.CanCollide = false
    knife.CanQuery = false
    knife.CanTouch = false
    knife.Color = Color3.fromRGB(215, 220, 226)
    knife.Material = Enum.Material.Metal
    knife.Size = Vector3.new(0.18, 0.18, 2.25)
    knife.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -1.1)
    knife.Parent = workspace
    return knife
end

local weaponRoundEpoch = 0

local function fireKnife(player, weaponId, config, direction)
    local character, _, head = getLiveCharacter(player)
    if not character then
        return
    end

    local start = head.Position
    local origin = start + direction * 2
    -- Prevent a projectile spawning beyond a wall or hitting through cover
    -- during the 2-stud muzzle offset. Close-range fighters are handled here.
    local params = makeRaycastParams({ character })
    local initialHit = workspace:Raycast(start, origin - start, params)
    if initialHit then
        broadcastFireFx(player, weaponId, start)
        damageHit(player, weaponId, config, initialHit, start)
        return
    end
    local knife = createKnifeVisual(origin, direction)
    local launchedEpoch = weaponRoundEpoch
    params.FilterDescendantsInstances = { character, knife }
    local speed = config.projectileSpeed
    local maxRange = config.range
    local lifetime = config.projectileLifetime
    broadcastFireFx(player, weaponId, origin)

    Debris:AddItem(knife, lifetime + 0.5)

    task.spawn(function()
        local elapsed = 0
        local traveled = 0
        local lastPosition = origin

        while knife.Parent and elapsed < lifetime and traveled < maxRange do
            local deltaTime = RunService.Heartbeat:Wait()
            -- Projectile tasks may outlive a round, their original owner or
            -- character. Never apply late damage in a different combat state.
            if launchedEpoch ~= weaponRoundEpoch
                or player.Character ~= character
                or workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then
                knife:Destroy()
                return
            end
            elapsed += deltaTime

            local stepDistance = math.min(speed * deltaTime, maxRange - traveled)
            local nextPosition = lastPosition + direction * stepDistance
            local result = workspace:Raycast(lastPosition, nextPosition - lastPosition, params)

            if result then
                knife.CFrame = CFrame.lookAt(result.Position, result.Position + direction) * CFrame.new(0, 0, -1.1)
                damageHit(player, weaponId, config, result, origin)
                knife:Destroy()
                return
            end

            traveled += stepDistance
            lastPosition = nextPosition
            knife.CFrame = CFrame.lookAt(lastPosition, lastPosition + direction) * CFrame.new(0, 0, -1.1)
        end

        if knife.Parent then
            knife:Destroy()
        end

        if launchedEpoch == weaponRoundEpoch and player.Character == character
            and workspace:GetAttribute("NeonMatchPhase") == "LIVE" then
            sendFeedback(player, {
                kind = "Miss",
                weaponId = weaponId,
            })
        end
    end)
end

local function onEquipWeapon(player, weaponId)
    if typeof(weaponId) ~= "string" or not WeaponConfig.isValid(weaponId) then
        return
    end

    local state = getState(player)
    if state.equippedWeaponId ~= weaponId then
        cancelReload(state, state.equippedWeaponId)
    end
    state.equippedWeaponId = weaponId
    sendAmmo(player, weaponId)
end

local function onFireWeapon(player, payload)
    if workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then
        return
    end
    if typeof(payload) ~= "table" or typeof(payload.weaponId) ~= "string" then
        return
    end

    local weaponId = payload.weaponId
    local config = WeaponConfig.get(weaponId)
    local direction = getAimDirection(payload)
    if not config or not direction then
        return
    end

    -- A dead character cannot fire or consume its rate limit.
    local liveCharacter = getLiveCharacter(player)
    if not liveCharacter then return end
    if not canFire(player, weaponId, config) then
        return
    end

    -- Shooting forfeits the temporary defensive shield; no invincible attackers.
    SpawnService.clearProtection(player.Character)
    if config.kind == "Raycast" then
        fireRaycastWeapon(player, weaponId, config, direction)
    elseif config.kind == "Pellet" then
        firePelletWeapon(player, weaponId, config, direction)
    elseif config.kind == "Projectile" then
        fireKnife(player, weaponId, config, direction)
    end
end

function WeaponService.resetRound()
    -- Invalidate in-flight knives before new rounds can accept damage.
    weaponRoundEpoch += 1
    -- All combatants start the next round with full magazines and no
    -- lingering reload or rate-limit state from the prior match.
    for player, state in pairs(playerState) do
        for id in pairs(state.reloadUntil) do cancelReload(state, id) end
        state.magazines = {}
        state.lastFireAt = {}
        if player.Parent then sendAmmo(player, state.equippedWeaponId) end
    end
end

function WeaponService.start()
    if started then
        return
    end

    started = true
    remotes = PrecisionNet.getRemotes(true)

    remotes.EquipWeapon.OnServerEvent:Connect(onEquipWeapon)
    remotes.FireWeapon.OnServerEvent:Connect(onFireWeapon)
    remotes.ReloadWeapon.OnServerEvent:Connect(reloadWeapon)

    local function watchPlayer(player)
        player.CharacterAdded:Connect(function()
            local state = getState(player)
            for id in pairs(state.reloadUntil) do cancelReload(state, id) end
            state.magazines = {}
            state.lastFireAt = {}
            task.defer(function()
                if player.Parent then sendAmmo(player, state.equippedWeaponId) end
            end)
        end)
    end
    Players.PlayerAdded:Connect(watchPlayer)
    for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end

    Players.PlayerRemoving:Connect(function(player)
        playerState[player] = nil
    end)
end

return WeaponService
