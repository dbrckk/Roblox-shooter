local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(shared:WaitForChild("MovementConfig"))
local PrecisionNet = require(shared:WaitForChild("PrecisionNet"))

local MovementService = {}

local remotes = nil
local movementStateByPlayer = {}
local started = false

local UP = Vector3.new(0, 1, 0)

local function getState(player)
	local state = movementStateByPlayer[player]
	if not state then
		state = {
			sprinting = false,
			sliding = false,
			wallRunning = false,
			wallSide = nil,
			wallNormal = nil,
			wallDirection = nil,
			wallRunStartedAt = -math.huge,
			wallRunStartVerticalSpeed = 0,
			wallRunSpeed = 0,
			boosting = false,
			boostDirection = nil,
			boostStartedAt = -math.huge,
			boostFuel = MovementConfig.boostFuelMax,
			lastSlideAt = -math.huge,
			lastSlideJumpAt = -math.huge,
			lastBoostAt = -math.huge,
			lastWallRunAt = -math.huge,
			lastWallJumpAt = -math.huge,
			lastMantleAt = -math.huge,
			lastStateSentAt = -math.huge,
			slideToken = 0,
			wallRunToken = 0,
		}
		movementStateByPlayer[player] = state
	end

	return state
end

local function sendMovementState(player, state)
	if not remotes then
		return
	end

	state.lastStateSentAt = os.clock()
	remotes.MovementState:FireClient(player, {
		boostFuel = state.boostFuel,
		boostFuelMax = MovementConfig.boostFuelMax,
		sliding = state.sliding,
		sprinting = state.sprinting,
		wallRunning = state.wallRunning,
		wallSide = state.wallSide,
		boosting = state.boosting,
	})
end

local function getCharacterParts(player)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	return character, humanoid, root
end

local function isGrounded(humanoid)
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

local function isWallRunnable(part)
	return part and part:GetAttribute("WallRunnable") == true
end

local function isMantleTarget(part)
	return part and (part:GetAttribute("MantleTarget") == true or part:GetAttribute("WallRunnable") == true)
end

local function getFlatDirection(payload, root)
	local direction = nil

	if typeof(payload) == "table" and typeof(payload.direction) == "Vector3" and payload.direction.Magnitude > 0.05 then
		direction = payload.direction
	end

	if not direction then
		direction = root.CFrame.LookVector
	end

	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.05 then
		direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end

	if direction.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end

	return direction.Unit
end

local function getOptionalFlatDirection(payload)
	if typeof(payload) ~= "table" or typeof(payload.direction) ~= "Vector3" or payload.direction.Magnitude <= 0.05 then
		return nil
	end

	local direction = Vector3.new(payload.direction.X, 0, payload.direction.Z)
	if direction.Magnitude < 0.05 then
		return nil
	end

	return direction.Unit
end

local function lerpNumber(a, b, alpha)
	return a + (b - a) * alpha
end

local function getBoostThrottle(boostStartedAt)
	local heldTime = math.max(0, os.clock() - boostStartedAt)
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

local function getBoostGravityAssist()
	return workspace.Gravity * math.max(0, 1 - MovementConfig.boostGravityMultiplier)
end

local function applyFallGravity(humanoid, root, state, deltaTime)
	if not humanoid or not root or state.wallRunning or state.boosting or isGrounded(humanoid) then
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

local function makeRaycastParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	return params
end

local function applyMovement(player)
	local _, humanoid = getCharacterParts(player)
	if not humanoid then
		return
	end

	local state = getState(player)
	if state.wallRunning then
		humanoid.WalkSpeed = state.wallRunSpeed > 0 and state.wallRunSpeed or MovementConfig.wallRunSpeed
	elseif state.sliding then
		humanoid.WalkSpeed = MovementConfig.slideSpeed
	elseif state.sprinting then
		humanoid.WalkSpeed = MovementConfig.sprintSpeed
	else
		humanoid.WalkSpeed = MovementConfig.walkSpeed
	end
