-- IRON YARD competitive awareness HUD. Read-only client display;
-- all kills and bot standings originate from MatchService on the server.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local existingGui = player:WaitForChild("PlayerGui"):FindFirstChild("IronYardTacticalHUD")
if existingGui then existingGui:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "IronYardTacticalHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 16
gui.Parent = player:WaitForChild("PlayerGui")

local COLOR = {
    charcoal = Color3.fromRGB(37, 43, 43),
    slate = Color3.fromRGB(66, 72, 70),
    amber = Color3.fromRGB(224, 177, 89),
    bone = Color3.fromRGB(243, 239, 226),
    muted = Color3.fromRGB(185, 190, 183),
    own = Color3.fromRGB(126, 174, 131),
}

local function panel(name, position, size)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Position = position
    frame.Size = size
    frame.BackgroundColor3 = COLOR.charcoal
    frame.BackgroundTransparency = 0.10
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = frame

    local outline = Instance.new("UIStroke")
    outline.Color = COLOR.slate
    outline.Thickness = 1
    outline.Transparency = 0.25
    outline.Parent = frame
    return frame
end

local function label(parent, name, position, size, fontSize, color)
    local t = Instance.new("TextLabel")
    t.Name = name
    t.Position = position
    t.Size = size
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = fontSize
    t.TextColor3 = color or COLOR.bone
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Center
    t.TextTruncate = Enum.TextTruncate.AtEnd
    t.Text = ""
    t.Parent = parent
    return t
end

local board = panel("TopThree", UDim2.fromOffset(12, 94), UDim2.fromOffset(205, 123))
local header = label(board, "RankTitle", UDim2.fromOffset(10, 7), UDim2.fromOffset(188, 21), 12, COLOR.amber)
header.Text = "TOP OPERATORS"
local rankRows = {}
for i = 1, 3 do
    local y = 30 + (i - 1) * 28
    local name = label(board, "Rank" .. i, UDim2.fromOffset(10, y), UDim2.fromOffset(154, 25), 12)
    local score = label(board, "Kills" .. i, UDim2.fromOffset(167, y), UDim2.fromOffset(28, 25), 13, COLOR.amber)
    score.TextXAlignment = Enum.TextXAlignment.Right
    rankRows[i] = { name = name, score = score }
end

local locationPanel = panel("Sector", UDim2.fromOffset(12, 225), UDim2.fromOffset(205, 52))
local sectorTitle = label(locationPanel, "Location", UDim2.fromOffset(10, 4), UDim2.fromOffset(185, 25), 12, COLOR.bone)
local heading = label(locationPanel, "Heading", UDim2.fromOffset(10, 27), UDim2.fromOffset(185, 18), 10, COLOR.muted)

local scaling = Instance.new("UIScale")
scaling.Parent = board
local locationScale = Instance.new("UIScale")
locationScale.Parent = locationPanel
local function adjustScale()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local width, height = camera.ViewportSize.X, camera.ViewportSize.Y
    local scale = math.clamp(math.min(width / 1000, height / 600), 0.73, 1)
    scaling.Scale = scale
    locationScale.Scale = scale
    locationPanel.Position = UDim2.fromOffset(12, math.floor(94 + 131 * scale))
end

local function showStandings()
    local raw = Workspace:GetAttribute("IronYardStandings")
    local standings = {}
    if typeof(raw) == "string" then
        local success, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
        if success and typeof(parsed) == "table" then
            standings = parsed
        end
    end
    for i, row in ipairs(rankRows) do
        local entry = standings[i]
        if typeof(entry) == "table" then
            local own = entry.userId == player.UserId and not entry.bot
            row.name.Text = string.format("%d  %s", i, tostring(entry.name or "Operator"))
            row.name.TextColor3 = own and COLOR.own or COLOR.bone
            row.score.Text = tostring(math.max(0, tonumber(entry.eliminations) or 0))
        else
            row.name.Text = string.format("%d  ---", i)
            row.name.TextColor3 = COLOR.muted
            row.score.Text = "0"
        end
    end
    -- The onboarding mission card occupies this area on narrow phones.
    -- Show standings again immediately after the briefing fades.
    board.Visible = Workspace:GetAttribute("NeonMatchPhase") ~= "WAITING"
        and gui.Parent:GetAttribute("IronYardBriefingOpen") ~= true
end

local sectors = {
    { name = "WEST FREIGHT", test = function(x, z) return x < -83 and z > -70 end },
    { name = "EAST FREIGHT", test = function(x, z) return x > 83 and z > -70 end },
    { name = "WEST CATWALK", test = function(x, z) return x < -75 end },
    { name = "EAST CATWALK", test = function(x, z) return x > 75 end },
    { name = "LOADING BAY", test = function(x, z) return z > 66 end },
    { name = "RAIL APPROACH", test = function(x, z) return z < -70 end },
}
local compass = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

local function updatePosition()
    local model = player.Character
    local root = model and model:FindFirstChild("HumanoidRootPart")
    if not root then
        sectorTitle.Text = "SECTOR  /  DEPLOYING"
    else
        local x, z = root.Position.X, root.Position.Z
        local name = "PROCESSING FLOOR"
        for _, sector in ipairs(sectors) do
            if sector.test(x, z) then
                name = sector.name
                break
            end
        end
        sectorTitle.Text = "SECTOR  /  " .. name
    end
    local camera = Workspace.CurrentCamera
    if camera then
        local look = camera.CFrame.LookVector
        local deg = (math.deg(math.atan2(look.X, -look.Z)) + 360) % 360
        local section = math.floor((deg + 22.5) / 45) % 8 + 1
        heading.Text = string.format("HEADING %s  /  %03d", compass[section], math.floor(deg + 0.5))
    end
end

gui.Parent:GetAttributeChangedSignal("IronYardBriefingOpen"):Connect(showStandings)
Workspace:GetAttributeChangedSignal("IronYardStandings"):Connect(showStandings)
Workspace:GetAttributeChangedSignal("NeonMatchPhase"):Connect(showStandings)
showStandings()
adjustScale()
local camera = Workspace.CurrentCamera
if camera then
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(adjustScale)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    adjustScale()
end)
-- Throttled location UI: no per-frame parsing, no remote request.
task.spawn(function()
    while gui.Parent do
        updatePosition()
        task.wait(UserInputService.TouchEnabled and 0.4 or 0.25)
    end
end)
