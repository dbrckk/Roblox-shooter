local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Mode = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PracticeMode"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponConfig"))
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
    return room, targets, center + Vector3.new(0, 3.4, 26), center
end

local function publishStats(player, room)
    -- Replicate the totals, reset revision and weapon counts together.
    local snapshot = { string.format("%d:%d:%d:%d:%d",
        room.session, room.shots, room.hits, room.targetsDown, room.statsRevision) }
    for _, weaponId in ipairs(WeaponConfig.Order) do
        local stats = room.weaponStats[weaponId]
        if stats then
            table.insert(snapshot, string.format("%s:%d:%d:%d", weaponId, stats.shots, stats.hits, stats.targetsDown))
        end
    end
    player:SetAttribute(Mode.STATS_ATTRIBUTE, table.concat(snapshot, ";"))
end

local function publishDrill(player, room)
    local drill = room.drill
    local result = drill.newBest and 2 or (drill.finished and 1 or 0)
    player:SetAttribute(Mode.DRILL_ATTRIBUTE, string.format("%d:%d:%d:%d:%d:%d:%d:%d",
        room.session, drill.id, drill.startsAtMs, drill.endsAtMs,
        drill.shots, drill.hits, drill.targetsDown, result))
end

local function finalizeDrill(player, drill)
    drill.finished = true
    if drill.targetsDown == 0 then return end
    local best = Mode.drillBest(player)
    if best then
        local moreTargets = drill.targetsDown > best.targetsDown
        local accuracyWinsTie = drill.targetsDown == best.targetsDown
            and drill.hits * best.shots > best.hits * drill.shots
        if not moreTargets and not accuracyWinsTie then return end
    end

    drill.newBest = true
    player:SetAttribute(Mode.DRILL_BEST_ATTRIBUTE,
        string.format("%d:%d:%d", drill.shots, drill.hits, drill.targetsDown))
end

function PracticeRange.startDrill(player, session, previousId)
    local room = rooms[player]
    if not room or room.session ~= session then return end
    local previous = room.drill
    if previousId ~= (previous and previous.id or 0) or (previous and not previous.finished) then return end

    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not head or not humanoid or humanoid.Health <= 0
        or not PracticeRange.contains(player, head.Position) then return end

    room.targets:ClearAllChildren()
    DummyService.populate(room.targets, room.origin)
    local startsAtMs = math.ceil(Workspace:GetServerTimeNow() * 1000) + Mode.DRILL_COUNTDOWN * 1000
    local drill = {
        id = previousId + 1, startsAtMs = startsAtMs, endsAtMs = startsAtMs + Mode.DRILL_SECONDS * 1000,
        shots = 0, hits = 0, targetsDown = 0, finished = false,
    }
    room.drill = drill
    publishDrill(player, room)
    local function finish()
        drill.finishTask = nil
        if rooms[player] ~= room or room.drill ~= drill then return end
        local remaining = drill.endsAtMs / 1000 - Workspace:GetServerTimeNow()
        if remaining > 0 then
            drill.finishTask = task.delay(remaining, finish)
            return
        end
        finalizeDrill(player, drill)
        publishDrill(player, room)
    end
    finish()
end

function PracticeRange.drillId(player)
    local room = rooms[player]
    return room and room.drill and room.drill.id
end

function PracticeRange.permitsFire(player, drillId)
    local room = rooms[player]
    local drill = room and room.drill
    if not drill then return drillId == nil end
    return drill.id == drillId and Workspace:GetServerTimeNow() >= drill.startsAtMs / 1000
end

function PracticeRange.record(player, weaponId, shots, hits, targetsDown, launchedSession, launchedRevision, launchDrillId)
    local room = rooms[player]
    if not room or (launchedSession and (launchedSession ~= room.session
        or launchedRevision ~= room.statsRevision)) then return end
    room.shots += shots
    room.hits += hits
    room.targetsDown += targetsDown
    local stats = room.weaponStats[weaponId]
    if not stats then
        stats = { shots = 0, hits = 0, targetsDown = 0 }
        room.weaponStats[weaponId] = stats
    end
    stats.shots += shots
    stats.hits += hits
    stats.targetsDown += targetsDown
    publishStats(player, room)

    local drill = room.drill
    if drill and not drill.finished and (not launchedSession or launchDrillId == drill.id) then
        local now = Workspace:GetServerTimeNow()
        if now >= drill.startsAtMs / 1000 and now < drill.endsAtMs / 1000 then
            drill.shots += shots
            drill.hits += hits
            drill.targetsDown += targetsDown
            publishDrill(player, room)
        end
    end
end

function PracticeRange.resetStats(player, session, revision)
    local room = rooms[player]
    if not room or room.session ~= session or room.statsRevision ~= revision then return end
    room.shots, room.hits, room.targetsDown = 0, 0, 0
    table.clear(room.weaponStats)
    room.statsRevision += 1
    publishStats(player, room)
end

function PracticeRange.enter(player, health, round)
    local slot = 1
    while occupied[slot] do slot += 1 end
    local model, targets, spawn, origin = buildRoom(slot)
    local session = Mode.session(player) + 1
    local room = { model = model, targets = targets, spawn = spawn, origin = origin,
        slot = slot, health = health, round = round, session = session,
        shots = 0, hits = 0, targetsDown = 0, statsRevision = 0, weaponStats = {} }
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
    if room.drill and room.drill.finishTask then task.cancel(room.drill.finishTask) end
    room.model:Destroy()
end

function PracticeRange.leave(player)
    local room = rooms[player]
    local drill = room and room.drill
    if drill and not drill.finished and Workspace:GetServerTimeNow() >= drill.endsAtMs / 1000 then
        finalizeDrill(player, drill)
    end
    remove(player)
    player:SetAttribute(Mode.ATTRIBUTE, Mode.session(player) + 1)
    player:SetAttribute(Mode.STATS_ATTRIBUTE, nil)
    player:SetAttribute(Mode.DRILL_ATTRIBUTE, nil)
end

Players.PlayerRemoving:Connect(remove)

return PracticeRange