end

local function endWallRun(player)
	local _, humanoid = getCharacterParts(player)
	local state = getState(player)
	if not state.wallRunning then
		return
	end

	state.wallRunning = false
	state.wallSide = nil
	state.wallNormal = nil
	state.wallDirection = nil
	state.wallRunStartedAt = -math.huge
	state.wallRunStartVerticalSpeed = 0
	state.wallRunSpeed = 0
	state.wallRunToken += 1

	if humanoid then
		humanoid.AutoRotate = true
	end

	applyMovement(player)
	sendMovementState(player, state)
end

local function stopSlideLater(player, token)
	task.delay(MovementConfig.slideDuration, function()
		local state = movementStateByPlayer[player]
		if not state or state.slideToken ~= token then
			return
		end

		state.sliding = false
		applyMovement(player)
		sendMovementState(player, state)
	end)
end

local function requestSlide(player, payload)
	local _, humanoid, root = getCharacterParts(player)
	if not humanoid or not root then
		return
	end

	local state = getState(player)
	local now = os.clock()
	if state.wallRunning or not state.sprinting or not isGrounded(humanoid) or now - state.lastSlideAt < MovementConfig.slideCooldown then
		return
	end

	local direction = getFlatDirection(payload, root)
	state.lastSlideAt = now
	state.sliding = true
	state.slideToken += 1

	humanoid.WalkSpeed = MovementConfig.slideSpeed
	root.AssemblyLinearVelocity = Vector3.new(
		direction.X * MovementConfig.slideSpeed,
		math.max(root.AssemblyLinearVelocity.Y, MovementConfig.slideHop),
		direction.Z * MovementConfig.slideSpeed
	)

	sendMovementState(player, state)
	stopSlideLater(player, state.slideToken)
end

local function requestSlideJump(player, payload)
	local _, humanoid, root = getCharacterParts(player)
	if not humanoid or not root then
		return
	end

	local state = getState(player)
	local now = os.clock()
	local canSlideJump = state.sliding or now - state.lastSlideAt <= MovementConfig.slideJumpWindow
	if not canSlideJump or now - state.lastSlideJumpAt < MovementConfig.slideJumpCooldown then
		return
	end

	local direction = getFlatDirection(payload, root)
	state.sliding = false
	state.lastSlideJumpAt = now
	state.slideToken += 1

	root.AssemblyLinearVelocity = Vector3.new(
		direction.X * MovementConfig.slideJumpForwardSpeed,
		MovementConfig.slideJumpUpSpeed,
		direction.Z * MovementConfig.slideJumpForwardSpeed
	)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	applyMovement(player)
	sendMovementState(player, state)
end

local function setBoosting(player, payload, enabled)
	local _, humanoid, root = getCharacterParts(player)
	if not humanoid or not root then
		return
	end

	local state = getState(player)
	local now = os.clock()
	if not enabled then
		state.boosting = false
		state.boostDirection = nil
		state.boostStartedAt = -math.huge
		sendMovementState(player, state)
		return
	end

	if state.wallRunning or isGrounded(humanoid) or state.boostFuel < MovementConfig.boostFuelMinToStart or now - state.lastBoostAt < MovementConfig.boostCooldown then
		return
	end

	state.boosting = true
	state.boostDirection = getOptionalFlatDirection(payload)
	state.boostStartedAt = now
	state.lastBoostAt = now

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	sendMovementState(player, state)
end

local function updateBoostDirection(player, payload)
	local _, _, root = getCharacterParts(player)
	if not root then
		return
	end

	local state = getState(player)
	if state.boosting then
		state.boostDirection = getOptionalFlatDirection(payload)
	end
end

local function getWallHit(character, root, side)
	local sideDirection = root.CFrame.RightVector
	if side == "Left" then
		sideDirection = -sideDirection
	end

	return workspace:Raycast(root.Position, sideDirection * MovementConfig.wallRunRayDistance, makeRaycastParams(character))
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

