local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudController = {}
HudController.__index = HudController

local DEFAULT_FOV = 70
local DEFAULT_SENSITIVITY = 1

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

local function makeText(parent, name, text, position, size, fontSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = Color3.fromRGB(247, 244, 235)
	label.TextSize = fontSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, position, size)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(35, 39, 48)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Position = position
	button.Size = size
	button.Text = text
	button.TextColor3 = Color3.fromRGB(247, 244, 235)
	button.TextSize = 14
	button.Parent = parent
	makeCorner(button, 4)
	makeStroke(button, Color3.fromRGB(70, 78, 96), 0.3, 1)
	return button
end

local function clampSetting(value, minValue, maxValue)
	return math.clamp(value, minValue, maxValue)
end

function HudController.new(player, gui, WeaponConfig, options)
	local self = setmetatable({}, HudController)

	self.player = player
	self.gui = gui
	self.WeaponConfig = WeaponConfig
	self.options = options or {}
	self.currentWeaponId = "Pistol"
	self.hitToken = 0
	self.settingsOpen = false
	self.baseFov = self.options.baseFov or DEFAULT_FOV
	self.mouseSensitivity = self.options.mouseSensitivity or DEFAULT_SENSITIVITY
	self.healthConnections = {}

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	self:_buildCrosshair()
	self:_buildBoostMeter()
	self:_buildHealthBar()
	self:_buildWeaponLabel()
	self:_buildScopeOverlay()
	self:_buildSettingsMenu()
	self:_bindHealth(player.Character)

	player.CharacterAdded:Connect(function(character)
		self:_bindHealth(character)
	end)

	return self
end

function HudController:_buildCrosshair()
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.BackgroundTransparency = 1
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(46, 46)
	crosshair.Parent = self.gui
	self.crosshair = crosshair

	local function addLine(name, size, position)
		local line = Instance.new("Frame")
		line.Name = name
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = Color3.fromRGB(247, 244, 235)
		line.BorderSizePixel = 0
		line.Position = position
		line.Size = size
		line.Parent = crosshair
        -- Bright daylight and white sand can wash out plain white crosshairs.
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.fromRGB(31, 37, 36)
        outline.Thickness = 1.2
        outline.Transparency = 0.15
        outline.Parent = line
		return line
	end

	self.crosshairLines = {
		addLine("Top", UDim2.fromOffset(2, 12), UDim2.fromScale(0.5, 0.18)),
		addLine("Bottom", UDim2.fromOffset(2, 12), UDim2.fromScale(0.5, 0.82)),
		addLine("Left", UDim2.fromOffset(12, 2), UDim2.fromScale(0.18, 0.5)),
		addLine("Right", UDim2.fromOffset(12, 2), UDim2.fromScale(0.82, 0.5)),
	}

	local hitMarker = Instance.new("TextLabel")
	hitMarker.Name = "HitMarker"
	hitMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	hitMarker.BackgroundTransparency = 1
	hitMarker.Font = Enum.Font.GothamBold
	hitMarker.Position = UDim2.fromScale(0.5, 0.5)
	hitMarker.Size = UDim2.fromOffset(90, 50)
	hitMarker.Text = "x"
	hitMarker.TextColor3 = Color3.fromRGB(255, 255, 255)
	hitMarker.TextScaled = true
	hitMarker.TextTransparency = 1
	hitMarker.Visible = false
	hitMarker.Parent = self.gui
	self.hitMarker = hitMarker
end

