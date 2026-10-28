local Workspace = game:GetService("Workspace")

local DummyService = {}

local DUMMY_FOLDER_NAME = "DamageTestDummies"
local RESPAWN_DELAY = 5

local dummySpawns = {
	Vector3.new(-18, 0, -62),
	Vector3.new(-9, 0, -68),
	Vector3.new(0, 0, -74),
	Vector3.new(9, 0, -68),
	Vector3.new(18, 0, -62),
}

local started = false
local folder = nil
local random = Random.new()

local function makePart(name, size, position, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Position = position
	part.Size = size
	part.Transparency = transparency or 0
	return part
end

local function updateHealthBar(barFill, healthText, humanoid)
	local maxHealth = math.max(humanoid.MaxHealth, 1)
	local health = math.max(humanoid.Health, 0)
	local ratio = math.clamp(health / maxHealth, 0, 1)

	barFill.Size = UDim2.fromScale(ratio, 1)
	healthText.Text = string.format("%d / %d", math.ceil(health), math.ceil(maxHealth))

	if ratio <= 0.3 then
		barFill.BackgroundColor3 = Color3.fromRGB(245, 82, 82)
	elseif ratio <= 0.6 then
		barFill.BackgroundColor3 = Color3.fromRGB(245, 192, 82)
	else
		barFill.BackgroundColor3 = Color3.fromRGB(77, 224, 128)
	end
end

local function addBillboard(model, head, humanoid, displayName)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TargetLabel"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 180
	billboard.Size = UDim2.fromOffset(150, 48)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.28, 0)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.fromOffset(0, 0)
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Text = displayName
	label.TextColor3 = Color3.fromRGB(255, 238, 168)
	label.TextSize = 14
	label.TextStrokeTransparency = 0.45
	label.Parent = billboard

	local shell = Instance.new("Frame")
	shell.Name = "HealthShell"
	shell.AnchorPoint = Vector2.new(0.5, 0)
	shell.BackgroundColor3 = Color3.fromRGB(18, 21, 28)
	shell.BorderSizePixel = 0
	shell.Position = UDim2.new(0.5, 0, 0, 24)
	shell.Size = UDim2.fromOffset(112, 10)
	shell.Parent = billboard

	local shellCorner = Instance.new("UICorner")
	shellCorner.CornerRadius = UDim.new(0, 4)
	shellCorner.Parent = shell

	local shellStroke = Instance.new("UIStroke")
	shellStroke.Color = Color3.fromRGB(80, 92, 112)
	shellStroke.Transparency = 0.2
	shellStroke.Thickness = 1
	shellStroke.Parent = shell

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(77, 224, 128)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = shell

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.BackgroundTransparency = 1
	healthText.Font = Enum.Font.GothamBold
	healthText.Position = UDim2.new(0, 0, 0, 34)
	healthText.Size = UDim2.new(1, 0, 0, 14)
	healthText.TextColor3 = Color3.fromRGB(235, 244, 255)
	healthText.TextSize = 10
	healthText.TextStrokeTransparency = 0.55
	healthText.Parent = billboard

	updateHealthBar(fill, healthText, humanoid)
	humanoid.HealthChanged:Connect(function()
		updateHealthBar(fill, healthText, humanoid)
	end)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHealthBar(fill, healthText, humanoid)
	end)

	return billboard, label, fill, healthText
end

local function collapseDummy(model)
	model:SetAttribute("Dead", true)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = descendant.Name ~= "HumanoidRootPart" and descendant.Name ~= "HeadshotMarker"
			descendant.AssemblyLinearVelocity = Vector3.new(
				random:NextNumber(-7, 7),
				random:NextNumber(5, 14),
				random:NextNumber(-7, 7)
			)
			descendant.AssemblyAngularVelocity = Vector3.new(
				random:NextNumber(-8, 8),
				random:NextNumber(-8, 8),
				random:NextNumber(-8, 8)
			)
		end
	end
end

local function addHealthWatcher(model, humanoid, spawnIndex, nameLabel)
	humanoid.Died:Connect(function()
		if nameLabel then
			nameLabel.Text = "RESPAWNING"
			nameLabel.TextColor3 = Color3.fromRGB(255, 106, 106)
		end

		collapseDummy(model)

		task.delay(RESPAWN_DELAY, function()
			if model.Parent then
				model:Destroy()
			end

			if started and folder then
				DummyService.spawn(spawnIndex)
			end
		end)
	end)
end

function DummyService.spawn(spawnIndex)
	local spawnPosition = dummySpawns[spawnIndex]
	if not spawnPosition or not folder then
		return
	end

	local model = Instance.new("Model")
	model.Name = "Damage Dummy " .. tostring(spawnIndex)
	model.Parent = folder

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), spawnPosition + Vector3.new(0, 2.8, 0), Color3.fromRGB(70, 78, 94), 1)
	root.CanCollide = false
	root.Parent = model

	local torso = makePart("Torso", Vector3.new(2.1, 2.2, 1), spawnPosition + Vector3.new(0, 2.7, 0), Color3.fromRGB(77, 92, 122), 0)
	torso.Parent = model

	local head = makePart("Head", Vector3.new(1.25, 1.25, 1.25), spawnPosition + Vector3.new(0, 4.45, 0), Color3.fromRGB(235, 189, 145), 0)
	head.Shape = Enum.PartType.Ball
	head.Parent = model

	local leftArm = makePart("Left Arm", Vector3.new(0.65, 1.9, 0.65), spawnPosition + Vector3.new(-1.45, 2.75, 0), Color3.fromRGB(68, 80, 105), 0)
	leftArm.Parent = model

	local rightArm = makePart("Right Arm", Vector3.new(0.65, 1.9, 0.65), spawnPosition + Vector3.new(1.45, 2.75, 0), Color3.fromRGB(68, 80, 105), 0)
	rightArm.Parent = model

	local leftLeg = makePart("Left Leg", Vector3.new(0.75, 2, 0.75), spawnPosition + Vector3.new(-0.48, 1, 0), Color3.fromRGB(39, 45, 58), 0)
	leftLeg.Parent = model

	local rightLeg = makePart("Right Leg", Vector3.new(0.75, 2, 0.75), spawnPosition + Vector3.new(0.48, 1, 0), Color3.fromRGB(39, 45, 58), 0)
	rightLeg.Parent = model

	local targetMark = makePart("HeadshotMarker", Vector3.new(0.62, 0.08, 0.62), spawnPosition + Vector3.new(0, 4.45, -0.64), Color3.fromRGB(255, 76, 76), 0)
	targetMark.CanCollide = false
	targetMark.CanQuery = false
	targetMark.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = model

	model.PrimaryPart = root
	local _, nameLabel = addBillboard(model, head, humanoid, "DUMMY " .. tostring(spawnIndex))
	addHealthWatcher(model, humanoid, spawnIndex, nameLabel)
end

function DummyService.start()
	if started then
		return
	end

	started = true
	folder = Workspace:FindFirstChild(DUMMY_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = DUMMY_FOLDER_NAME
	folder.Parent = Workspace

	for index in ipairs(dummySpawns) do
		DummyService.spawn(index)
	end
end

return DummyService
