local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(shared:WaitForChild("MovementConfig"))
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))
local PrecisionNet = require(shared:WaitForChild("PrecisionNet"))
local HudController = require(script:WaitForChild("HudController"))
local WeaponVisuals = require(script:WaitForChild("WeaponVisuals"))

local remotes = PrecisionNet.getRemotes(false)
local currentWeaponId = "AssaultRifle"
local scoped = false
local sprinting = false
local localBoostFuel = MovementConfig.boostFuelMax
local baseFieldOfView = 70
local mouseSensitivity = 1
local lastLocalFire = {}
local ammoByWeapon = {}
local lastReloadRequestAt = -math.huge
local lastLocalSlideAt = -math.huge
local lastLocalSlideJumpAt = -math.huge
local lastLocalBoostAt = -math.huge
local lastLocalWallRunRequestAt = -math.huge
local lastLocalWallRunUpdateAt = -math.huge
local lastLocalMantleAt = -math.huge
local lastJumpActionAt = -math.huge
local lastGroundedAt = os.clock()
local lastBoostUpdateAt = -math.huge
local localSlidingUntil = -math.huge
local localBoosting = false
local localBoostStartedAt = -math.huge
local localWallRunning = false
local localWallSide = nil
local localWallNormal = nil
local localWallDirection = nil
local localWallRunStartedAt = -math.huge
local localWallRunStartVerticalSpeed = 0
local localWallRunSpeed = 0
local cameraRoll = 0
local hud = nil

local UP = Vector3.new(0, 1, 0)

local existingGui = playerGui:FindFirstChild("PrecisionHud")
if existingGui then
	existingGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "PrecisionHud"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function getCamera()
	return workspace.CurrentCamera
end

local function applyMouseSensitivity()
	pcall(function()
		UserInputService.MouseDeltaSensitivity = mouseSensitivity
	end)
end

local function applyCameraFov()
	local camera = getCamera()
	if camera and not scoped then
		camera.FieldOfView = baseFieldOfView
	end
end

local function applyMenuMouseState(isOpen)
	if isOpen then
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		UserInputService.MouseIconEnabled = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end

hud = HudController.new(player, gui, WeaponConfig, {
	baseFov = baseFieldOfView,
	mouseSensitivity = mouseSensitivity,
	onFovChanged = function(fov)
		baseFieldOfView = fov
		applyCameraFov()
	end,
	onMouseSensitivityChanged = function(sensitivity)
		mouseSensitivity = sensitivity
		applyMouseSensitivity()
	end,
	onSettingsOpenChanged = function(isOpen)
		applyMenuMouseState(isOpen)
	end,
})

local visuals = WeaponVisuals.new(WeaponConfig)

local function enforceFirstPerson()
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	applyMenuMouseState(hud and hud:isSettingsOpen() or false)
	applyMouseSensitivity()
	applyCameraFov()
end

local function getCharacterParts()
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function isGrounded(humanoid)
	return humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
end

local function getFlatCameraVectors()
	local camera = getCamera()
	if not camera then
		return Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
	end

	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)

	if forward.Magnitude < 0.05 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	if right.Magnitude < 0.05 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end

	return forward, right
end

local function getInputMoveDirection()
	local forward, right = getFlatCameraVectors()
	local direction = Vector3.new(0, 0, 0)

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		direction += forward
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		direction -= forward
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		direction += right
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		direction -= right
	end

	if direction.Magnitude < 0.05 then
		return nil
	end

	return direction.Unit
end

local function getMoveDirection()
	local inputDirection = getInputMoveDirection()
	if inputDirection then
		return inputDirection
	end

	local forward = getFlatCameraVectors()
	return forward
end

local function makeMovementRaycastParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace.CurrentCamera }
	params.IgnoreWater = true
	return params
end

local function isWallRunnable(part)
	return part and part:GetAttribute("WallRunnable") == true
end

local function isMantleTarget(part)
	return part and (part:GetAttribute("MantleTarget") == true or part:GetAttribute("WallRunnable") == true)
end

local function applyLocalMoveSpeed()
	local _, humanoid = getCharacterParts()
	if not humanoid then
		return
	end

	if localWallRunning then
		humanoid.WalkSpeed = localWallRunSpeed > 0 and localWallRunSpeed or MovementConfig.wallRunSpeed
	elseif os.clock() < localSlidingUntil then
		humanoid.WalkSpeed = MovementConfig.slideSpeed
	else
		humanoid.WalkSpeed = sprinting and MovementConfig.sprintSpeed or MovementConfig.walkSpeed
	end
end

-- Cache parts when the character streams in. Roblox's camera transparency
-- controller can overwrite LocalTransparencyModifier each render frame, so
-- only the cached parts (not GetDescendants) are reconciled after camera updates.
local visibleRig = nil
local visibleRigConnection = nil
local visibleRigParts = {}