local function requestStartWallRun(player, payload)
	local character, humanoid, root = getCharacterParts(player)
	if not character or not humanoid or not root then
		return
	end

	local state = getState(player)
	local side = typeof(payload) == "table" and payload.side or nil
	local now = os.clock()
	if side ~= "Left" and side ~= "Right" then
		return
	end

	if state.wallRunning or isGrounded(humanoid) or now - state.lastWallRunAt < MovementConfig.wallRunCooldown then
		return
	end

	local hit = getWallHit(character, root, side)
	if not hit or not isWallRunnable(hit.Instance) then
		return
	end

	local desiredDirection = getOptionalFlatDirection(payload)
	local wallDirection, entrySpeed = getWallRunStartInfo(root, hit, desiredDirection)
	if not wallDirection then
		return
	end

	local runSpeed = math.clamp(entrySpeed, MovementConfig.wallRunSpeed, MovementConfig.wallRunMaxSpeed)
	local startVerticalSpeed = getWallRunStartVerticalSpeed(root)
	state.wallRunning = true
	state.wallSide = side
	state.wallNormal = hit.Normal
	state.wallDirection = wallDirection
	state.wallRunStartedAt = now
	state.wallRunStartVerticalSpeed = startVerticalSpeed
	state.wallRunSpeed = runSpeed
	state.lastWallRunAt = now
	state.sliding = false
	state.wallRunToken += 1

	humanoid.AutoRotate = false
	humanoid.WalkSpeed = runSpeed
	root.AssemblyLinearVelocity = wallDirection * runSpeed - hit.Normal * MovementConfig.wallRunStickForce + UP * startVerticalSpeed
	sendMovementState(player, state)
end

local function updateWallRunDirection(player, payload)
	local character, humanoid, root = getCharacterParts(player)
	if not character or not humanoid or not root then
		return
	end

	local state = getState(player)
	if not state.wallRunning or not state.wallSide then
		return
	end

	local desiredDirection = getOptionalFlatDirection(payload)
	local hit = getWallHit(character, root, state.wallSide)
	if not hit or not isWallRunnable(hit.Instance) then
		endWallRun(player)
		return
	end

	local wallDirection = getWallDirection(hit.Normal, desiredDirection or state.wallDirection or getFlatDirection(nil, root))
	if not isWallRunDirectionValid(hit.Normal, desiredDirection, wallDirection) then
		endWallRun(player)
		return
	end

	state.wallNormal = hit.Normal
	state.wallDirection = wallDirection
end

local function requestWallJump(player, payload)
	local _, humanoid, root = getCharacterParts(player)
	if not humanoid or not root then
		return
	end

	local state = getState(player)
	if not state.wallRunning or not state.wallNormal or not state.wallDirection then
		return
	end

	local wallNormal = state.wallNormal
	local wallDirection = state.wallDirection
	local flatVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local carrySpeed = math.clamp(
		math.max(MovementConfig.wallJumpForwardSpeed, flatVelocity:Dot(wallDirection)),
		MovementConfig.wallJumpForwardSpeed,
		MovementConfig.wallRunMaxSpeed
	)
	state.lastWallJumpAt = os.clock()
	endWallRun(player)

	root.AssemblyLinearVelocity =
		wallNormal * MovementConfig.wallJumpOutSpeed
		+ wallDirection * carrySpeed
		+ UP * MovementConfig.wallJumpUpSpeed
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

