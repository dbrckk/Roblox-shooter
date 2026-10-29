-- NEON STRIKE: server-run NPC fighters with Roblox Humanoid rigs.
-- Design inspired by REA analysis of the legal MIT Arena FPS reference:
-- reactive target acquisition, bounded inaccuracy, waypoints and LOS checks.
-- No assets/scripts are copied from proprietary Roblox experiences.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("BotConfig"))
local remotes = require(shared:WaitForChild("PrecisionNet")).getRemotes(true)
local BotService = {}
local BotVisuals = require(script.Parent:WaitForChild("BotVisuals"))
local BotAnimation = require(script.Parent:WaitForChild("BotAnimation"))
local BotNavigation = require(script.Parent:WaitForChild("BotNavigation"))
local BotTactics = require(script.Parent:WaitForChild("BotTactics"))
local SpawnService = require(script.Parent:WaitForChild("SpawnService"))
local folder = nil
local slots = {}
local roundKills = {}
local started = false
local rng = Random.new()

local function createPart(model, name, size, offset, color, collide)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.Position = offset
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Anchored = false
    p.CanCollide = collide
    p.CanTouch = false
    p.Massless = name ~= "HumanoidRootPart" and name ~= "Torso"
    p.Parent = model
    return p
end

local function motor(parent, name, part0, part1, c0, c1)
    local m = Instance.new("Motor6D")
    m.Name = name
    m.Part0 = part0
    m.Part1 = part1
    m.C0 = c0
    m.C1 = c1
    m.Parent = parent
    return m
end