local function addFirstPersonPart(part)
    if not part:IsA("BasePart") then return end
    local name = string.lower(part.Name)
    local isArm = string.find(name, "arm") ~= nil or string.find(name, "hand") ~= nil
    local hide = part.Name == "Head" or part.Name == "HumanoidRootPart" or isArm
        or part:FindFirstAncestorWhichIsA("Accessory") ~= nil
    table.insert(visibleRigParts, { part = part, transparency = hide and 1 or 0 })
end

local function ensureBodyVisibility(character)
    if visibleRig == character then return end
    if visibleRigConnection then
        visibleRigConnection:Disconnect()
        visibleRigConnection = nil
    end
    visibleRig = character
    table.clear(visibleRigParts)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        addFirstPersonPart(part)
    end
    visibleRigConnection = character.DescendantAdded:Connect(addFirstPersonPart)
end

local function showLocalBody()
    local character, humanoid = getCharacterParts()
    ensureBodyVisibility(character)
    if not humanoid then return end

    for _, entry in ipairs(visibleRigParts) do
        local part = entry.part
        if part.Parent and part.LocalTransparencyModifier ~= entry.transparency then
            part.LocalTransparencyModifier = entry.transparency
        end
    end

    local offset = Vector3.new(0, -0.05, -0.45)
    if os.clock() < localSlidingUntil then
        offset = Vector3.new(0, -0.55, -0.52)
    elseif localWallRunning then
        local sideOffset = localWallSide == "Left" and 0.22 or -0.22
        offset = Vector3.new(sideOffset, -0.08, -0.48)
    end
    humanoid.CameraOffset = offset
end

local function setSprinting(enabled)
	if sprinting == enabled then
		return
	end

	sprinting = enabled
	applyLocalMoveSpeed()
	visuals:setSprinting(sprinting)
	remotes.SetSprinting:FireServer(sprinting)
end

local function requestSlide()
	local _, humanoid, root = getCharacterParts()
	local now = os.clock()
	if not sprinting or not humanoid or not root or not isGrounded(humanoid) or now - lastLocalSlideAt < MovementConfig.slideCooldown then
		return
	end

	local direction = getMoveDirection()
	lastLocalSlideAt = now
	localSlidingUntil = now + MovementConfig.slideDuration
	root.AssemblyLinearVelocity = Vector3.new(
		direction.X * MovementConfig.slideSpeed,
		math.max(root.AssemblyLinearVelocity.Y, MovementConfig.slideHop),
		direction.Z * MovementConfig.slideSpeed
	)
	humanoid.WalkSpeed = MovementConfig.slideSpeed

	task.delay(MovementConfig.slideDuration, function()
		applyLocalMoveSpeed()
	end)

	remotes.MovementAction:FireServer({
		action = "Slide",
		direction = direction,
	})
end

local function requestSlideJump()
	local _, humanoid, root = getCharacterParts()
	local now = os.clock()
	local canSlideJump = now <= localSlidingUntil + MovementConfig.slideJumpWindow
	if not humanoid or not root or not canSlideJump or now - lastLocalSlideJumpAt < MovementConfig.slideJumpCooldown then
		return false
	end

	local direction = getMoveDirection()
	lastLocalSlideJumpAt = now
	localSlidingUntil = -math.huge
	root.AssemblyLinearVelocity = Vector3.new(
		direction.X * MovementConfig.slideJumpForwardSpeed,
		MovementConfig.slideJumpUpSpeed,
		direction.Z * MovementConfig.slideJumpForwardSpeed
	)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	applyLocalMoveSpeed()

	remotes.MovementAction:FireServer({
		action = "SlideJump",
		direction = direction,
	})

	return true
end

local function startBoosting()
	local _, humanoid, root = getCharacterParts()
	local now = os.clock()
	if not humanoid or not root or isGrounded(humanoid) or localWallRunning or localBoostFuel < MovementConfig.boostFuelMinToStart or now - lastGroundedAt < MovementConfig.boostStartDelay or now - lastLocalBoostAt < MovementConfig.boostCooldown then
		return false
	end

	if localBoosting then
		return true
	end

	localBoosting = true
	localBoostStartedAt = now
	lastLocalBoostAt = now
	lastBoostUpdateAt = now

	local direction = getInputMoveDirection()
	hud:setBoostFuel(localBoostFuel / MovementConfig.boostFuelMax)

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	remotes.MovementAction:FireServer({
		action = "BoostStart",
		direction = direction,
	})

	return true
end

local function stopBoosting()
	if not localBoosting then
		return
	end

	localBoosting = false
	localBoostStartedAt = -math.huge
	remotes.MovementAction:FireServer({
		action = "BoostStop",
	})