local function requestMantle(player, payload)
	local character, humanoid, root = getCharacterParts(player)
	if not character or not humanoid or not root then
		return
	end

	local state = getState(player)
	local now = os.clock()
	if now - state.lastMantleAt < MovementConfig.mantleCooldown then
		return
	end

	local direction = getFlatDirection(payload, root)
	local origin = root.Position + UP * 0.4
	local hit = workspace:Raycast(origin, direction * MovementConfig.mantleDistance, makeRaycastParams(character))
	if not hit or not isMantleTarget(hit.Instance) then
		return
	end

	local part = hit.Instance
	local topY = part.Position.Y + part.Size.Y * 0.5
	local footY = root.Position.Y - 3
	local ledgeHeight = topY - footY
	if ledgeHeight < MovementConfig.mantleMinHeight or ledgeHeight > MovementConfig.mantleMaxHeight then
		return
	end

	state.lastMantleAt = now
	state.sliding = false
	endWallRun(player)

	root.AssemblyLinearVelocity = direction * MovementConfig.mantleForwardSpeed + UP * MovementConfig.mantleUpSpeed
	task.delay(0.14, function()
		local _, currentHumanoid, currentRoot = getCharacterParts(player)
		if not currentHumanoid or not currentRoot then
			return
		end

		local targetPosition = Vector3.new(
			currentRoot.Position.X,
			topY + 3,
			currentRoot.Position.Z
		) + direction * 2.2
		currentRoot.CFrame = CFrame.lookAt(targetPosition, targetPosition + direction)
		currentRoot.AssemblyLinearVelocity = direction * MovementConfig.mantleForwardSpeed
		currentHumanoid:ChangeState(Enum.HumanoidStateType.Running)
	end)

	sendMovementState(player, state)
end

local function onCharacterAdded(player, character)
	local state = getState(player)
	state.sprinting = false
	state.sliding = false
	state.wallRunning = false
	state.wallSide = nil
	state.wallNormal = nil
	state.wallDirection = nil
	state.wallRunStartedAt = -math.huge
	state.wallRunStartVerticalSpeed = 0
	state.wallRunSpeed = 0
	state.boosting = false
	state.boostDirection = nil
	state.boostStartedAt = -math.huge
	state.boostFuel = MovementConfig.boostFuelMax
	state.lastSlideAt = -math.huge
	state.lastBoostAt = -math.huge
	state.slideToken += 1
	state.wallRunToken += 1

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.RunningNoPhysics then
				local currentState = movementStateByPlayer[player]
				if currentState then
					currentState.wallRunning = false
					currentState.wallSide = nil
					sendMovementState(player, currentState)
				end
			end
		end)
	end

	task.defer(function()
		applyMovement(player)
		sendMovementState(player, state)
	end)
end

local function onSprintingChanged(player, isSprinting)
	if typeof(isSprinting) ~= "boolean" then
		return
	end

	local state = getState(player)
	state.sprinting = isSprinting
	applyMovement(player)
	sendMovementState(player, state)
end

local function onMovementAction(player, payload)
	if typeof(payload) ~= "table" or typeof(payload.action) ~= "string" then
		return
	end

	if payload.action == "Slide" then
		requestSlide(player, payload)
	elseif payload.action == "SlideJump" then
		requestSlideJump(player, payload)
	elseif payload.action == "BoostStart" then
		setBoosting(player, payload, true)
	elseif payload.action == "BoostStop" then
		setBoosting(player, payload, false)
	elseif payload.action == "BoostUpdate" then
		updateBoostDirection(player, payload)
	elseif payload.action == "BoostJump" then
		setBoosting(player, payload, true)
	elseif payload.action == "StartWallRun" then
		requestStartWallRun(player, payload)
	elseif payload.action == "WallRunUpdate" then
		updateWallRunDirection(player, payload)
	elseif payload.action == "WallJump" then
		requestWallJump(player, payload)
	elseif payload.action == "Mantle" then
		requestMantle(player, payload)
	elseif payload.action == "StopWallRun" then
		endWallRun(player)
	end
end

