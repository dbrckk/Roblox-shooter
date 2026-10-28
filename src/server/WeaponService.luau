local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))
local PrecisionNet = require(shared:WaitForChild("PrecisionNet"))

local WeaponService = {}

local remotes = nil
local playerState = {}
local started = false

local function getState(player)
	local state = playerState[player]
	if not state then
		state = {
			equippedWeaponId = "Pistol",
			lastFireAt = {},
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
	if targetPlayer == attacker then
		return false
	end

	local headshot = raycastResult.Instance.Name == "Head"
	local damage = headshot and config.headshotDamage or config.damage
	local healthBefore = targetHumanoid.Health
	targetHumanoid:TakeDamage(damage)

	sendFeedback(attacker, {
		kind = "Hit",
		weaponId = weaponId,
		targetName = targetPlayer and targetPlayer.DisplayName or targetCharacter.Name,
		damage = damage,
		headshot = headshot,
		killed = healthBefore > 0 and targetHumanoid.Health <= 0,
		distance = origin and (raycastResult.Position - origin).Magnitude or 0,
	})

	return true
end

local function canFire(player, weaponId, config)
	local state = getState(player)
	local now = os.clock()
	local lastFireAt = state.lastFireAt[weaponId] or -math.huge

	if now - lastFireAt < config.fireCooldown then
		return false
	end

	state.lastFireAt[weaponId] = now
	state.equippedWeaponId = weaponId
	return true
end

local function fireRaycastWeapon(player, weaponId, config, direction)
	local character, _, head = getLiveCharacter(player)
	if not character then
		return
	end

	local origin = head.Position
	local params = makeRaycastParams({ character })
	broadcastFireFx(player, weaponId, origin)

	local result = workspace:Raycast(origin, direction * config.range, params)
	damageHit(player, weaponId, config, result, origin)
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

	local origin = head.Position + direction * 2
	local knife = createKnifeVisual(origin, direction)
	local params = makeRaycastParams({ character, knife })
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

		sendFeedback(player, {
			kind = "Miss",
			weaponId = weaponId,
		})
	end)
end

local function onEquipWeapon(player, weaponId)
	if typeof(weaponId) ~= "string" or not WeaponConfig.isValid(weaponId) then
		return
	end

	getState(player).equippedWeaponId = weaponId
end

local function onFireWeapon(player, payload)
	if typeof(payload) ~= "table" or typeof(payload.weaponId) ~= "string" then
		return
	end

	local weaponId = payload.weaponId
	local config = WeaponConfig.get(weaponId)
	local direction = getAimDirection(payload)
	if not config or not direction then
		return
	end

	if not canFire(player, weaponId, config) then
		return
	end

	if config.kind == "Raycast" then
		fireRaycastWeapon(player, weaponId, config, direction)
	elseif config.kind == "Projectile" then
		fireKnife(player, weaponId, config, direction)
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

	Players.PlayerRemoving:Connect(function(player)
		playerState[player] = nil
	end)
end

return WeaponService