end

local function lerpNumber(a, b, alpha)
	return a + (b - a) * alpha
end

local function getBoostThrottle()
	local heldTime = math.max(0, os.clock() - localBoostStartedAt)
	local ramp = math.clamp(heldTime / MovementConfig.boostFeatherRampTime, 0, 1)
	local throttle = lerpNumber(MovementConfig.boostFeatherMinThrottle, 1, ramp)
	return throttle, ramp
end

local function moveVectorToward(current, target, maxDelta)
	local offset = target - current
	local distance = offset.Magnitude
	if distance <= maxDelta or distance < 0.001 then
		return target
	end

	return current + offset.Unit * maxDelta
end

local function getAirControlSpeed(currentSpeed)
	if currentSpeed > MovementConfig.airControlMaxSpeed then
		return currentSpeed
	end

	return math.clamp(currentSpeed, MovementConfig.airControlBaseSpeed, MovementConfig.airControlMaxSpeed)
end

local function getBoostGravityAssist()
	return workspace.Gravity * math.max(0, 1 - MovementConfig.boostGravityMultiplier)
end

local function getWallHit(side)
	local character, _, root = getCharacterParts()
	if not character or not root then
		return nil
	end

	local sideDirection = root.CFrame.RightVector
	if side == "Left" then
		sideDirection = -sideDirection
	end

	return workspace:Raycast(root.Position, sideDirection * MovementConfig.wallRunRayDistance, makeMovementRaycastParams(character))
end

local function getWallDirection(normal, desiredDirection)
	local alongWall = normal:Cross(UP)
	if alongWall.Magnitude < 0.05 then
		return desiredDirection
	end

	alongWall = Vector3.new(alongWall.X, 0, alongWall.Z).Unit
	if alongWall:Dot(desiredDirection) < 0 then
		alongWall = -alongWall
	end

	return alongWall
end

local function isWallRunDirectionValid(normal, desiredDirection, wallDirection)
	if not desiredDirection or desiredDirection.Magnitude < 0.05 then
		return false
	end

	if desiredDirection:Dot(wallDirection) < MovementConfig.wallRunMinInputDot then
		return false
	end

	return desiredDirection:Dot(normal) <= MovementConfig.wallRunTurnAwayDot
end

local function getWallRunStartInfo(root, hit, desiredDirection)
	if not desiredDirection or desiredDirection.Magnitude < 0.05 then
		return nil
	end

	local flatVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local speed = flatVelocity.Magnitude
	if speed < MovementConfig.wallRunMinSpeed then
		return nil
	end

	local velocityDirection = flatVelocity.Unit
	local wallDirection = getWallDirection(hit.Normal, desiredDirection)
	local approachDot = velocityDirection:Dot(-hit.Normal)
	local alongDot = math.abs(velocityDirection:Dot(wallDirection))
	if approachDot < MovementConfig.wallRunMinApproachDot or approachDot > MovementConfig.wallRunMaxApproachDot then
		return nil
	end
	if alongDot < MovementConfig.wallRunMinAlongDot or not isWallRunDirectionValid(hit.Normal, desiredDirection, wallDirection) then
		return nil
	end

	return wallDirection, speed
end

local function getWallRunVerticalSpeed(startedAt, startVerticalSpeed, now)
	local dropTime = math.max(0.001, MovementConfig.wallRunDuration - MovementConfig.wallRunDropDelay)
	local dropAlpha = math.clamp((now - startedAt - MovementConfig.wallRunDropDelay) / dropTime, 0, 1)
	return lerpNumber(startVerticalSpeed, MovementConfig.wallRunEndVerticalSpeed, dropAlpha)
end

local function getWallRunStartVerticalSpeed(root)
	return math.clamp(
		root.AssemblyLinearVelocity.Y,
		MovementConfig.wallRunEndVerticalSpeed,
		MovementConfig.wallRunStartVerticalSpeed
	)
end

local function stopLocalWallRun(shouldTellServer)
	if not localWallRunning then
		return
	end

	localWallRunning = false
	localWallSide = nil
	localWallNormal = nil
	localWallDirection = nil
	localWallRunStartedAt = -math.huge
	localWallRunStartVerticalSpeed = 0
	localWallRunSpeed = 0
	applyLocalMoveSpeed()

	if shouldTellServer then
		remotes.MovementAction:FireServer({
			action = "StopWallRun",
		})
	end
end