local function buildCharacter(slot, skill)
    -- Dynamic spawning prevents fixed-corner camping and respects new freight cover.
    local spawn = SpawnService.selectSafeSpawn(nil)
    local model = Instance.new("Model")
    model.Name = "[BOT] " .. config.BotNames[slot]
    model:SetAttribute("IsArenaBot", true)
    model:SetAttribute("BotDifficulty", skill.label)

    local base = spawn
    local root = createPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), base, Color3.new(0, 0, 0), false)
    root.Transparency = 1
    local torso = createPart(model, "Torso", Vector3.new(2, 2, 1), base, Color3.fromRGB(96, 112, 100), true)
    local head = createPart(model, "Head", Vector3.new(2, 1, 1), base + Vector3.new(0, 1.5, 0), Color3.fromRGB(75, 84, 81), false)
    local leftArm = createPart(model, "Left Arm", Vector3.new(1, 2, 1), base + Vector3.new(-1.5, 0, 0), Color3.fromRGB(126, 135, 120), false)
    local rightArm = createPart(model, "Right Arm", Vector3.new(1, 2, 1), base + Vector3.new(1.5, 0, 0), Color3.fromRGB(126, 135, 120), false)
    local leftLeg = createPart(model, "Left Leg", Vector3.new(1, 2, 1), base + Vector3.new(-0.5, -2, 0), Color3.fromRGB(72, 80, 74), false)
    local rightLeg = createPart(model, "Right Leg", Vector3.new(1, 2, 1), base + Vector3.new(0.5, -2, 0), Color3.fromRGB(72, 80, 74), false)

    local rootJoint = motor(root, "RootJoint", root, torso, CFrame.new(), CFrame.new())
    local neck = motor(torso, "Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
    local leftShoulder = motor(torso, "Left Shoulder", torso, leftArm,
        CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
    local rightShoulder = motor(torso, "Right Shoulder", torso, rightArm,
        CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
    local leftHip = motor(torso, "Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
    local rightHip = motor(torso, "Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))

    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "Humanoid"
    humanoid.BreakJointsOnDeath = false
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.WalkSpeed = skill.speed
    humanoid.UseJumpPower = true
    humanoid.JumpPower = 45
    humanoid.AutoRotate = true
    humanoid.Parent = model

    -- Rotate the full rig towards its opponent without teleporting the root.
    local facingAttachment = Instance.new("Attachment")
    facingAttachment.Name = "CombatFacing"
    facingAttachment.Parent = root
    local facing = Instance.new("AlignOrientation")
    facing.Name = "CombatOrientation"
    facing.Attachment0 = facingAttachment
    facing.Mode = Enum.OrientationAlignmentMode.OneAttachment
    facing.RigidityEnabled = false
    facing.Responsiveness = 13
    facing.MaxTorque = 26000
    facing.MaxAngularVelocity = 8
    facing.Enabled = false
    facing.Parent = root

    model.PrimaryPart = root

    -- Clear labeling is essential: AI should be visually readable, not impersonate users.
    local marker = Instance.new("BillboardGui")
    marker.Name = "BotIdentity"
    marker.Size = UDim2.fromOffset(142, 40)
    marker.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
    marker.MaxDistance = 155
    marker.AlwaysOnTop = true
    marker.Parent = head
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 24)
    title.Font = Enum.Font.GothamBold
    title.Text = model.Name
    title.TextColor3 = Color3.fromRGB(255, 224, 174)
    title.TextSize = 14
    title.TextStrokeTransparency = 0.45
    title.Parent = marker
    local function updateProtectionLabel()
        if SpawnService.isProtected(model) then
            title.Text = model.Name .. " | SAFE"
            title.TextColor3 = Color3.fromRGB(255, 222, 166)
        else
            title.Text = model.Name
            title.TextColor3 = Color3.fromRGB(236, 238, 226)
        end
    end
    local protectionRevision = 0
    model:GetAttributeChangedSignal("NeonSpawnProtectedUntil"):Connect(function()
        protectionRevision += 1
        local revision = protectionRevision
        updateProtectionLabel()
        if SpawnService.isProtected(model) then
            local deadline = model:GetAttribute("NeonSpawnProtectedUntil") or 0
            task.delay(math.max(0, deadline - Workspace:GetServerTimeNow()) + 0.07, function()
                if model.Parent and revision == protectionRevision then
                    updateProtectionLabel()
                end
            end)
        end
    end)
    local backing = Instance.new("Frame")
    backing.Position = UDim2.fromOffset(18, 27)
    backing.Size = UDim2.fromOffset(106, 6)
    backing.BackgroundColor3 = Color3.fromRGB(13, 18, 27)
    backing.BorderSizePixel = 0
    backing.Parent = marker
    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = Color3.fromRGB(114, 185, 124)
    fill.BorderSizePixel = 0
    fill.Parent = backing
    humanoid.HealthChanged:Connect(function(value)
        fill.Size = UDim2.fromScale(math.clamp(value / humanoid.MaxHealth, 0, 1), 1)
    end)

    -- The complete armor is assembled before parenting to Workspace.
    local appearance = BotVisuals.decorate(model, {
        torso = torso,
        head = head,
        leftArm = leftArm,
        rightArm = rightArm,
        leftLeg = leftLeg,
        rightLeg = rightLeg,
    }, slot)
    model.Parent = folder
    SpawnService.protectCharacter(model, 2.0)
    updateProtectionLabel()
    -- Keep NPC physics server-owned; cosmetics are massless, non-colliding parts.
    pcall(function() root:SetNetworkOwner(nil) end)
    return model, humanoid, root, head, {
        root = rootJoint,
        neck = neck,
        leftShoulder = leftShoulder,
        rightShoulder = rightShoulder,
        leftHip = leftHip,
        rightHip = rightHip,
        facing = facing,
    }, appearance
end

local function targetInfo(model)
    if not model or not model.Parent then return nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local head = model:FindFirstChild("Head")
    local root = model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not head or not root or humanoid.Health <= 0 then return nil end
    return humanoid, root, head
end

-- Target acquisition balances line-of-sight, distance and target persistence.
-- Bots no longer chase the nearest enemy through an opaque warehouse wall.
local function getTargetModel(bot, limit)
    local now = os.clock()
    local best, bestScore = nil, -math.huge
    local origin = bot.head.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { bot.model }
    params.IgnoreWater = true

    local function consider(model)
        if not model or model == bot.model or not model.Parent then return end
        if SpawnService.isProtected(model) then return end
        local humanoid, root, head = targetInfo(model)
        if not humanoid or not root or not head then return end
        local distance = (root.Position - bot.root.Position).Magnitude
        if distance > limit then return end

        -- Test the head first and the torso if crouching/cover hides it.
        -- The same physical map raycast controls actual firing.
        local direction = head.Position - origin
        local ray = Workspace:Raycast(origin, direction, params)
        local visible = ray ~= nil and ray.Instance:IsDescendantOf(model)
        if not visible then
            local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
            if torso then
                direction = torso.Position - origin
                ray = Workspace:Raycast(origin, direction, params)
                visible = ray ~= nil and ray.Instance:IsDescendantOf(model)
            end
        end
        -- If the player ducked behind cover, remember them only briefly.
        -- Otherwise switch to a visible fighter rather than wall-staring.
        local recent = model == bot.target and (now - (bot.lastTargetSeenAt or 0)) < 2.2
        if not visible and not recent then return end
        if visible and model == bot.target then
            bot.lastTargetSeenAt = now
            bot.lastKnownTargetPosition = root.Position
        end

        local score = (visible and 150 or 25) - distance * 0.58
        if model == bot.target then score += 28 end
        if score > bestScore then
            best, bestScore = model, score
            if visible then
                bot.nextVisibleTargetPosition = root.Position
            else
                bot.nextVisibleTargetPosition = nil
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        consider(player.Character)
    end
    for _, other in pairs(slots) do
        if other ~= bot then consider(other.model) end
    end
    if best and best ~= bot.target and bot.nextVisibleTargetPosition then
        bot.lastTargetSeenAt = now
        bot.lastKnownTargetPosition = bot.nextVisibleTargetPosition
    end
    return best
end

local function rayParams(ignore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { ignore }
    params.IgnoreWater = true
    return params
end

local function visibleAimPoint(bot, model)
    local _, _, head = targetInfo(model)
    if not head then return nil end
    local aimFrom = bot.head.Position
    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
    for _, p in ipairs({head, torso or head}) do
        local direction = p.Position - aimFrom
        if direction.Magnitude <= config.MaximumSightDistance then
            local hit = Workspace:Raycast(aimFrom, direction, rayParams(bot.model))
            if hit and hit.Instance:IsDescendantOf(model) then
                return p.Position
            end
        end
    end
    return nil
end

local function createBot(slot)
    local skill = config.Difficulties[slot]
    local model, humanoid, root, head, joints, appearance = buildCharacter(slot, skill)
    local bot = {
        slot = slot,
        name = model.Name,
        model = model,
        humanoid = humanoid,
        root = root,
        head = head,
        joints = joints,
        muzzle = appearance.muzzle,
        accent = appearance.accent,
        skill = skill,
        target = nil,
        lastTargetSeenAt = 0,
        lastKnownTargetPosition = nil,
        lastDamageAt = -math.huge,
        coverGoal = nil,
        coverGoalUntil = 0,
        reactionReadyAt = 0,
        nextFireAt = 0,
        ammoRemaining = config.MagazineSize,
        reloadUntil = 0,
        nextThinkAt = 0,
        nextPathAt = 0,
        pathRevision = 0,
        pathing = false,
        waypoints = nil,
        waypointIndex = 1,
        pathGoal = nil,
        strafeSign = rng:NextInteger(0, 1) == 0 and -1 or 1,
        nextStrafeAt = 0,
        aimDirection = root.CFrame.LookVector,
        kills = roundKills[slot] or 0,
        deaths = 0,
        lastShotAt = -math.huge,
        walkBlend = 0,
        aimBlend = 0,
        animationAt = os.clock(),
        lastPosition = root.Position,
        stuckSince = 0,
    }
    slots[slot] = bot
    local previousHealth = humanoid.Health
    humanoid.HealthChanged:Connect(function(value)
        if value < previousHealth and value > 0 then
            bot.lastDamageAt = os.clock()
        end
        previousHealth = value
    end)
    humanoid.Died:Connect(function()
        bot.deaths += 1
        BotNavigation.invalidate(bot)
        bot.joints.facing.Enabled = false
        -- A defeated bot must not become invisible bullet-blocking cover.
        -- Keep its visible body briefly for a readable elimination.
        for _, component in ipairs(model:GetDescendants()) do
            if component:IsA("BasePart") then
                component.CanCollide = false
                component.CanQuery = false
                component.CanTouch = false
            end
        end
        task.delay(config.DespawnAfterDeath, function()
            if slots[slot] ~= bot then return end
            slots[slot] = nil
            if model.Parent then model:Destroy() end
        end)
    end)
    return bot
end

local function steerToward(bot, desired)
    BotNavigation.steer(bot, desired, function()
        return slots[bot.slot] == bot and bot.model.Parent ~= nil and bot.humanoid.Health > 0
    end)
end

local function patrolGoal(bot)
    local points = config.PatrolPoints
    return points[(bot.slot * 3 + math.floor(os.clock() / 7)) % #points + 1]
end

local function navigationGoal(bot, target, canSee)
    local now = os.clock()
    if not target then
        BotTactics.reset(bot)
        return patrolGoal(bot)
    end
    local _, targetRoot = targetInfo(target)
    if not targetRoot then
        BotTactics.reset(bot)
        return patrolGoal(bot)
    end

    -- The only pursuit coordinate is the last verified line-of-sight
    -- position. Never substitute a hidden fighter's current root position.
    local destination = bot.lastKnownTargetPosition
    if not destination then return patrolGoal(bot) end

    if now > bot.nextStrafeAt then
        bot.strafeSign = -bot.strafeSign
        bot.nextStrafeAt = now + rng:NextNumber(1.8, 3.8)
    end

    -- Retreat and seek static cover during a reload or after taking
    -- meaningful damage; this is not an instantaneous aim or teleport.
    local defensive = BotTactics.defensiveGoal(bot, destination, now)
    if defensive then return defensive end
    if not canSee then
        return BotTactics.flankGoal(bot, destination, now) or patrolGoal(bot)
    end

    local offset = destination - bot.root.Position
    local flat = Vector3.new(offset.X, 0, offset.Z)
    local distance = flat.Magnitude
    if distance < 0.01 then return patrolGoal(bot) end
    local toward = flat.Unit
    local side = Vector3.new(-toward.Z, 0, toward.X) * bot.strafeSign
    if distance > 49 then
        return destination - toward * 26 + side * 9
    elseif distance < 16 then
        return bot.root.Position - toward * 16 + side * 10
    end
    return bot.root.Position + side * 15 + toward * (distance > 30 and 10 or -3)
end

local function shoot(bot, target, aimPoint, dt)
    local now = os.clock()
    if not aimPoint or not target then return end
    local origin = bot.muzzle.WorldPosition
    local direction = aimPoint - origin
    if direction.Magnitude < 0.01 then return end
    bot.aimDirection = bot.aimDirection:Lerp(direction.Unit, math.clamp(bot.skill.aimSpeed * dt, 0, 1))
    if bot.aimDirection.Magnitude < 0.001 then
        bot.aimDirection = direction.Unit
    end
    if now < bot.reactionReadyAt or now < bot.nextFireAt then return end
    if direction.Magnitude > config.MaximumAttackDistance then return end
    -- Do not spend ammo firing through the cover between head and muzzle.
    local muzzleBlock = Workspace:Raycast(origin, direction, rayParams(bot.model))
    if not muzzleBlock or not muzzleBlock.Instance:IsDescendantOf(target) then return end
    -- Reloading is serviced in updateBot even while the opponent is hidden.
    if bot.ammoRemaining <= 0 or bot.reloadUntil > now then return end
    bot.ammoRemaining -= 1
    bot.nextFireAt = now + bot.skill.cooldown * rng:NextNumber(0.86, 1.18)

    local errorYaw = math.rad(rng:NextNumber(-bot.skill.aimErrorDegrees, bot.skill.aimErrorDegrees))
    local errorPitch = math.rad(rng:NextNumber(-bot.skill.aimErrorDegrees, bot.skill.aimErrorDegrees))
    local look = CFrame.lookAt(Vector3.zero, bot.aimDirection) * CFrame.Angles(errorPitch, errorYaw, 0)
    local rayDirection = look.LookVector
    bot.lastShotAt = now
    -- Just like players, firing immediately forfeits spawn protection.
    SpawnService.clearProtection(bot.model)
    -- Reuse the existing client audio channel; bots remain server-controlled.
    remotes.WeaponFx:FireAllClients({
        kind = "FireSound",
        shooterUserId = 0,
        weaponId = "AssaultRifle",
        origin = origin,
    })
    local ray = Workspace:Raycast(origin, rayDirection * config.MaximumAttackDistance, rayParams(bot.model))
    -- Visual-only effects; never trusted for hit registration.
    remotes.WeaponFx:FireAllClients({
        kind = "BotTracer",
        origin = origin,
        direction = rayDirection,
        color = Color3.fromRGB(244, 202, 132),
        length = ray and (ray.Position - origin).Magnitude or config.MaximumAttackDistance,
    })
    if not ray then return end
    local hitModel = ray.Instance:FindFirstAncestorOfClass("Model")
    local humanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
    if not humanoid or hitModel == bot.model or humanoid.Health <= 0 then return end

    -- Only fighters participate: neither practice dummies nor arbitrary NPCs are targets.
    local targetPlayer = Players:GetPlayerFromCharacter(hitModel)
    if not targetPlayer and not hitModel:GetAttribute("IsArenaBot") then return end
    if SpawnService.isProtected(hitModel) then return end

    if Workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then return end
    local before = humanoid.Health
    humanoid:TakeDamage(config.Damage)
    if targetPlayer and humanoid.Health < before then
        -- Replicated server-owned combat direction for mobile/desktop HUD.
        hitModel:SetAttribute("IronYardLastHitPosition", origin)
        hitModel:SetAttribute("IronYardLastHitTime", Workspace:GetServerTimeNow())
    end
    if before > 0 and humanoid.Health <= 0 then
        bot.kills += 1
        roundKills[bot.slot] = bot.kills
        remotes.KillFeed:FireAllClients({
            attacker = bot.name,
            target = targetPlayer and targetPlayer.DisplayName or hitModel.Name,
            weapon = "VX",
            headshot = ray.Instance.Name == "Head",
        })
    end
end

local function serviceReload(bot, now)
    -- Reload state is independent of visibility and firing. Otherwise a
    -- retreating bot with an empty magazine can never finish reloading.
    if bot.ammoRemaining > 0 then return end
    if bot.reloadUntil == 0 then
        bot.reloadUntil = now + config.ReloadSeconds
    elseif now >= bot.reloadUntil then
        bot.ammoRemaining = config.MagazineSize
        bot.reloadUntil = 0
    end
end

local function updateBot(bot, dt)
    if not bot.model.Parent or bot.humanoid.Health <= 0 then return end
    local now = os.clock()
    if now < bot.nextThinkAt then return end
    bot.nextThinkAt = now + config.ThinkInterval
    serviceReload(bot, now)

    local phase = Workspace:GetAttribute("NeonMatchPhase")
    local target = phase == "LIVE" and getTargetModel(bot, config.MaximumSightDistance) or nil
    if target ~= bot.target then
        bot.target = target
        if not target then
            bot.lastKnownTargetPosition = nil
        end
        bot.reactionReadyAt = now + bot.skill.reaction
        bot.aimDirection = bot.root.CFrame.LookVector
        BotTactics.reset(bot)
        BotNavigation.invalidate(bot)
    end

    local aimPoint = target and visibleAimPoint(bot, target) or nil
    if phase == "LIVE" or phase == "COUNTDOWN" then
        steerToward(bot, navigationGoal(bot, target, aimPoint ~= nil))
    else
        bot.humanoid:MoveTo(bot.root.Position)
    end

    local currentPosition = bot.root.Position
    local moved = (currentPosition - bot.lastPosition).Magnitude
    local targetRoot = nil
    if target then
        local _, root = targetInfo(target)
        targetRoot = root
    end
    local facing = bot.joints.facing
    local shouldFace = phase == "LIVE" and aimPoint ~= nil and targetRoot ~= nil
    if shouldFace then
        local offset = targetRoot.Position - bot.root.Position
        local horizontal = Vector3.new(offset.X, 0, offset.Z)
        if horizontal.Magnitude > 2 then
            facing.CFrame = CFrame.lookAt(Vector3.zero, horizontal.Unit)
            facing.Enabled = true
            bot.humanoid.AutoRotate = false
        else
            shouldFace = false
        end
    end
    if not shouldFace then
        facing.Enabled = false
        bot.humanoid.AutoRotate = true
    end
    BotAnimation.step(bot, now, moved > 0.3, aimPoint ~= nil)
    if (phase == "LIVE" or phase == "COUNTDOWN") and moved < 0.3 then
        if bot.stuckSince == 0 then
            bot.stuckSince = now
        elseif now - bot.stuckSince > 2.3 then
            BotNavigation.invalidate(bot)
            bot.humanoid.Jump = true
            bot.stuckSince = now
        end
    else
        bot.stuckSince = 0
    end
    bot.lastPosition = currentPosition

    if phase == "LIVE" and target and aimPoint then
        shoot(bot, target, aimPoint, math.max(dt, config.ThinkInterval))
    end
end

local function reconcile()
    local humans = #Players:GetPlayers()
    local targetCount = humans > 0 and math.min(config.MaxBots, math.max(0, config.MaxCombatants - humans)) or 0
    for slot = 1, config.MaxBots do
        local bot = slots[slot]
        if slot > targetCount then
            if bot then
                slots[slot] = nil
                if bot.model.Parent then bot.model:Destroy() end
            end
            -- Retired AI must not remain a ghost leader after a human joins.
            roundKills[slot] = 0
        elseif not bot and humans > 0 then
            createBot(slot)
        end
    end
    local alive = 0
    for _, bot in pairs(slots) do
        if bot.model.Parent and bot.humanoid.Health > 0 then
            alive += 1
        end
    end
    Workspace:SetAttribute("NeonBotCount", alive)
end

-- Ranked score snapshot includes bots that are temporarily waiting to respawn.
-- This is read by MatchService only; no client can author scoring.
function BotService.getScores()
    local rows = {}
    for slot = 1, config.MaxBots do
        if slots[slot] or (roundKills[slot] or 0) > 0 then
            table.insert(rows, {
                name = "[BOT] " .. config.BotNames[slot],
                eliminations = roundKills[slot] or 0,
                bot = true,
                userId = 0,
                sortKey = slot,
            })
        end
    end
    return rows
end

function BotService.getLeader()
    local selected, best, tied = nil, -1, false
    -- Use per-slot scores so bot deaths/respawns cannot erase a match leader.
    for slot, total in pairs(roundKills) do
        if total > best then
            best = total
            selected = "[BOT] " .. config.BotNames[slot]
            tied = false
        elseif total == best then
            tied = true
        end
    end
    return selected, best, tied
end

function BotService.resetRound()
    table.clear(roundKills)
    for slot = 1, config.MaxBots do
        roundKills[slot] = 0
    end
    local rebuild = {}
    for slot, bot in pairs(slots) do
        if bot.humanoid.Health <= 0 then
            -- Do not carry dead characters into the next round. The existing
            -- delayed despawn callback checks identity before removing anything.
            slots[slot] = nil
            if bot.model.Parent then bot.model:Destroy() end
            table.insert(rebuild, slot)
        else
            bot.kills = 0
            bot.deaths = 0
            bot.ammoRemaining = config.MagazineSize
            bot.reloadUntil = 0
            bot.target = nil
            bot.lastTargetSeenAt = 0
            bot.lastKnownTargetPosition = nil
            bot.lastDamageAt = -math.huge
            BotTactics.reset(bot)
            bot.aimDirection = bot.root.CFrame.LookVector
            BotNavigation.invalidate(bot)
            bot.humanoid.Health = bot.humanoid.MaxHealth
            bot.joints.facing.Enabled = false
            bot.humanoid.AutoRotate = true
            bot.root.AssemblyLinearVelocity = Vector3.zero
            bot.root.AssemblyAngularVelocity = Vector3.zero
            bot.model:PivotTo(CFrame.new(SpawnService.selectSafeSpawn(bot.model)))
            bot.lastAnimationPosition = bot.root.Position
            bot.gaitPhase = 0
            bot.walkBlend = 0
            bot.airBlend = 0
            bot.reloadBlend = 0
            SpawnService.protectCharacter(bot.model, 2.0)
        end
    end
    for _, slot in ipairs(rebuild) do
        createBot(slot)
    end
end

function BotService.start()
    if started then return end
    started = true
    for slot = 1, config.MaxBots do
        roundKills[slot] = 0
    end
    folder = Instance.new("Folder")
    folder.Name = "NeonStrikeBots"
    folder.Parent = Workspace
    Workspace:SetAttribute("NeonBotCount", 0)
    task.spawn(function()
        while started do
            reconcile()
            task.wait(1.25)
        end
    end)
    task.spawn(function()
        local previous = os.clock()
        while started do
            local now = os.clock()
            local dt = math.clamp(now - previous, 0, 0.4)
            previous = now
            for _, bot in pairs(slots) do
                updateBot(bot, dt)
            end
            task.wait(config.ThinkInterval)
        end
    end)
end

return BotService