function HudController:_buildHealthBar()
	local shell = Instance.new("Frame")
	shell.Name = "HealthBar"
	shell.AnchorPoint = Vector2.new(0, 1)
	shell.BackgroundColor3 = Color3.fromRGB(35, 41, 41)
	shell.BorderSizePixel = 0
	shell.Position = UDim2.new(0, 24, 1, -32)
	shell.Size = UDim2.fromOffset(250, 24)
	shell.Parent = self.gui
	makeCorner(shell, 4)
	makeStroke(shell, Color3.fromRGB(72, 82, 98), 0.25, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(77, 224, 128)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = shell
	makeCorner(fill, 4)

	local text = Instance.new("TextLabel")
	text.Name = "Value"
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.Size = UDim2.fromScale(1, 1)
	text.Text = "100"
	text.TextColor3 = Color3.fromRGB(247, 250, 255)
	text.TextSize = 13
	text.Parent = shell

	self.healthFill = fill
	self.healthText = text
end

function HudController:_buildBoostMeter()
	local label = Instance.new("TextLabel")
	label.Name = "BoostLabel"
	label.AnchorPoint = Vector2.new(0, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.new(0, 24, 1, -63)
	label.Size = UDim2.fromOffset(74, 16)
	label.Text = "BOOST"
	label.TextColor3 = Color3.fromRGB(235, 198, 135)
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = self.gui

	local shell = Instance.new("Frame")
	shell.Name = "BoostMeter"
	shell.AnchorPoint = Vector2.new(0, 1)
	shell.BackgroundColor3 = Color3.fromRGB(35, 41, 41)
	shell.BorderSizePixel = 0
	shell.Position = UDim2.new(0, 84, 1, -66)
	shell.Size = UDim2.fromOffset(190, 10)
	shell.Parent = self.gui
	makeCorner(shell, 4)
	makeStroke(shell, Color3.fromRGB(72, 82, 98), 0.25, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(207, 160, 89)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = shell
	makeCorner(fill, 4)

	self.boostFill = fill
end

function HudController:_buildWeaponLabel()
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Name = "WeaponLabel"
	weaponLabel.AnchorPoint = Vector2.new(0.5, 1)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Font = Enum.Font.GothamMedium
	weaponLabel.Position = UDim2.new(0.5, 0, 1, -42)
	weaponLabel.Size = UDim2.fromOffset(280, 34)
	weaponLabel.TextColor3 = Color3.fromRGB(247, 244, 235)
	weaponLabel.TextScaled = true
	weaponLabel.Parent = self.gui
	self.weaponLabel = weaponLabel
end

function HudController:_buildScopeOverlay()
	local scopeOverlay = Instance.new("Frame")
	scopeOverlay.Name = "ScopeOverlay"
	scopeOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	scopeOverlay.BackgroundTransparency = 0.45
	scopeOverlay.BorderSizePixel = 0
	scopeOverlay.Size = UDim2.fromScale(1, 1)
	scopeOverlay.Visible = false
	scopeOverlay.ZIndex = 0
	scopeOverlay.Parent = self.gui

	local scopeRing = Instance.new("Frame")
	scopeRing.Name = "ScopeRing"
	scopeRing.AnchorPoint = Vector2.new(0.5, 0.5)
	scopeRing.BackgroundTransparency = 1
	scopeRing.BorderSizePixel = 0
	scopeRing.Position = UDim2.fromScale(0.5, 0.5)
	scopeRing.Size = UDim2.fromOffset(310, 310)
	scopeRing.Visible = false
	scopeRing.ZIndex = 2
	scopeRing.Parent = self.gui
	makeStroke(scopeRing, Color3.fromRGB(247, 244, 235), 0.2, 2)
	makeCorner(scopeRing, 999)

	self.scopeOverlay = scopeOverlay
	self.scopeRing = scopeRing
end

function HudController:_buildSettingsMenu()
	local button = makeButton(self.gui, "SettingsButton", "M SETTINGS", UDim2.new(1, -138, 0, 18), UDim2.fromOffset(118, 34))
	self.settingsButton = button

	local panel = Instance.new("Frame")
	panel.Name = "SettingsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(18, 21, 28)
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(340, 232)
	panel.Visible = false
	panel.ZIndex = 10
	panel.Parent = self.gui
	makeCorner(panel, 6)
	makeStroke(panel, Color3.fromRGB(90, 102, 126), 0.15, 1)
	self.settingsPanel = panel

	local title = makeText(panel, "Title", "SETTINGS", UDim2.fromOffset(22, 18), UDim2.fromOffset(220, 28), 18)
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 11

	local closeButton = makeButton(panel, "Close", "X", UDim2.new(1, -48, 0, 18), UDim2.fromOffset(28, 28))
	closeButton.ZIndex = 11

	self.fovValueLabel = self:_makeStepper(panel, "FOV", UDim2.fromOffset(22, 74), 60, 100, 5, function()
		return tostring(self.baseFov)
	end, function(delta)
		self.baseFov = clampSetting(self.baseFov + delta, 60, 100)
		self:_refreshSettingsText()
		if self.options.onFovChanged then
			self.options.onFovChanged(self.baseFov)
		end
	end)

	self.sensitivityValueLabel = self:_makeStepper(panel, "MOUSE SENS", UDim2.fromOffset(22, 132), 0.3, 2.5, 0.1, function()
		return string.format("%.1f", self.mouseSensitivity)
	end, function(delta)
		self.mouseSensitivity = clampSetting(math.floor((self.mouseSensitivity + delta) * 10 + 0.5) / 10, 0.3, 2.5)
		self:_refreshSettingsText()
		if self.options.onMouseSensitivityChanged then
			self.options.onMouseSensitivityChanged(self.mouseSensitivity)
		end
	end)

	local hint = makeText(panel, "Hint", "Press M to close", UDim2.fromOffset(22, 192), UDim2.fromOffset(220, 22), 12)
	hint.TextColor3 = Color3.fromRGB(162, 173, 190)
	hint.ZIndex = 11

	button.Activated:Connect(function()
		self:setSettingsOpen(not self.settingsOpen)
	end)

	closeButton.Activated:Connect(function()
		self:setSettingsOpen(false)
	end)

	self:_refreshSettingsText()
end

function HudController:_makeStepper(parent, labelText, position, minValue, maxValue, step, getText, onStep)
	local row = Instance.new("Frame")
	row.Name = labelText:gsub("%s+", "") .. "Row"
	row.BackgroundTransparency = 1
	row.Position = position
	row.Size = UDim2.fromOffset(296, 42)
	row.ZIndex = 11
	row.Parent = parent

	local label = makeText(row, "Label", labelText, UDim2.fromOffset(0, 3), UDim2.fromOffset(128, 32), 14)
	label.Font = Enum.Font.GothamBold
	label.ZIndex = 12

	local minus = makeButton(row, "Minus", "-", UDim2.fromOffset(144, 0), UDim2.fromOffset(36, 36))
	local value = makeText(row, "Value", getText(), UDim2.fromOffset(190, 3), UDim2.fromOffset(54, 30), 14)
	local plus = makeButton(row, "Plus", "+", UDim2.fromOffset(258, 0), UDim2.fromOffset(36, 36))
	minus.ZIndex = 12
	value.ZIndex = 12
	value.TextXAlignment = Enum.TextXAlignment.Center
	plus.ZIndex = 12

	minus.Activated:Connect(function()
		onStep(-step, minValue, maxValue)
	end)

	plus.Activated:Connect(function()
		onStep(step, minValue, maxValue)
	end)

	return value
end

function HudController:_refreshSettingsText()
	if self.fovValueLabel then
		self.fovValueLabel.Text = tostring(self.baseFov)
	end

	if self.sensitivityValueLabel then
		self.sensitivityValueLabel.Text = string.format("%.1f", self.mouseSensitivity)
	end
end

function HudController:_disconnectHealth()
	for _, connection in ipairs(self.healthConnections) do
		connection:Disconnect()
	end

	table.clear(self.healthConnections)
end

function HudController:_bindHealth(character)
	self:_disconnectHealth()

	if not character then
		self:_updateHealth(nil)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid then
		self:_updateHealth(nil)
		return
	end

	self:_updateHealth(humanoid)
	table.insert(self.healthConnections, humanoid.HealthChanged:Connect(function()
		self:_updateHealth(humanoid)
	end))
	table.insert(self.healthConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		self:_updateHealth(humanoid)
	end))
end

function HudController:_updateHealth(humanoid)
	local health = humanoid and humanoid.Health or 0
	local maxHealth = humanoid and humanoid.MaxHealth or 100
	local ratio = 0

	if maxHealth > 0 then
		ratio = math.clamp(health / maxHealth, 0, 1)
	end

	local color = Color3.fromRGB(77, 224, 128)
	if ratio <= 0.3 then
		color = Color3.fromRGB(245, 82, 82)
	elseif ratio <= 0.6 then
		color = Color3.fromRGB(245, 192, 82)
	end

	self.healthFill.BackgroundColor3 = color
	TweenService:Create(self.healthFill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
	}):Play()
	self.healthText.Text = string.format("%d / %d", math.max(0, math.ceil(health)), math.ceil(maxHealth))
end

function HudController:setBoostFuel(ratio)
	if not self.boostFill then
		return
	end

	ratio = math.clamp(ratio, 0, 1)
	if ratio <= 0.12 then
		self.boostFill.BackgroundColor3 = Color3.fromRGB(245, 82, 82)
	elseif ratio <= 0.25 then
		self.boostFill.BackgroundColor3 = Color3.fromRGB(245, 192, 82)
	else
		self.boostFill.BackgroundColor3 = Color3.fromRGB(207, 160, 89)
	end

	TweenService:Create(self.boostFill, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
	}):Play()