function MovementService.start()
	if started then
		return
	end

	started = true
	remotes = PrecisionNet.getRemotes(true)
	remotes.SetSprinting.OnServerEvent:Connect(onSprintingChanged)
	remotes.MovementAction.OnServerEvent:Connect(onMovementAction)

	RunService.Heartbeat:Connect(function(deltaTime)
		for player, state in pairs(movementStateByPlayer) do
			local character, humanoid, root = getCharacterParts(player)
			local now = os.clock()
			local stateChanged = false

			if state.wallRunning then
				local shouldStop = not character or not humanoid or not root or isGrounded(humanoid) or now - state.wallRunStartedAt > MovementConfig.wallRunDuration
				local hit = nil
				if not shouldStop then
					hit = getWallHit(character, root, state.wallSide)
					shouldStop = not hit or not isWallRunnable(hit.Instance)
				end

				if shouldStop then
					endWallRun(player)
				else
					local desiredDirection = state.wallDirection or getFlatDirection(nil, root)
					state.wallNormal = hit.Normal
					state.wallDirection = getWallDirection(hit.Normal, desiredDirection)
					local runSpeed = state.wallRunSpeed > 0 and state.wallRunSpeed or MovementConfig.wallRunSpeed
					local verticalSpeed = getWallRunVerticalSpeed(state.wallRunStartedAt, state.wallRunStartVerticalSpeed, now)
					root.AssemblyLinearVelocity = state.wallDirection * runSpeed - hit.Normal * MovementConfig.wallRunStickForce + UP * verticalSpeed
				end
			end

			if humanoid and root and state.boosting and not state.wallRunning and not isGrounded(humanoid) and state.boostFuel > 0 then
				local velocity = root.AssemblyLinearVelocity
				local throttle, ramp = getBoostThrottle(state.boostStartedAt)
				local maxUpSpeed = lerpNumber(MovementConfig.boostFeatherMaxUpSpeed, MovementConfig.boostMaxUpSpeed, ramp)
				local fallBrakeSpeed = lerpNumber(MovementConfig.boostFeatherFallBrakeSpeed, MovementConfig.boostFallBrakeSpeed, ramp)
				local liftedY = math.min(
					maxUpSpeed,
					velocity.Y + (MovementConfig.boostLiftAcceleration * throttle + getBoostGravityAssist()) * deltaTime
				)
				liftedY = math.max(liftedY, fallBrakeSpeed)

				local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
				if state.boostDirection then
					local horizontalThrottle = math.max(throttle, MovementConfig.boostFeatherHorizontalThrottle)
					local desiredSpeed = math.clamp(flatVelocity.Magnitude, MovementConfig.airControlBaseSpeed, MovementConfig.boostMaxHorizontalSpeed)
					local desiredFlatVelocity = state.boostDirection * desiredSpeed
					flatVelocity = moveVectorToward(flatVelocity, desiredFlatVelocity, MovementConfig.boostForwardAcceleration * horizontalThrottle * deltaTime)
				end
				if flatVelocity.Magnitude > MovementConfig.boostMaxHorizontalSpeed then
					flatVelocity = flatVelocity.Unit * MovementConfig.boostMaxHorizontalSpeed
				end

				root.AssemblyLinearVelocity = Vector3.new(flatVelocity.X, liftedY, flatVelocity.Z)
				state.boostFuel = math.max(0, state.boostFuel - MovementConfig.boostFuelBurnPerSecond * throttle * deltaTime)
				stateChanged = true

				if state.boostFuel <= 0 then
					state.boosting = false
					state.boostDirection = nil
					state.boostStartedAt = -math.huge
				end
			elseif state.boosting then
				state.boosting = false
				state.boostDirection = nil
				state.boostStartedAt = -math.huge
				stateChanged = true
			end

			applyFallGravity(humanoid, root, state, deltaTime)

			if humanoid and isGrounded(humanoid) and state.boostFuel < MovementConfig.boostFuelMax then
				state.boostFuel = math.min(
					MovementConfig.boostFuelMax,
					state.boostFuel + MovementConfig.boostFuelRegenPerSecond * deltaTime
				)
				stateChanged = true
			end

			if stateChanged and now - state.lastStateSentAt > 0.08 then
				sendMovementState(player, state)
			end
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		getState(player)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end

		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		getState(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		movementStateByPlayer[player] = nil
	end)
end

return MovementService