local function tryStartWallRun()
	local _, humanoid, root = getCharacterParts()
	local now = os.clock()
	if not humanoid or not root or localWallRunning or isGrounded(humanoid) or now - lastLocalWallRunRequestAt < 0.12 then
		return
	end

	local desiredDirection = getInputMoveDirection()
	if not desiredDirection then
		return
	end

	for _, side in ipairs({ "Left", "Right" }) do
		local hit = getWallHit(side)
		if hit and isWallRunnable(hit.Instance) then
			local wallDirection, entrySpeed = getWallRunStartInfo(root, hit, desiredDirection)
			if wallDirection then
				local runSpeed = math.clamp(entrySpeed, MovementConfig.wallRunSpeed, MovementConfig.wallRunMaxSpeed)
				local startVerticalSpeed = getWallRunStartVerticalSpeed(root)
				lastLocalWallRunRequestAt = now
				lastLocalWallRunUpdateAt = now
				localWallRunning = true
				localWallSide = side
				localWallNormal = hit.Normal
				localWallDirection = wallDirection
				localWallRunStartedAt = now
				localWallRunStartVerticalSpeed = startVerticalSpeed
				localWallRunSpeed = runSpeed
				localSlidingUntil = -math.huge
				root.AssemblyLinearVelocity = wallDirection * runSpeed - hit.Normal * MovementConfig.wallRunStickForce + UP * startVerticalSpeed
				applyLocalMoveSpeed()

				remotes.MovementAction:FireServer({
					action = "StartWallRun",
					side = side,
					direction = desiredDirection,
				})
				return
			end
		end
	end
end

local function updateLocalWallRun()
	local _, humanoid, root = getCharacterParts()
	if not localWallRunning or not humanoid or not root then
		return
	end

	local now = os.clock()
	local hit = getWallHit(localWallSide)
	if isGrounded(humanoid) or now - localWallRunStartedAt > MovementConfig.wallRunDuration or not hit or not isWallRunnable(hit.Instance) then
		stopLocalWallRun(true)
		return
	end

	local desiredDirection = getInputMoveDirection()
	if not desiredDirection then
		stopLocalWallRun(true)
		return
	end

	local wallDirection = getWallDirection(hit.Normal, desiredDirection)
	if not isWallRunDirectionValid(hit.Normal, desiredDirection, wallDirection) then
		stopLocalWallRun(true)
		return
	end

	localWallNormal = hit.Normal
	localWallDirection = wallDirection
	local verticalSpeed = getWallRunVerticalSpeed(localWallRunStartedAt, localWallRunStartVerticalSpeed, now)
	local runSpeed = localWallRunSpeed > 0 and localWallRunSpeed or MovementConfig.wallRunSpeed
	root.AssemblyLinearVelocity = localWallDirection * runSpeed - hit.Normal * MovementConfig.wallRunStickForce + UP * verticalSpeed

	if now - lastLocalWallRunUpdateAt > 0.08 then
		lastLocalWallRunUpdateAt = now
		remotes.MovementAction:FireServer({
			action = "WallRunUpdate",
			direction = desiredDirection,
		})
	end
end

local function requestWallJump()
	local _, humanoid, root = getCharacterParts()
	if not humanoid or not root or not localWallRunning or not localWallNormal or not localWallDirection then
		return false
	end

	local wallNormal = localWallNormal
	local wallDirection = localWallDirection
	local flatVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local carrySpeed = math.clamp(
		math.max(MovementConfig.wallJumpForwardSpeed, flatVelocity:Dot(wallDirection)),
		MovementConfig.wallJumpForwardSpeed,
		MovementConfig.wallRunMaxSpeed
	)
	stopLocalWallRun(false)
	root.AssemblyLinearVelocity =
		wallNormal * MovementConfig.wallJumpOutSpeed
		+ wallDirection * carrySpeed
		+ UP * MovementConfig.wallJumpUpSpeed
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	remotes.MovementAction:FireServer({
		action = "WallJump",
	})

	return true
end

local function requestMantle()
	local character, humanoid, root = getCharacterParts()
	local now = os.clock()
	if not character or not humanoid or not root or now - lastLocalMantleAt < MovementConfig.mantleCooldown then
		return false
	end

	local direction = getMoveDirection()
	local origin = root.Position + UP * 0.4
	local hit = workspace:Raycast(origin, direction * MovementConfig.mantleDistance, makeMovementRaycastParams(character))
	if not hit or not isMantleTarget(hit.Instance) then
		return false
	end

	local part = hit.Instance
	local topY = part.Position.Y + part.Size.Y * 0.5
	local footY = root.Position.Y - 3
	local ledgeHeight = topY - footY
	if ledgeHeight < MovementConfig.mantleMinHeight or ledgeHeight > MovementConfig.mantleMaxHeight then
		return false
	end

	lastLocalMantleAt = now
	stopLocalWallRun(false)
	localSlidingUntil = -math.huge
	root.AssemblyLinearVelocity = direction * MovementConfig.mantleForwardSpeed + UP * MovementConfig.mantleUpSpeed

	task.delay(0.14, function()
		local _, currentHumanoid, currentRoot = getCharacterParts()
		if not currentHumanoid or not currentRoot then
			return
		end

		local targetPosition = Vector3.new(currentRoot.Position.X, topY + 3, currentRoot.Position.Z) + direction * 2.2
		currentRoot.CFrame = CFrame.lookAt(targetPosition, targetPosition + direction)
		currentRoot.AssemblyLinearVelocity = direction * MovementConfig.mantleForwardSpeed
		currentHumanoid:ChangeState(Enum.HumanoidStateType.Running)
	end)

	remotes.MovementAction:FireServer({
		action = "Mantle",
		direction = direction,
	})

	return true
