local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Mode = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PracticeMode"))
local DummyService = require(script.Parent:WaitForChild("DummyService"))

local PracticeRange = {}
local rooms = {}
local occupied = {}

local STEEL = Color3.fromRGB(56, 66, 65)
local DARK = Color3.fromRGB(36, 44, 43)
local AMBER = Color3.fromRGB(228, 174, 89)
local PALE = Color3.fromRGB(246, 222, 177)

function PracticeRange.room(player)
    return rooms[player]
end

function PracticeRange.ownsTarget(player, model)
    local room = rooms[player]
    return room ~= nil and model.Parent == room.targets
end

function PracticeRange.contains(player, position)
    local room = rooms[player]
    if not room then return false end
    local offset = position - room.spawn
    return math.abs(offset.X) <= 26 and offset.Z >= -124 and offset.Z <= 8
        and offset.Y >= -3.4 and offset.Y <= 15
end

local function buildRoom(slot)
    local center = Vector3.new(2300 + ((slot - 1) % 8) * 112, 0, math.floor((slot - 1) / 8) * 192)
    local room = Instance.new("Model")
    room.Name = "PracticeBay"

    local function part(name, size, offset, color, material, decorative)
        local block = Instance.new("Part")
        block.Name = name
        block.Size = size
        block.Position = center + offset
        block.Color = color
        block.Material = material
        block.Anchored = true
        block.CanTouch = false
        if decorative then
            block.CanCollide = false
            block.CanQuery = false
        end
        block.Parent = room
        return block
    end

    part("ConcreteDeck", Vector3.new(54, 2, 132), Vector3.new(0, -1, -32), STEEL, Enum.Material.Concrete)
    part("Roof", Vector3.new(54, 2, 132), Vector3.new(0, 19, -32), DARK, Enum.Material.Metal)
    for _, side in ipairs({ -1, 1 }) do
        part("SideWall", Vector3.new(2, 18, 132), Vector3.new(side * 26, 9, -32), DARK, Enum.Material.Metal)
        for _, z in ipairs({ 24, 0, -24, -48, -72, -94 }) do
            part("SteelColumn", Vector3.new(2, 18, 2), Vector3.new(side * 24.5, 9, z), STEEL, Enum.Material.Metal)
        end
        part("LaneStripe", Vector3.new(0.22, 0.04, 108), Vector3.new(side * 20, 0.03, -33), AMBER, Enum.Material.SmoothPlastic, true)
    end
    part("EntryWall", Vector3.new(54, 18, 2), Vector3.new(0, 9, 33), DARK, Enum.Material.Metal)
    local backstop = part("Backstop", Vector3.new(54, 18, 2), Vector3.new(0, 9, -97), STEEL, Enum.Material.Metal)
    local sign = Instance.new("SurfaceGui")
    sign.Face = Enum.NormalId.Back
    sign.CanvasSize = Vector2.new(1080, 360)
    sign.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    sign.LightInfluence = 0.35
    sign.Parent = backstop
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromScale(0, 0.06)
    title.Size = UDim2.fromScale(1, 0.22)
    title.Text = "IRON YARD  /  PRACTICE RANGE"
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = PALE
    title.Parent = sign

    for _, z in ipairs({ 20, 0, -24, -48, -72, -90 }) do
        local fixture = part("CeilingLight", Vector3.new(36, 0.28, 0.45), Vector3.new(0, 17.7, z),
            PALE, Enum.Material.Neon, true)
        local light = Instance.new("SurfaceLight")
        light.Face = Enum.NormalId.Bottom
        light.Angle = 118
        light.Range = 26
        light.Brightness = 2
        light.Color = PALE
        light.Parent = fixture
    end
    for _, z in ipairs({ 12, -12, -36, -60, -84 }) do
        part("DistanceStripe", Vector3.new(40, 0.04, 0.14), Vector3.new(0, 0.04, z),
            AMBER, Enum.Material.SmoothPlastic, true)
    end
    local targets = Instance.new("Folder")
    targets.Name = "Targets"
    targets.Parent = room
    DummyService.populate(targets, center)
    -- Stream this room as a unit when the owner reaches it.
    room.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    room.Parent = Workspace
    return room, targets, center + Vector3.new(0, 3.4, 26)
end

local function publishStats(player, room)
    player:SetAttribute(Mode.STATS_ATTRIBUTE, string.format("%d:%d:%d:%d:%d",
        room.session, room.shots, room.hits, room.targetsDown, room.statsRevision))
end

function PracticeRange.record(player, shots, hits, targetsDown, launchedSession, launchedRevision)
    local room = rooms[player]
    if not room or (launchedSession and (launchedSession ~= room.session
        or launchedRevision ~= room.statsRevision)) then return end
    room.shots += shots
    room.hits += hits
    room.targetsDown += targetsDown
    publishStats(player, room)
end

function PracticeRange.resetStats(player, session, revision)
    local room = rooms[player]
    if not room or room.session ~= session or room.statsRevision ~= revision then return end
    room.shots, room.hits, room.targetsDown = 0, 0, 0
    room.statsRevision += 1
    publishStats(player, room)
end

function PracticeRange.enter(player, health, round)
    local slot = 1
    while occupied[slot] do slot += 1 end
    local model, targets, spawn = buildRoom(slot)
    local session = Mode.session(player) + 1
    local room = { model = model, targets = targets, spawn = spawn,
        slot = slot, health = health, round = round, session = session,
        shots = 0, hits = 0, targetsDown = 0, statsRevision = 0 }
    rooms[player] = room
    occupied[slot] = true
    publishStats(player, room)
    player:SetAttribute(Mode.ATTRIBUTE, session)
end

local function remove(player)
    local room = rooms[player]
    if not room then return end
    rooms[player] = nil
    occupied[room.slot] = nil
    room.model:Destroy()
end

function PracticeRange.leave(player)
    remove(player)
    player:SetAttribute(Mode.ATTRIBUTE, Mode.session(player) + 1)
    player:SetAttribute(Mode.STATS_ATTRIBUTE, nil)
end

Players.PlayerRemoving:Connect(remove)

return PracticeRange
