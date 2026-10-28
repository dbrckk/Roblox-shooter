local Workspace = game:GetService("Workspace")

local MapService = {}

local MAP_FOLDER_NAME = "MovementTestArena"
local WALL_COLOR = Color3.fromRGB(45, 58, 78)
local WALL_ACCENT = Color3.fromRGB(82, 186, 255)
local LEDGE_COLOR = Color3.fromRGB(58, 70, 86)

local started = false

local function createPart(parent, name, size, position, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Position = position
	part.Size = size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addWallRunStripe(parent, wall, offset)
	local stripe = createPart(parent, wall.Name .. " Stripe", Vector3.new(0.08, 0.18, wall.Size.Z - 4), wall.Position + offset, WALL_ACCENT)
	stripe.Material = Enum.Material.Neon
	stripe.CanCollide = false
	stripe.CanQuery = false
	return stripe
end

local function buildArena(folder)
	local leftWall = createPart(folder, "Left WallRun Wall", Vector3.new(2, 18, 72), Vector3.new(-28, 9, 4), WALL_COLOR)
	leftWall:SetAttribute("WallRunnable", true)
	addWallRunStripe(folder, leftWall, Vector3.new(1.05, 2.6, 0))

	local rightWall = createPart(folder, "Right WallRun Wall", Vector3.new(2, 18, 72), Vector3.new(28, 9, 4), WALL_COLOR)
	rightWall:SetAttribute("WallRunnable", true)
	addWallRunStripe(folder, rightWall, Vector3.new(-1.05, 2.6, 0))

	local crossWall = createPart(folder, "Cross WallRun Wall", Vector3.new(62, 16, 2), Vector3.new(0, 8, 42), WALL_COLOR)
	crossWall:SetAttribute("WallRunnable", true)

	local lowRamp = createPart(folder, "Mantle Low Block", Vector3.new(12, 4, 9), Vector3.new(-10, 2, 62), LEDGE_COLOR)
	lowRamp:SetAttribute("MantleTarget", true)

	local highLedge = createPart(folder, "Mantle High Ledge", Vector3.new(16, 2, 10), Vector3.new(12, 6.5, 64), LEDGE_COLOR)
	highLedge:SetAttribute("MantleTarget", true)

	local backStop = createPart(folder, "Back Combat Wall", Vector3.new(80, 12, 2), Vector3.new(0, 6, 88), Color3.fromRGB(36, 43, 54))
	backStop:SetAttribute("WallRunnable", true)
end

function MapService.start()
	if started then
		return
	end

	started = true
	local existing = Workspace:FindFirstChild(MAP_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = MAP_FOLDER_NAME
	folder.Parent = Workspace
	buildArena(folder)
end

return MapService