end

local function requestJumpMovement()
	local now = os.clock()
	if now - lastJumpActionAt < 0.05 then
		return
	end

	lastJumpActionAt = now
	if requestWallJump() then
		return
	end
	if requestSlideJump() then
		return
	end
	if requestMantle() then
		return
	end
end

local function setScoped(enabled)
	local camera = getCamera()
	if not camera then
		return
	end

	if enabled and currentWeaponId ~= "Sniper" then
		enabled = false
	end

	if enabled == scoped then
		return
	end

	scoped = enabled
	if scoped then
		local sniperConfig = WeaponConfig.get("Sniper")
		camera.FieldOfView = sniperConfig.zoomFieldOfView or 35
	else
		camera.FieldOfView = baseFieldOfView
	end

	hud:setScoped(scoped)
	visuals:setScoped(scoped)
end

local function equipWeapon(weaponId)
	if not WeaponConfig.get(weaponId) then
		return
	end

	currentWeaponId = weaponId
	if currentWeaponId ~= "Sniper" then
		setScoped(false)
	end

	hud:setWeapon(weaponId)
    local ammunition = ammoByWeapon[weaponId]
    if ammunition then
        hud:setAmmo(weaponId, ammunition.loaded, ammunition.capacity, ammunition.reloading)
    end
	visuals:setWeapon(weaponId)
	remotes.EquipWeapon:FireServer(weaponId)
end

local function getAimRay()
	local camera = getCamera()
	if not camera then
		return nil
	end

	local viewportSize = camera.ViewportSize
	return camera:ViewportPointToRay(viewportSize.X * 0.5, viewportSize.Y * 0.5)
end

local function requestReload()
    local config = WeaponConfig.get(currentWeaponId)
    if not config or not config.magazineSize then return end
    local now = os.clock()
    if now - lastReloadRequestAt < 0.24 then return end
    local state = ammoByWeapon[currentWeaponId]
    if state and state.reloading then return end
    lastReloadRequestAt = now
    remotes.ReloadWeapon:FireServer(currentWeaponId)
end

local function fireWeapon(weaponId)
	local config = WeaponConfig.get(weaponId)
	if not config then
		return
	end

    local ammo = ammoByWeapon[weaponId]
    if ammo and (ammo.reloading or ammo.loaded <= 0 and ammo.capacity > 0) then
        if ammo.loaded <= 0 and not ammo.reloading then requestReload() end
        return
    end
    local _, humanoid = getCharacterParts()
    if not humanoid or humanoid.Health <= 0 then return end
    if workspace:GetAttribute("NeonMatchPhase") ~= "LIVE" then return end

	local now = os.clock()
	local lastShot = lastLocalFire[weaponId] or -math.huge
	if now - lastShot < config.fireCooldown * 1.015 then
		return
	end

	local ray = getAimRay()
	if not ray then
		return
	end

	lastLocalFire[weaponId] = now
    if ammo and ammo.capacity > 0 then
        ammo.loaded = math.max(0, ammo.loaded - 1)
        hud:setAmmo(weaponId, ammo.loaded, ammo.capacity, false)
    end
	visuals:kick(weaponId)
	visuals:playFireSound(weaponId, ray.Origin)

	if config.kind == "Raycast" or config.kind == "Pellet" then
        visuals:drawTracer(ray.Origin, ray.Direction.Unit, config.kind == "Pellet" and 100 or config.range)
	end

	remotes.FireWeapon:FireServer({
		weaponId = weaponId,
		origin = ray.Origin,
		direction = ray.Direction.Unit,
	})
end

local function quickThrowKnife()
	local previousWeaponId = currentWeaponId
	equipWeapon("Knife")
	fireWeapon("Knife")

	if previousWeaponId ~= "Knife" then
		task.delay(0.18, function()
            if currentWeaponId == "Knife" then
                equipWeapon(previousWeaponId)
            end
		end)
	end
end

