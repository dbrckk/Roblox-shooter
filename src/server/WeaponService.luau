local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))
local ShotInputPolicy = require(shared:WaitForChild("ShotInputPolicy"))
local FireEpochPolicy = require(shared:WaitForChild("FireEpochPolicy"))
local WeaponSpreadPolicy = require(shared:WaitForChild("WeaponSpreadPolicy"))
local DuelRoom = require(script.Parent:WaitForChild("DuelRoom"))
local DuelCombatState = require(script.Parent:WaitForChild("DuelCombatState"))
local AimStancePolicy = require(shared:WaitForChild("AimStancePolicy"))
local FeedbackPolicy = require(shared:WaitForChild("CombatFeedbackPolicy"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local PrecisionNet = require(shared:WaitForChild("PrecisionNet"))
local PracticeMode = require(shared:WaitForChild("PracticeMode"))
local PracticeRange = require(script.Parent:WaitForChild("PracticeRange"))

local SpawnService = require(script.Parent:WaitForChild("SpawnService"))
local MovementService = require(script.Parent:WaitForChild("MovementService"))
local CombatAwards = require(script.Parent:WaitForChild("CombatAwards"))
local DeathNotice = require(script.Parent:WaitForChild("DeathNotice"))
local BotHearingService = require(script.Parent:WaitForChild("BotHearingService"))
local CombatFxRelay = require(script.Parent:WaitForChild("CombatFxRelay"))
local WeaponService = {}

local remotes = nil
local playerState = {}
local practiceState = {}
local started = false
local weaponRoundEpoch = 0
local weaponRandom = Random.new()

local function getState(player)
    local states = PracticeMode.active(player) and practiceState or playerState
    local state = states[player]
    if not state then
        state = {
            equippedWeaponId = "AssaultRifle",
            lastFireAt = {},
            lastSpreadAt = {},
            spreadCount = {},
            aimSince = nil,
            aimCharacter = nil,
            aimWeaponId = nil,
            nextGlobalFireAt = 0,
            magazines = {},
            reloadUntil = {},
            reloadTokens = {},
            shotRayCharacter = nil,
            shotRayParams = nil,
        }
        states[player] = state
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

local function canUseWeapons(player)
    return PracticeMode.active(player) or workspace:GetAttribute("NeonMatchPhase") == "LIVE"
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
    -- Do not allocate a coordinate array for every remote fire request.
    -- The pure policy rejects invalid, oversized and near-zero vectors
    -- before the Roblox Vector3 normalization and server Raycast.
    if not ShotInputPolicy.validDirection(
        direction.X, direction.Y, direction.Z) then return nil end

    return direction.Unit
end

local function makeRaycastParams(ignoreInstances)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreInstances
    params.IgnoreWater = true
    return params
end

-- A new immutable RaycastParams per shot wastes allocation work during
-- automatic fire and 8-pellet shotgun bursts. Only the current character
-- is excluded, so a single set can safely serve both hitscan weapons.
-- Knife projectiles continue to use isolated params: they must also ignore
-- their own moving Part.
local function shotRaycastParams(player, character)
    local state = getState(player)
    if state.shotRayCharacter ~= character or not state.shotRayParams then
        state.shotRayParams = makeRaycastParams({ character })
        state.shotRayCharacter = character
    end
    return state.shotRayParams
end

-- Camera-space aim converges on the actual target, while the accepted damage
-- ray STILL originates at the server character's Head. Never trust a client
-- hit/target, and never shoot from an offset camera behind cover.
-- Invalid/stale camera origins (e.g. a sprinting player on a high-ping link)
-- fall back to the original head ray to avoid rejecting legitimate shots.
local function convergeCameraAim(player, payload, direction, config, character, head)
    local cameraOrigin = payload.origin
    if typeof(cameraOrigin) ~= "Vector3" then return direction end
    local offset = cameraOrigin - head.Position
    if not ShotInputPolicy.validCameraOffset(offset.X, offset.Y, offset.Z) then
        return direction
    end
    if offset.Magnitude <= 0.05 then return direction end

    local params = shotRaycastParams(player, character)
    -- Occluded cameras cannot grant a new firing position or view angle.
    if workspace:Raycast(head.Position, offset, params) then
        return direction
    end
    local cameraHit = workspace:Raycast(cameraOrigin, direction * config.range, params)
    local aimPoint = cameraHit and cameraHit.Position
        or cameraOrigin + direction * config.range
    local fromHead = aimPoint - head.Position
    if fromHead.Magnitude <= 0.05 or fromHead:Dot(direction) <= 0 then
        return direction
    end
    return fromHead.Unit
end

local function sendFeedback(player, message)
    if remotes then
        message.epoch = weaponRoundEpoch
        message.rangeSession = PracticeMode.session(player)
        remotes.WeaponFeedback:FireClient(player, message)
    end
end

-- Repeated fire against a protected player must not flood the owner with
-- 8-9 shield notifications/second on an automatic rifle.
local function sendProtected(player, weaponId)
    local state = getState(player)
    local now = os.clock()
    if now < (state.nextProtectedNoticeAt or 0) then return end
    state.nextProtectedNoticeAt = now + 0.45
    sendFeedback(player, { kind = "Protected", weaponId = weaponId })
end

local function broadcastFireFx(player, weaponId, origin, soundOnly)
    if not remotes or PracticeMode.active(player) then return end
    -- Bot hearing is recorded for every accepted server shot. Hitscan
    -- audio now travels inside PlayerTracer instead of a second broadcast.
    -- Thrown knives have no PlayerTracer, so keep their sound-only packet.
    BotHearingService.record(player.Character, weaponId, origin)
    if soundOnly then
        CombatFxRelay.send(remotes.WeaponFx, {
            kind = "FireSound",
            shooterUserId = player.UserId,
            weaponId = weaponId,
            origin = origin,
        }, origin, player)
    end
end

-- Spectator effects use server raycasts, never client-submitted hit data.
-- Send at most ONE trace for an accepted shot, including pellet weapons.
local function broadcastTrace(player, weaponId, origin, direction, range, result, pelletImpacts)
    local isWorldImpact = false
    if result then
        local humanoid = getHumanoidFromHit(result.Instance)
        isWorldImpact = humanoid == nil
    end
    local packet = {
        kind = "PlayerTracer",
        shooterUserId = player.UserId,
        epoch = weaponRoundEpoch,
        rangeSession = PracticeMode.session(player),
        weaponId = weaponId,
        origin = origin,
        direction = direction,
        length = result and (result.Position - origin).Magnitude or range,
        impactNormal = isWorldImpact and result.Normal or nil,
        impactMaterial = isWorldImpact and result.Material.Name or nil,
        pelletImpacts = pelletImpacts,
    }
    if PracticeMode.active(player) then
        remotes.WeaponFx:FireClient(player, packet)
    else
        CombatFxRelay.send(remotes.WeaponFx, packet, origin, player)
    end
end

-- Bound to exact Roblox Characters by MatchService; UserIds alone are not lives.
local function duelCanFire(player)
    if PracticeMode.active(player) then return true end
    return DuelCombatState.canFire(player,
        workspace:GetAttribute("NeonMatchPhase"),
        workspace:GetAttribute("IronYardMatchMode"), DuelRoom.combatantCount())
end

local function canDamage(attacker, targetPlayer, targetCharacter)
    if PracticeMode.active(attacker) then
        return PracticeRange.ownsTarget(attacker, targetCharacter)
    end
    if targetPlayer and PracticeMode.active(targetPlayer) then return false end
    if not targetPlayer and targetCharacter:GetAttribute("IsArenaBot") ~= true then
        return false
    end
    return DuelCombatState.canDamage(attacker, targetPlayer, targetCharacter,
        workspace:GetAttribute("NeonMatchPhase"),
        workspace:GetAttribute("IronYardMatchMode"), DuelRoom.combatantCount())
end

local function damageHit(attacker, weaponId, config, raycastResult, origin)
    if not canUseWeapons(attacker) then return false end
    if not raycastResult then return false end

    local targetHumanoid, targetCharacter = getHumanoidFromHit(raycastResult.Instance)
    if not targetHumanoid or targetHumanoid.Health <= 0 then return false end

    if targetCharacter == attacker.Character then
        return false
    end

    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    if not canDamage(attacker, targetPlayer, targetCharacter) then return false end

    -- Avoid spawn-camping. Server-only protection is removed when its owner fires.
    if SpawnService.isProtected(targetCharacter) then
        -- A confirmed hit on a protected opponent is not a miss.
        -- Do not leak target positions or names in this feedback.
        sendProtected(attacker, weaponId)
        return false
    end
    local headshot = raycastResult.Instance.Name == "Head"
    local damage = headshot and config.headshotDamage or config.damage
    local healthBefore = targetHumanoid.Health
    targetHumanoid:TakeDamage(damage)
    if targetHumanoid.Health < healthBefore then
        -- Validated human and bot hit targets publish the trusted firing
        -- origin. AI uses it for avoidance, never for through-wall shooting.
        targetCharacter:SetAttribute("IronYardLastHitPosition", origin)
        targetCharacter:SetAttribute("IronYardLastHitTime", workspace:GetServerTimeNow())
    end

    if targetHumanoid.Health >= healthBefore then return false end

    local killed = targetHumanoid.Health <= 0
    sendFeedback(attacker, {
        kind = "Hit",
        weaponId = weaponId,
        hitPosition = raycastResult.Position,
        targetName = targetPlayer and targetPlayer.DisplayName or targetCharacter.Name,
        damage = FeedbackPolicy.actualDamage(healthBefore, targetHumanoid.Health),
        headshot = headshot,
        killed = killed,
        distance = origin and (raycastResult.Position - origin).Magnitude or 0,
    })

    if killed and not PracticeMode.active(attacker) then
        local stats = attacker:FindFirstChild("leaderstats")
        local kills = stats and stats:FindFirstChild("Eliminations")
        DeathNotice.record(targetCharacter, attacker.DisplayName, weaponId, headshot)
        if kills then kills.Value += 1 end
        CombatAwards.recordElimination(attacker, headshot, weaponId)
        remotes.KillFeed:FireAllClients({
            attacker = attacker.DisplayName,
            target = targetPlayer and targetPlayer.DisplayName or targetCharacter.Name,
            weapon = weaponId,
            headshot = headshot,
        })
    end
    return true, killed
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
    local reloadRemaining = math.max(0, (state.reloadUntil[weaponId] or 0) - os.clock())
    sendFeedback(player, {
        kind = "Ammo", weaponId = weaponId,
        loaded = getLoaded(state, weaponId, config) or -1,
        capacity = config.magazineSize or -1,
        reloading = reloadRemaining > 0,
        reloadSeconds = config.reloadSeconds or 0,
        reloadEndsAt = reloadRemaining > 0 and workspace:GetServerTimeNow() + reloadRemaining or nil,
    })
end

local function cancelReload(state, weaponId)
    state.reloadTokens[weaponId] = (state.reloadTokens[weaponId] or 0) + 1
    state.reloadUntil[weaponId] = nil
end

function WeaponService.refillPracticeMagazines(player, drillMode)
    if not PracticeMode.active(player) then return end
    local state = getState(player)
    for id in pairs(state.reloadUntil) do cancelReload(state, id) end
    table.clear(state.magazines)
    if drillMode ~= PracticeMode.OPEN_DRILL and WeaponConfig.isValid(drillMode) then
        state.equippedWeaponId = drillMode
        state.aimSince = nil
        state.aimCharacter = nil
        state.aimWeaponId = nil
    end
    for _, id in ipairs(WeaponConfig.Order) do
        if WeaponConfig.get(id).magazineSize then sendAmmo(player, id) end
    end
end

function WeaponService.canEnterPractice(player, character)
    local state = getState(player)
    local lastHit = character:GetAttribute("IronYardLastHitTime") or -math.huge
    return os.clock() - (state.lastAcceptedShotAt or -math.huge) >= 5
        and workspace:GetServerTimeNow() - lastHit >= 5
end

function WeaponService.onPracticeChanged(player, enabled)
    local public = playerState[player]
    if public then
        for id in pairs(public.reloadUntil) do cancelReload(public, id) end
        public.aimSince = nil
        public.aimCharacter = nil
        public.aimWeaponId = nil
    end
    local practice = practiceState[player]
    if enabled then
        local state = getState(player)
        if public then state.equippedWeaponId = public.equippedWeaponId end
    elseif practice then
        getState(player).equippedWeaponId = practice.equippedWeaponId
        practiceState[player] = nil
    end
    sendAmmo(player, getState(player).equippedWeaponId)
end

local function reloadWeapon(player, weaponId, session)
    if not RemoteGuard.allow(player, "ReloadWeapon") then return end
    if typeof(weaponId) ~= "string" or not PracticeMode.matches(player, session) then return end
    if not canUseWeapons(player) then return end
    local state = getState(player)
    local config = WeaponConfig.get(weaponId)
    if not config or not config.magazineSize or state.equippedWeaponId ~= weaponId then return end
    local character = getLiveCharacter(player)
    if not character then return end
    local loaded = getLoaded(state, weaponId, config)
    if loaded >= config.magazineSize or (state.reloadUntil[weaponId] or 0) > os.clock() then
        -- The client may have spent a locally predicted shot that the server
        -- rejected. Reply with the actual magazine count even when there is
        -- nothing to reload, otherwise its empty HUD can remain stuck.
        sendAmmo(player, weaponId)
        return
    end

    cancelReload(state, weaponId)
    local token = state.reloadTokens[weaponId]
    state.reloadUntil[weaponId] = os.clock() + config.reloadSeconds
    sendAmmo(player, weaponId)

    task.delay(config.reloadSeconds, function()
        if player.Parent ~= Players or player.Character ~= character or state ~= getState(player)
            or not PracticeMode.matches(player, session) or state.reloadTokens[weaponId] ~= token
            or state.equippedWeaponId ~= weaponId then return end
        local _, humanoid = getLiveCharacter(player)
        if not humanoid or not canUseWeapons(player) then
            cancelReload(state, weaponId)
            sendAmmo(player, weaponId)
            return
        end
        state.magazines[weaponId] = config.magazineSize
        state.reloadUntil[weaponId] = nil
        sendAmmo(player, weaponId)
    end)
end

-- A predicted client shot can be rejected by server timing, despite both
-- sides using the same cooldown profile. Every VALID, rate-admitted
-- rejection reconciles ammo once, not a misleading hit or shot effect.
-- RemoteGuard.FireWeapon already limits spam before this helper is reached.
local function rejectFireWithAmmo(player, weaponId)
    sendAmmo(player, weaponId)
    return false
end

local function canFire(player, weaponId, config)
    local state = getState(player)
    if state.equippedWeaponId ~= weaponId then
        return rejectFireWithAmmo(player, weaponId)
    end
    local now = os.clock()
    if now - (state.lastFireAt[weaponId] or -math.huge) < config.fireCooldown then
        return rejectFireWithAmmo(player, weaponId)
    end
    -- Slot cycling cannot bypass the preceding weapon's shot cooldown.
    if now < (state.nextGlobalFireAt or 0) then
        return rejectFireWithAmmo(player, weaponId)
    end
    if (state.reloadUntil[weaponId] or 0) > now then
        return rejectFireWithAmmo(player, weaponId)
    end

    local loaded = getLoaded(state, weaponId, config)
    if loaded ~= nil then
        if loaded <= 0 then
            sendFeedback(player, { kind = "OutOfAmmo", weaponId = weaponId })
            sendAmmo(player, weaponId)
            return false
        end
        state.magazines[weaponId] = loaded - 1
        sendAmmo(player, weaponId)
    end
    state.lastFireAt[weaponId] = now
    state.lastAcceptedShotAt = now
    state.nextGlobalFireAt = WeaponConfig.nextGlobalFireAt(weaponId, now)
    return true
end

-- Only the server confirms ADS after a settled stance, live character,
-- grounded body and server movement state. Evaluated for admitted shots.
local function acceptedAimReady(player, weaponId, character, humanoid, root)
    local state = getState(player)
    if not root or state.aimCharacter ~= character
        or state.aimWeaponId ~= weaponId then return false end
    local v = root.AssemblyLinearVelocity
    local speed = Vector3.new(v.X, 0, v.Z).Magnitude
    return AimStancePolicy.ready(state.aimSince, os.clock(),
        MovementService.aimMovementAllowed(player),
        humanoid.FloorMaterial ~= Enum.Material.Air, speed)
end

-- Only after cadence/ammo admission do we advance the burst state.
-- A client cannot choose a spread value, hitbox, or burst timestamp.
local function acceptedRaycastSpread(player, weaponId, config)
    local baseline = config.spreadDegrees or 0
    if baseline <= 0 then return baseline end
    local state = getState(player)
    local now = os.clock()
    local cone, count = WeaponSpreadPolicy.next(weaponId,
        state.lastSpreadAt[weaponId], state.spreadCount[weaponId], now, baseline)
    if cone == nil then return baseline end -- safe native-weapon fallback
    state.lastSpreadAt[weaponId] = now
    state.spreadCount[weaponId] = count
    return cone
end

-- Server-side cone sampling: the client never selects individual pellets.
local function randomSpread(direction, spreadDegrees)
    if not spreadDegrees or spreadDegrees <= 0 then return direction end
    local theta = weaponRandom:NextNumber(0, 2 * math.pi)
    local radius = math.sqrt(weaponRandom:NextNumber()) * math.rad(spreadDegrees)
    return (CFrame.lookAt(Vector3.zero, direction)
        * CFrame.Angles(math.cos(theta) * radius, math.sin(theta) * radius, 0)).LookVector
end

local function fireRaycastWeapon(player, weaponId, config, direction, coneDegrees)
    local character, _, head = getLiveCharacter(player)
    if not character then
        return
    end

    local origin = head.Position
    local params = shotRaycastParams(player, character)
    broadcastFireFx(player, weaponId, origin)

    local shotDirection = randomSpread(direction, coneDegrees)
    local result = workspace:Raycast(origin, shotDirection * config.range, params)
    broadcastTrace(player, weaponId, origin, shotDirection, config.range, result)
    local hit, killed = damageHit(player, weaponId, config, result, origin)
    PracticeRange.record(player, weaponId, 1, hit and 1 or 0, killed and 1 or 0)
end

local function firePelletWeapon(player, weaponId, config, direction, coneDegrees)
    local character, _, head = getLiveCharacter(player)
    if not character then return end
    local origin = head.Position
    local params = shotRaycastParams(player, character)
    local victims = {}
    broadcastFireFx(player, weaponId, origin)
    local firstDirection = nil
    local firstResult = nil
    -- A small set of actual world contacts adds readable shotgun spread.
    -- Humanoid impacts are never broadcast in this payload.
    local extraWorldImpacts = {}
    local struckShield = false

    for pelletIndex = 1, config.pellets do
        local pelletDirection = randomSpread(direction, coneDegrees)
        local ray = workspace:Raycast(origin, pelletDirection * config.range, params)
        if not firstDirection then
            firstDirection = pelletDirection
            firstResult = ray
        end
        if ray then
            local humanoid, model = getHumanoidFromHit(ray.Instance)
            if pelletIndex > 1 and not humanoid
                and #extraWorldImpacts < 3 then
                table.insert(extraWorldImpacts, {
                    position = ray.Position,
                    normal = ray.Normal,
                    material = ray.Material.Name,
                })
            end
            if humanoid and humanoid.Health > 0 and model ~= character then
                local opponent = Players:GetPlayerFromCharacter(model)
                local damageAllowed = canDamage(player, opponent, model)
                if damageAllowed and SpawnService.isProtected(model) then
                    struckShield = true
                elseif damageAllowed then
                    local entry = victims[humanoid]
                    if not entry then
                        entry = { model = model, player = opponent, damage = 0,
                            pellets = 0, headshots = 0, distance = config.range, hitPosition = nil }
                        victims[humanoid] = entry
                    end
                    local headshot = ray.Instance.Name == "Head"
                    local distance = (ray.Position - origin).Magnitude
                    local falloff = math.clamp(1 - distance / config.range * 0.55, 0.45, 1)
                    entry.damage += (headshot and config.headshotDamage or config.damage) * falloff
                    entry.pellets += 1
                    if headshot then entry.headshots += 1 end
                    if not entry.hitPosition or distance < entry.distance then
                        entry.distance = distance
                        entry.hitPosition = ray.Position
                    end
                end
            end
        end
    end

    if firstDirection then
        broadcastTrace(player, weaponId, origin, firstDirection, config.range,
            firstResult, #extraWorldImpacts > 0 and extraWorldImpacts or nil)
    end

    local confirmedHit
    local strongestPriority = 0
    local totalDamage, pelletsHit, targetsDown = 0, 0, 0
    for humanoid, entry in pairs(victims) do
        if humanoid.Health > 0 and entry.model.Parent
            and canDamage(player, entry.player, entry.model)
            and not SpawnService.isProtected(entry.model) then
            local damage = math.max(1, math.floor(entry.damage + 0.5))
            local oldHealth = humanoid.Health
            humanoid:TakeDamage(damage)
            local killed = oldHealth > 0 and humanoid.Health <= 0
            if humanoid.Health < oldHealth then
                entry.model:SetAttribute("IronYardLastHitPosition", origin)
                entry.model:SetAttribute("IronYardLastHitTime", workspace:GetServerTimeNow())
                totalDamage += FeedbackPolicy.actualDamage(oldHealth, humanoid.Health)
                pelletsHit += entry.pellets
                if killed then targetsDown += 1 end
                local headshot = entry.headshots > 0
                local priority = killed and 3 or (headshot and 2 or 1)
                if not confirmedHit or priority > strongestPriority
                    or (priority == strongestPriority and entry.distance < confirmedHit.distance) then
                    strongestPriority = priority
                    confirmedHit = entry
                end
            end
            if killed and not PracticeMode.active(player) then
                DeathNotice.record(entry.model, player.DisplayName, weaponId, entry.headshots > 0)
                local stats = player:FindFirstChild("leaderstats")
                local score = stats and stats:FindFirstChild("Eliminations")
                if score then score.Value += 1 end
                CombatAwards.recordElimination(player, entry.headshots > 0, weaponId)
                remotes.KillFeed:FireAllClients({
                    attacker = player.DisplayName,
                    target = entry.player and entry.player.DisplayName or entry.model.Name,
                    weapon = weaponId, headshot = entry.headshots > 0,
                })
            end
        end
    end
    PracticeRange.record(player, weaponId, 1, confirmedHit and 1 or 0, targetsDown)
    -- One local cue per shell, even when it damages several opponents.
    if confirmedHit then
        local entry = confirmedHit
        sendFeedback(player, {
            kind = "Hit", weaponId = weaponId,
            hitPosition = entry.hitPosition,
            targetName = entry.player and entry.player.DisplayName or entry.model.Name,
            headshot = entry.headshots > 0, killed = strongestPriority == 3, distance = entry.distance,
            damage = totalDamage, pelletsHit = pelletsHit,
        })
    elseif struckShield then
        sendProtected(player, weaponId)
    end
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
        broadcastFireFx(player, weaponId, start, true)
        local hit, killed = damageHit(player, weaponId, config, initialHit, start)
        PracticeRange.record(player, weaponId, 1, hit and 1 or 0, killed and 1 or 0)
        return
    end
    local knife = createKnifeVisual(origin, direction)
    local launchedEpoch = weaponRoundEpoch
    local launchedSession = PracticeMode.session(player)
    local launchedInPractice = PracticeMode.active(player)
    local practiceRoom = launchedInPractice and PracticeRange.room(player)
    local launchedRevision = practiceRoom and practiceRoom.statsRevision
    local launchDrillId = launchedInPractice and PracticeRange.drillId(player)
    params.FilterDescendantsInstances = { character, knife }
    local speed = config.projectileSpeed
    local maxRange = config.range
    local lifetime = config.projectileLifetime
    broadcastFireFx(player, weaponId, origin, true)
    if launchedInPractice then
        PracticeRange.record(player, weaponId, 1, 0, 0, launchedSession, launchedRevision, launchDrillId)
    end

    Debris:AddItem(knife, lifetime + 0.5)

    task.spawn(function()
        local elapsed = 0
        local traveled = 0
        local lastPosition = origin

        while knife.Parent and elapsed < lifetime and traveled < maxRange do
            local deltaTime = RunService.Heartbeat:Wait()
            -- Projectile tasks may outlive a round, their original owner or
            -- character. Never apply late damage in a different combat state.
            if (not launchedInPractice and launchedEpoch ~= weaponRoundEpoch)
                or not PracticeMode.matches(player, launchedSession)
                or (practiceRoom and practiceRoom.statsRevision ~= launchedRevision)
                or (launchedInPractice and PracticeRange.drillId(player) ~= launchDrillId)
                or not duelCanFire(player)
                or player.Parent ~= Players
                or player.Character ~= character
                or not canUseWeapons(player) then
                knife:Destroy()
                return
            end
            elapsed += deltaTime

            local stepDistance = math.min(speed * deltaTime, maxRange - traveled)
            local nextPosition = lastPosition + direction * stepDistance
            local result = workspace:Raycast(lastPosition, nextPosition - lastPosition, params)

            if result then
                knife.CFrame = CFrame.lookAt(result.Position, result.Position + direction) * CFrame.new(0, 0, -1.1)
                local hit, killed = damageHit(player, weaponId, config, result, origin)
                if launchedInPractice and hit then
                    PracticeRange.record(player, weaponId, 0, 1, killed and 1 or 0,
                        launchedSession, launchedRevision, launchDrillId)
                end
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

        -- The projectile expired without contact; no unused Miss event.
        -- Existing authoritative Ammo and Hit feedback are unaffected.
    end)
end

local function onEquipWeapon(player, weaponId, session)
    if not RemoteGuard.allow(player, "EquipWeapon") or not PracticeMode.matches(player, session) then return end
    if typeof(weaponId) ~= "string" or not WeaponConfig.isValid(weaponId) then
        return
    end
    if not PracticeRange.permitsWeapon(player, weaponId) then return end

    local state = getState(player)
    if state.equippedWeaponId ~= weaponId then
        local previousWeaponId = state.equippedWeaponId
        local hadReload = state.reloadUntil[previousWeaponId] ~= nil
        cancelReload(state, previousWeaponId)
        if hadReload then sendAmmo(player, previousWeaponId) end
        state.aimSince = nil
        state.aimCharacter = nil
        state.aimWeaponId = nil
    end
    state.equippedWeaponId = weaponId
    sendAmmo(player, weaponId)
end

local function onSetAiming(player, enabled, session)
    if not RemoteGuard.allow(player, "SetAiming") or not PracticeMode.matches(player, session) then return end
    if typeof(enabled) ~= "boolean" then return end
    local state = getState(player)
    if not enabled then
        state.aimSince = nil
        state.aimCharacter = nil
        state.aimWeaponId = nil
        return
    end
    local phase = workspace:GetAttribute("NeonMatchPhase")
    if phase ~= "LIVE" and phase ~= "COUNTDOWN" and not PracticeMode.active(player) then return end
    local character = getLiveCharacter(player)
    local weaponId = state.equippedWeaponId
    local definition = WeaponConfig.get(weaponId)
    if not character or not definition
        or not (definition.aimFov or definition.zoomFieldOfView) then
        return
    end
    -- Repeated requests cannot bypass the settling delay.
    if state.aimCharacter == character and state.aimWeaponId == weaponId then
        return
    end
    state.aimCharacter = character
    state.aimWeaponId = weaponId
    state.aimSince = os.clock()
end

local function onFireWeapon(player, payload)
    if not RemoteGuard.allow(player, "FireWeapon") then return end
    if workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" and not PracticeMode.active(player) then
        return
    end
    if typeof(payload) ~= "table" or typeof(payload.weaponId) ~= "string"
        or not PracticeMode.matches(player, payload.rangeSession) then
        return
    end

    if not duelCanFire(player) then return end
    local weaponId = payload.weaponId
    local config = WeaponConfig.get(weaponId)
    local direction = getAimDirection(payload)
    if not config or not direction then
        return
    end

    -- Do not admit an in-flight packet from the preceding FFA round or
    -- duel bout after a new LIVE phase reopens. Invalid/stale packets
    -- cannot consume shots, ammo, cooldown, or spawn protection.
    if not FireEpochPolicy.matches(payload.epoch, weaponRoundEpoch) then
        -- Legitimate high-latency clients may still have an older
        -- replicated epoch. Send a versioned magazine snapshot so the
        -- HUD recovers without fabricating a hit or tracer.
        sendAmmo(player, weaponId)
        return
    end

    -- A dead character cannot fire or consume its rate limit.
    local liveCharacter, liveHumanoid, liveHead, liveRoot = getLiveCharacter(player)
    if not liveCharacter then return end
    if PracticeMode.active(player) then
        if not PracticeRange.contains(player, liveHead.Position) then return end
        if not PracticeRange.permitsFire(player, payload.rangeDrill) or not PracticeRange.permitsWeapon(player, weaponId) then
            sendAmmo(player, weaponId)
            return
        end
    end
    if not canFire(player, weaponId, config) then
        return
    end
    -- Only ACCEPTED shots may spend extra camera-convergence raycasts.
    -- Rejected spam, empty magazines and reloads do not perform them.
    direction = convergeCameraAim(player, payload, direction, config,
        liveCharacter, liveHead)

    -- Shooting forfeits the temporary defensive shield; no invincible attackers.
    SpawnService.clearProtection(player.Character)
    if config.kind == "Raycast" then
        local coneDegrees = acceptedRaycastSpread(player, weaponId, config)
        local aimed = acceptedAimReady(player, weaponId,
            liveCharacter, liveHumanoid, liveRoot)
        local adjusted = AimStancePolicy.cone(weaponId, coneDegrees, aimed)
        fireRaycastWeapon(player, weaponId, config, direction, adjusted or coneDegrees)
    elseif config.kind == "Pellet" then
        local aimed = acceptedAimReady(player, weaponId,
            liveCharacter, liveHumanoid, liveRoot)
        local adjusted = AimStancePolicy.cone(weaponId, config.spreadDegrees, aimed)
        firePelletWeapon(player, weaponId, config, direction,
            adjusted or config.spreadDegrees)
    elseif config.kind == "Projectile" then
        fireKnife(player, weaponId, config, direction)
    end
end

function WeaponService.resetRound()
    BotHearingService.resetRound()
    -- Invalidate in-flight knives before new rounds can accept damage.
    weaponRoundEpoch += 1
    workspace:SetAttribute("IronYardFireEpoch", weaponRoundEpoch)
    -- All combatants start the next round with full magazines and no
    -- lingering reload or rate-limit state from the prior match.
    for player, state in pairs(playerState) do
        for id in pairs(state.reloadUntil) do cancelReload(state, id) end
        state.magazines = {}
        state.lastFireAt = {}
        state.lastAcceptedShotAt = nil
        state.lastSpreadAt = {}
        state.spreadCount = {}
        state.aimSince = nil
        state.aimCharacter = nil
        state.aimWeaponId = nil
        state.nextGlobalFireAt = 0
        state.nextProtectedNoticeAt = nil
        if player.Parent and not PracticeMode.active(player) then
            sendAmmo(player, state.equippedWeaponId)
        end
    end
    for player, state in pairs(practiceState) do
        if player.Parent then sendAmmo(player, state.equippedWeaponId) end
    end
end

function WeaponService.start()
    if started then
        return
    end

    started = true
    -- Practice can start in the lobby before the first FFA round.
    weaponRoundEpoch += 1
    workspace:SetAttribute("IronYardFireEpoch", weaponRoundEpoch)
    remotes = PrecisionNet.getRemotes(true)

    remotes.EquipWeapon.OnServerEvent:Connect(onEquipWeapon)
    remotes.SetAiming.OnServerEvent:Connect(onSetAiming)
    remotes.FireWeapon.OnServerEvent:Connect(onFireWeapon)
    remotes.ReloadWeapon.OnServerEvent:Connect(reloadWeapon)

    local function watchPlayer(player)
        player.CharacterAdded:Connect(function()
            local state = getState(player)
            for id in pairs(state.reloadUntil) do cancelReload(state, id) end
            state.magazines = {}
            state.lastFireAt = {}
            state.lastSpreadAt = {}
            state.spreadCount = {}
            state.aimSince = nil
            state.aimCharacter = nil
            state.aimWeaponId = nil
            state.shotRayCharacter = nil
            state.shotRayParams = nil
            -- Respawn deliberately keeps the prior global shot deadline.
            task.defer(function()
                if player.Parent then sendAmmo(player, state.equippedWeaponId) end
            end)
        end)
        player.CharacterRemoving:Connect(function(character)
            local state = (PracticeMode.active(player) and practiceState or playerState)[player]
            if state and state.shotRayCharacter == character then
                state.shotRayCharacter = nil
                state.shotRayParams = nil
            end
        end)
    end
    Players.PlayerAdded:Connect(watchPlayer)
    for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end

    Players.PlayerRemoving:Connect(function(player)
        playerState[player] = nil
        practiceState[player] = nil
    end)
end

return WeaponService