end

function HudController:setSettingsOpen(open)
	self.settingsOpen = open
	self.settingsPanel.Visible = open

	if self.options.onSettingsOpenChanged then
		self.options.onSettingsOpenChanged(open)
	end
end

function HudController:toggleSettings()
	self:setSettingsOpen(not self.settingsOpen)
end

function HudController:isSettingsOpen()
	return self.settingsOpen
end

function HudController:setWeapon(weaponId)
	self.currentWeaponId = weaponId
	local config = self.WeaponConfig.get(weaponId)
	self.weaponLabel.Text = config and config.displayName or weaponId

	local color = Color3.fromRGB(247, 244, 235)
	if weaponId == "Sniper" then
		color = Color3.fromRGB(201, 191, 162)
	elseif weaponId == "Knife" then
		color = Color3.fromRGB(255, 226, 153)
	end

	for _, line in ipairs(self.crosshairLines) do
		line.BackgroundColor3 = color
	end
end

function HudController:setScoped(scoped)
	self.scopeOverlay.Visible = scoped
	self.scopeRing.Visible = scoped
	self.crosshair.Visible = not scoped
end

function HudController:showHitFeedback(message)
	self.hitToken += 1
	local token = self.hitToken

	local color = Color3.fromRGB(255, 255, 255)
	if message.headshot then
		color = Color3.fromRGB(255, 226, 153)
	elseif message.killed then
		color = Color3.fromRGB(255, 106, 106)
	end

	self.hitMarker.Text = message.killed and "K" or "x"
	self.hitMarker.TextColor3 = color
	self.hitMarker.TextTransparency = 0
	self.hitMarker.Visible = true
	self.hitMarker.Size = UDim2.fromOffset(message.headshot and 112 or 86, message.headshot and 64 or 48)

	task.delay(0.14, function()
		if self.hitToken == token then
			self.hitMarker.TextTransparency = 1
			self.hitMarker.Visible = false
		end
	end)
end

return HudController