local function applyAirControl(deltaTime)
	local _, humanoid, root = getCharacterParts()
	if not humanoid or not root or isGrounded(humanoid) or localWallRunning or hud:isSettingsOpen() then
		return
	end

	local inputDirection = getInputMoveDirection()
	if not inputDirection then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local desiredSpeed = getAirControlSpeed(flatVelocity.Magnitude)
	local desiredFlatVelocity = inputDirection * desiredSpeed
	local adjustedFlatVelocity = moveVectorToward(flatVelocity, desiredFlatVelocity, MovementConfig.airControlAcceleration * deltaTime)

	root.AssemblyLinearVelocity = Vector3.new(adjustedFlatVelocity.X, velocity.Y, adjustedFlatVelocity.Z)
end

local function applyBoostThrust(deltaTime)
	local _, humanoid, root = getCharacterParts()
	if not humanoid or not root or not localBoosting or isGrounded(humanoid) or localWallRunning or localBoostFuel <= 0 then
		stopBoosting()
		return
	end

	local direction = getInputMoveDirection()
	local velocity = root.AssemblyLinearVelocity
	local throttle, ramp = getBoostThrottle()
	local maxUpSpeed = lerpNumber(MovementConfig.boostFeatherMaxUpSpeed, MovementConfig.boostMaxUpSpeed, ramp)
	local fallBrakeSpeed = lerpNumber(MovementConfig.boostFeatherFallBrakeSpeed, MovementConfig.boostFallBrakeSpeed, ramp)
	local liftedY = math.min(
		maxUpSpeed,
		velocity.Y + (MovementConfig.boostLiftAcceleration * throttle + getBoostGravityAssist()) * deltaTime
	)
	liftedY = math.max(liftedY, fallBrakeSpeed)

	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if direction then
		local horizontalThrottle = math.max(throttle, MovementConfig.boostFeatherHorizontalThrottle)
		local desiredSpeed = math.clamp(flatVelocity.Magnitude, MovementConfig.airControlBaseSpeed, MovementConfig.boostMaxHorizontalSpeed)
		local desiredFlatVelocity = direction * desiredSpeed
		flatVelocity = moveVectorToward(flatVelocity, desiredFlatVelocity, MovementConfig.boostForwardAcceleration * horizontalThrottle * deltaTime)
	end
	if flatVelocity.Magnitude > MovementConfig.boostMaxHorizontalSpeed then
		flatVelocity = flatVelocity.Unit * MovementConfig.boostMaxHorizontalSpeed
	end

	root.AssemblyLinearVelocity = Vector3.new(flatVelocity.X, liftedY, flatVelocity.Z)
	localBoostFuel = math.max(0, localBoostFuel - MovementConfig.boostFuelBurnPerSecond * throttle * deltaTime)
	hud:setBoostFuel(localBoostFuel / MovementConfig.boostFuelMax)

	local now = os.clock()
	if now - lastBoostUpdateAt > 0.08 then
		lastBoostUpdateAt = now
		remotes.MovementAction:FireServer({
			action = "BoostUpdate",
			direction = direction,
		})
	end
end

local function applyFallGravity(deltaTime)
	local _, humanoid, root = getCharacterParts()
	if not humanoid or not root or isGrounded(humanoid) or localWallRunning or localBoosting then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	if velocity.Y >= MovementConfig.fallGravityStartSpeed then
		return
	end

	local extraFallGravity = workspace.Gravity * math.max(0, MovementConfig.fallGravityMultiplier - 1)
	local newY = math.max(-MovementConfig.maxFallSpeed, velocity.Y - extraFallGravity * deltaTime)
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, newY, velocity.Z)
end

local function updateCameraFeel(deltaTime)
	local camera = getCamera()
	if not camera then
		return
	end

	local _, humanoid = getCharacterParts()
	local sliding = os.clock() < localSlidingUntil
	local targetRoll = 0
	if localWallRunning then
		targetRoll = localWallSide == "Left" and -7 or 7
	elseif sliding then
		targetRoll = -1.2
	end

	cameraRoll += (targetRoll - cameraRoll) * math.clamp(deltaTime * 10, 0, 1)
	if math.abs(cameraRoll) > 0.01 then
		camera.CFrame *= CFrame.Angles(0, 0, math.rad(cameraRoll))
	end

	if scoped then
		return
	end

	local fovBonus = 0
	if sprinting then
		fovBonus += 4
	end
	if sliding then
		fovBonus += 7
	end
	if localWallRunning then
		fovBonus += 5
	elseif humanoid and not isGrounded(humanoid) then
		fovBonus += 2
	end

	local targetFov = baseFieldOfView + fovBonus
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.clamp(deltaTime * 8, 0, 1)
end

-- Desktop automatic weapons fire while the button is held, but semi-automatic
-- guns still need one distinct press. The server enforces all shot cooldowns.
local mouseFireHeld = false
local function beginMouseFire()
    if mouseFireHeld then return end
    mouseFireHeld = true
    fireWeapon(currentWeaponId)
    task.spawn(function()
        while mouseFireHeld do
            local weapon = WeaponConfig.get(currentWeaponId)
            if not weapon or not weapon.automatic then break end
            task.wait(math.max(0.04, weapon.fireCooldown * 0.40))
            if mouseFireHeld and not hud:isSettingsOpen() then
                fireWeapon(currentWeaponId)
            end
        end
    end)
end

UserInputService.WindowFocusReleased:Connect(function()
    mouseFireHeld = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.M then
        mouseFireHeld = false
		hud:toggleSettings()
		return
	end

	if hud:isSettingsOpen() then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
        beginMouseFire()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		setScoped(true)
	elseif input.KeyCode == Enum.KeyCode.Space then
		requestJumpMovement()
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprinting(true)
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		requestSlide()
	elseif input.KeyCode == Enum.KeyCode.One then
		equipWeapon("AssaultRifle")
    elseif input.KeyCode == Enum.KeyCode.Two then
        equipWeapon("Pistol")
    elseif input.KeyCode == Enum.KeyCode.Three then
        equipWeapon("Shotgun")
    elseif input.KeyCode == Enum.KeyCode.Four then
        equipWeapon("Sniper")
    elseif input.KeyCode == Enum.KeyCode.Five then
        equipWeapon("Knife")
	elseif input.KeyCode == Enum.KeyCode.R then
        requestReload()
    elseif input.KeyCode == Enum.KeyCode.Q then
		quickThrowKnife()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseFireHeld = false
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		setScoped(false)
	elseif input.KeyCode == Enum.KeyCode.Space then
		stopBoosting()
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprinting(false)
	end
end)

UserInputService.JumpRequest:Connect(function()
	if hud:isSettingsOpen() then
		return
	end

	requestJumpMovement()
end)

remotes.WeaponFeedback.OnClientEvent:Connect(function(message)
	if typeof(message) ~= "table" then
		return
	end

	if message.kind == "Hit" then
        hud:showHitFeedback(message)
    elseif message.kind == "Ammo" and typeof(message.weaponId) == "string"
        and typeof(message.capacity) == "number" and typeof(message.loaded) == "number" then
        ammoByWeapon[message.weaponId] = {
            loaded = message.loaded,
            capacity = message.capacity,
            reloading = message.reloading == true,
        }
        hud:setAmmo(message.weaponId, message.loaded, message.capacity, message.reloading == true)
    elseif message.kind == "OutOfAmmo" and message.weaponId == currentWeaponId then
        requestReload()
	end
end)

remotes.WeaponFx.OnClientEvent:Connect(function(message)
	if typeof(message) ~= "table" then
		return
	end

	if message.kind == "FireSound" and message.shooterUserId ~= player.UserId and typeof(message.origin) == "Vector3" then
		visuals:playFireSound(message.weaponId, message.origin)
    elseif message.kind == "BotTracer"
        and typeof(message.origin) == "Vector3"
        and typeof(message.direction) == "Vector3"
        and typeof(message.length) == "number" then
        local distance = math.clamp(message.length, 0, 140)
        if message.direction.Magnitude > 0.01 and distance > 1 then
            local accent = typeof(message.color) == "Color3" and message.color or nil
            visuals:drawTracer(message.origin, message.direction.Unit, distance, accent)
            visuals:drawMuzzleFlash(message.origin, accent)
        end
	end
end)

remotes.MovementState.OnClientEvent:Connect(function(message)
	if typeof(message) ~= "table" then
		return
	end

	if typeof(message.boostFuel) == "number" then
		local maxFuel = typeof(message.boostFuelMax) == "number" and message.boostFuelMax or MovementConfig.boostFuelMax
		localBoostFuel = math.clamp(message.boostFuel, 0, maxFuel)
		hud:setBoostFuel(localBoostFuel / maxFuel)
	end

	if message.wallRunning == false then
		stopLocalWallRun(false)
	elseif message.wallRunning == true then
		localWallRunning = true
		localWallSide = message.wallSide
	end

	if message.boosting == false then
		localBoosting = false
		localBoostStartedAt = -math.huge
	end
end)

player.CharacterAdded:Connect(function()
	task.defer(function()
		enforceFirstPerson()
		setSprinting(false)
		stopLocalWallRun(false)
		localBoostFuel = MovementConfig.boostFuelMax
		localSlidingUntil = -math.huge
		localBoosting = false
		localBoostStartedAt = -math.huge
		lastGroundedAt = os.clock()
        ammoByWeapon = {}
        lastLocalFire = {}
        equipWeapon(currentWeaponId)
		hud:setBoostFuel(1)
		applyLocalMoveSpeed()
	end)
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.defer(enforceFirstPerson)
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if hud and hud:isSettingsOpen() then
		applyMenuMouseState(true)
	end

	showLocalBody()
	tryStartWallRun()
	updateLocalWallRun()
	applyBoostThrust(deltaTime)
	applyAirControl(deltaTime)
	applyFallGravity(deltaTime)
	updateCameraFeel(deltaTime)

	local _, humanoid = getCharacterParts()
	if isGrounded(humanoid) then
		lastGroundedAt = os.clock()
		stopBoosting()
		localBoostFuel = math.min(
			MovementConfig.boostFuelMax,
			localBoostFuel + MovementConfig.boostFuelRegenPerSecond * deltaTime
		)
		hud:setBoostFuel(localBoostFuel / MovementConfig.boostFuelMax)
	elseif UserInputService:IsKeyDown(Enum.KeyCode.Space) and not localWallRunning then
		startBoosting()
	end
end)

enforceFirstPerson()
hud:setBoostFuel(localBoostFuel / MovementConfig.boostFuelMax)
equipWeapon(currentWeaponId)

-- IRON YARD: mobile touch fire/aim/weapon controls; Roblox provides left thumbstick and camera drag.
if UserInputService.TouchEnabled then
    local touchGui = Instance.new("ScreenGui")
    touchGui.Name = "NeonStrikeTouchControls"
    touchGui.IgnoreGuiInset = true
    touchGui.ResetOnSpawn = false
    touchGui.DisplayOrder = 30
    touchGui.Parent = playerGui

    local function button(name, label, x, y, width, height)
        local b = Instance.new("TextButton")
        b.Name = name
        b.AnchorPoint = Vector2.new(1, 1)
        b.Position = UDim2.new(1, x, 1, y)
        b.Size = UDim2.fromOffset(width, height)
        b.Font = Enum.Font.GothamBold
        b.Text = label
        b.TextScaled = true
        b.BackgroundColor3 = Color3.fromRGB(38, 45, 43)
        b.BackgroundTransparency = 0.17
        b.TextColor3 = Color3.fromRGB(250, 239, 213)
        b.Parent = touchGui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = b
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(204, 165, 94)
        stroke.Parent = b
        return b
    end

    local fire = button("Fire", "FIRE", -22, -153, 100, 100)
    local aim = button("Aim", "AIM", -135, -163, 70, 65)
    local sprint = button("Sprint", "RUN", -22, -276, 78, 55)
    local slide = button("Slide", "SLIDE", -112, -276, 78, 55)
    local reload = button("Reload", "RLD", -205, -276, 72, 55)
    local rifle = button("AssaultRifle", "AR", -22, -348, 50, 48)
    local pistol = button("Pistol", "P", -80, -348, 50, 48)
    local shotgun = button("Shotgun", "SG", -138, -348, 50, 48)
    local sniper = button("Sniper", "S", -196, -348, 50, 48)
    local knife = button("Knife", "K", -254, -348, 50, 48)
    local heldFireInput = nil
    fire.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if heldFireInput then return end
        heldFireInput = input
        fireWeapon(currentWeaponId)
        task.spawn(function()
            while heldFireInput == input and fire.Parent do
                local selected = WeaponConfig.get(currentWeaponId)
                if not selected or not selected.automatic then break end
                task.wait(math.max(0.04, selected.fireCooldown * 0.40))
                if heldFireInput == input and not hud:isSettingsOpen() then
                    fireWeapon(currentWeaponId)
                end
            end
        end)
    end)
    fire.InputEnded:Connect(function(input)
        if input == heldFireInput then
            heldFireInput = nil
        end
    end)
    aim.Activated:Connect(function()
        if not hud:isSettingsOpen() then setScoped(not scoped) end
    end)
    sprint.Activated:Connect(function()
        if not hud:isSettingsOpen() then setSprinting(not sprinting) end
    end)
    slide.Activated:Connect(function()
        if not hud:isSettingsOpen() then requestSlide() end
    end)
    reload.Activated:Connect(function()
        if not hud:isSettingsOpen() then requestReload() end
    end)
    rifle.Activated:Connect(function() if not hud:isSettingsOpen() then equipWeapon("AssaultRifle") end end)
    shotgun.Activated:Connect(function() if not hud:isSettingsOpen() then equipWeapon("Shotgun") end end)
    pistol.Activated:Connect(function() if not hud:isSettingsOpen() then equipWeapon("Pistol") end end)
    sniper.Activated:Connect(function() if not hud:isSettingsOpen() then equipWeapon("Sniper") end end)
    knife.Activated:Connect(function() if not hud:isSettingsOpen() then equipWeapon("Knife") end end)
end
