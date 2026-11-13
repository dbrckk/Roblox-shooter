-- IRON YARD / discreet opt-in profiling tool for owner and Studio only.
-- Hidden for the public, including all ordinary Android players.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

if not RunService:IsStudio() and not (
    game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0
    and player.UserId == game.CreatorId) then return end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PrecisionNet = require(Shared:WaitForChild("PrecisionNet"))
local FrameWindow = require(Shared:WaitForChild("ClientFrameWindow"))
local WeaponSwapMetrics = require(Shared:WaitForChild("WeaponSwapMetrics"))
local WorldPbrPolicy = require(Shared:WaitForChild("WorldPbrPolicy"))
local remote = PrecisionNet.getRemotes(false).PerformanceDiagnostics

local gui = Instance.new("ScreenGui")
gui.Name = "IronYardPrivatePerformance"
gui.IgnoreGuiInset = false
gui.DisplayOrder = 80
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local toggle = Instance.new("TextButton")
toggle.Name = "PerfToggle"
toggle.Size = UDim2.fromOffset(57, 28)
toggle.Position = UDim2.fromOffset(12, 66)
toggle.BackgroundColor3 = Color3.fromRGB(35, 45, 47)
toggle.TextColor3 = Color3.fromRGB(245, 225, 170)
toggle.BorderSizePixel = 0
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 13
toggle.Text = "PERF"
toggle.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PerformancePanel"
panel.Visible = false
-- PERF is owner-only and must remain usable on compact landscape phones.
-- A fixed 485px panel previously extended below the physical viewport.
panel.Size = UDim2.new(0, 300, 1, -110)
panel.Position = UDim2.fromOffset(12, 100)
local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MaxSize = Vector2.new(300, 485)
panelLimit.Parent = panel
panel.BackgroundColor3 = Color3.fromRGB(21, 29, 33)
panel.BackgroundTransparency = 0.07
panel.BorderSizePixel = 0
panel.Parent = gui

local scroller = Instance.new("ScrollingFrame")
scroller.Name = "DiagnosticsScroll"
scroller.Size = UDim2.fromScale(1, 1)
scroller.CanvasSize = UDim2.fromOffset(0, 0)
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.ScrollingDirection = Enum.ScrollingDirection.Y
scroller.ScrollBarThickness = 4
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.Parent = panel

local label = Instance.new("TextLabel")
label.Name = "Diagnostics"
label.BackgroundTransparency = 1
label.Position = UDim2.fromOffset(10, 8)
label.Size = UDim2.new(1, -24, 0, 0)
label.AutomaticSize = Enum.AutomaticSize.Y
label.TextColor3 = Color3.fromRGB(223, 231, 219)
label.Font = Enum.Font.Code
label.TextSize = 12
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.TextWrapped = false
label.Text = "IRON YARD / DIAGNOSTICS\nActivation en cours..."
label.Parent = scroller

local active = false
local lastPacket = nil
local frameWindow = FrameWindow.new()
local frameSeconds = 0
local latestFrameStats = nil
local CLIENT_PERF_ATTRIBUTES = {
    "IronYardPerfWeaponSamples", "IronYardPerfWeaponMeanMs",
    "IronYardPerfWeaponPeakMs", "IronYardPerfWeaponParts",
    "IronYardPerfWeaponId", "IronYardPerfWeaponSource",
    "IronYardPerfFxActive", "IronYardPerfFxCap",
    "IronYardPerfRemoteAudioRefs",
}
local function clearClientWeaponReadings()
    for _, name in ipairs(CLIENT_PERF_ATTRIBUTES) do
        player:SetAttribute(name, nil)
    end
end

local function weaponMetrics()
    local samples = player:GetAttribute("IronYardPerfWeaponSamples")
    if type(samples) ~= "number" or samples < 1 then
        return "Arme: mesures en cours..."
    end
    return string.format(
        "Arme %s / %s: %d pieces\n"
        .. "CPU arme: %.2fms moy | %.2fms pic\n"
        .. "Effets transitoires: %d / %d\n"
        .. "Audio distant: %d refs",
        player:GetAttribute("IronYardPerfWeaponId") or "?",
        player:GetAttribute("IronYardPerfWeaponSource") or "?",
        player:GetAttribute("IronYardPerfWeaponParts") or 0,
        player:GetAttribute("IronYardPerfWeaponMeanMs") or 0,
        player:GetAttribute("IronYardPerfWeaponPeakMs") or 0,
        player:GetAttribute("IronYardPerfFxActive") or 0,
        player:GetAttribute("IronYardPerfFxCap") or 0,
        player:GetAttribute("IronYardPerfRemoteAudioRefs") or 0)
end


-- Server-owned material/weapon delivery diagnostics. No asset IDs, credentials,
-- raw server error messages or extra network traffic are exposed to the client.
local function weaponDeliverySnapshot()
    local states = {}
    for _, weaponId in ipairs({ "AssaultRifle", "Pistol", "Shotgun", "Sniper", "Knife" }) do
        local state = Workspace:GetAttribute("IronYardWeaponState_" .. weaponId)
        table.insert(states, weaponId .. ": " .. tostring(state or "UNKNOWN"))
    end
    return string.format(
        "\n--- ARMES PBR (serveur) ---\n%s: %s/%d disponibles\n%s",
        tostring(Workspace:GetAttribute("IronYardWeaponMeshStatus") or "UNKNOWN"),
        tostring(Workspace:GetAttribute("IronYardWeaponMeshReadyCount") or 0),
        5, table.concat(states, "  |  "))
end

-- Private and opt-in only: count locally replicated bot visuals without
-- scanning server hitboxes on every frame or exposing account data.
local function pbrSnapshot()
    local kit = tostring(Workspace:GetAttribute("IronYardPbrStatus") or "UNKNOWN")
    local world = tostring(Workspace:GetAttribute("IronYardWorldPbrStatus") or "UNKNOWN")
    local folder = Workspace:FindFirstChild("NeonStrikeBots")
    local total, imported, primitives, details, visible = 0, 0, 0, 0, 0
    if folder then
        for _, bot in ipairs(folder:GetChildren()) do
            if bot:IsA("Model") and bot:GetAttribute("IsArenaBot") == true then
                total += 1
                if bot:GetAttribute("NeonVisualSource") == "PBR_MESH" then
                    imported += 1
                    for _, child in ipairs(bot:GetDescendants()) do
                        if child:IsA("MeshPart")
                            and child:GetAttribute("NeonCosmeticTier") ~= nil then
                            primitives += 1
                            if child:GetAttribute("NeonCosmeticTier") == "Detail" then
                                details += 1
                                if child.LocalTransparencyModifier < 0.5 then
                                    visible += 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- Distinguish missing imports from a bad-looking material. This runs
    -- only while the owner explicitly keeps PERF open: no gameplay polling,
    -- new network messages or GPU readbacks.
    local worldTagged, worldRendered = 0, 0
    local roofTagged, roofRendered = 0, 0
    local byFamily = {}
    for _, style in ipairs(WorldPbrPolicy.Materials) do
        byFamily[style.key] = { tagged = 0, rendered = 0 }
    end
    for _, part in ipairs(CollectionService:GetTagged("IronYardWorldPbr")) do
        if part:IsA("BasePart") and part:IsDescendantOf(Workspace) then
            worldTagged += 1
            local key = part:GetAttribute("IronYardPbrMaterial")
            local group = type(key) == "string" and byFamily[key] or nil
            if group then group.tagged += 1 end
            local applied = group ~= nil
                and part.MaterialVariant == WorldPbrPolicy.variantName(key)
            if applied then
                worldRendered += 1
                group.rendered += 1
            end
            if part.Name:find("ROOF / pitched corrugated shell", 1, true) == 1 then
                roofTagged += 1
                if applied then roofRendered += 1 end
            end
        end
    end
    local familyLines = {}
    for _, style in ipairs(WorldPbrPolicy.Materials) do
        local group = byFamily[style.key]
        table.insert(familyLines, string.format("%s: %d/%d",
            style.key, group.rendered, group.tagged))
    end
    return string.format(
        "\n--- PBR (ce client uniquement) ---\n"
        .. "Kit: %s | bots PBR: %d/%d\n"
        .. "Meshes: %d | Detail visible: %d/%d\n"
        .. "Decor: %s | PBR local: %d/%d\n%s\nRoof: %d/%d",
        kit, imported, total, primitives, visible, details, world,
        worldRendered, worldTagged, table.concat(familyLines, "\n"),
        roofRendered, roofTagged) .. weaponDeliverySnapshot()
end

-- These readings are client-local and only polled with the private panel.
-- Total RAM includes the whole Roblox process, not weapon-cache bytes alone.
local function localSwapSummary()
    local data = WeaponSwapMetrics.snapshot()
    if not data then return "" end
    local ok, value = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
    local ram = ok and type(value) == "number" and value == value
        and value >= 0 and value < math.huge
        and string.format("%.0f MB", value) or "n/a"
    local cached = data.cachedParts and tostring(data.cachedParts) or "?"
    return string.format(
        "\n--- ARMES (local) ---\n"
        .. "A/B recycles: %d | rebuilds: %d\n"
        .. "Recycle 48 moy/P95: %.1f / %.1fms\n"
        .. "Build 48 moy/P95: %.1f / %.1fms\n"
        .. "LOD: %d | cache: %s pieces\n"
        .. "RAM client TOTAL: %s",
        data.reuse.count, data.build.count,
        data.reuse.windowMeanMs, data.reuse.p95Ms,
        data.build.windowMeanMs, data.build.p95Ms,
        data.lod.count, cached, ram)
end

local function updateLabel()
    if not active then return end
    local p = lastPacket
    if not p or not p.rates or not p.timings then
        local frames = latestFrameStats
        label.Text = string.format(
            "IRON YARD / PRIVATE PROFILER\n"
            .. "FPS client: %.0f | P95: %.0fms\n"
            .. "P99: %.0fms\n"
            .. "%s\n\n"
            .. "Statistiques serveur en cours...",
            frames and frames.fps or 0,
            frames and frames.p95Ms or 0,
            frames and frames.p99Ms or 0,
            weaponMetrics()) .. pbrSnapshot() .. localSwapSummary()
        return
    end
    local r, t = p.rates, p.timings
    local frames = latestFrameStats
    local fps = frames and frames.fps or 0
    local framePeak = frames and frames.peakMs or 0
    local p95 = frames and frames.p95Ms or 0
    local p99 = frames and frames.p99Ms or 0
    local slow = frames and frames.slow33 or 0
    local samples = frames and frames.count or 0
    local rays = (r.targetRay or 0) + (r.navRay or 0)
        + (r.tacticsRay or 0) + (r.muzzleRay or 0) + (r.shotRay or 0)
    local think = t.thinkMs or {}
    local pose = t.poseMs or {}
    local path = t.pathMs or {}
    label.Text = string.format(
        "IRON YARD / PRIVATE PROFILER\n"
        .. "FPS client: %4.0f   pic: %.0fms\n"
        .. "P95: %.0fms  P99: %.0fms\n"
        .. ">33ms: %d / %d images\n"
        .. "Bots actifs: %d\n"
        .. "Raycasts IA: %.1f/s\n"
        .. "  vision %.1f | nav %.1f\n"
        .. "  tact %.1f | tirs %.1f\n"
        .. "Navmesh: %.1f/s | diff %.1f/s\n"
        .. "Path ms: %.1f avg / %.1f pic\n"
        .. "MoveTo: %.1f/s\n"
        .. "IA ms: %.1f avg / %.1f pic\n"
        .. "Pose ms: %.1f avg / %.1f pic\n"
        .. "Pose: %.1f/s | Feu: %.1f/s\n"
        .. "%s",
        fps, framePeak, p95, p99, slow, samples,
        p.bots or 0, rays,
        r.targetRay or 0, r.navRay or 0,
        r.tacticsRay or 0, (r.muzzleRay or 0) + (r.shotRay or 0),
        r.pathStarted or 0, r.pathDeferred or 0,
        path.mean or 0, path.peak or 0,
        r.moveIssued or 0,
        think.mean or 0, think.peak or 0,
        pose.mean or 0, pose.peak or 0,
        r.pose or 0, r.botShot or 0,
        weaponMetrics()) .. pbrSnapshot() .. localSwapSummary()
end

remote.OnClientEvent:Connect(function(packet)
    if not active or typeof(packet) ~= "table" then return end
    if packet.status == "OFF" then
        WeaponSwapMetrics.enable(false)
        active = false
        panel.Visible = false
        toggle.Text = "PERF"
        player:SetAttribute("IronYardPrivatePerfActive", false)
        return
    end
    if packet.status == "ON" and packet.rates then
        lastPacket = packet
        updateLabel()
    end
end)

toggle.Activated:Connect(function()
    active = not active
    WeaponSwapMetrics.enable(active)
    panel.Visible = active
    toggle.Text = active and "CLOSE" or "PERF"
    player:SetAttribute("IronYardPrivatePerfActive", active)
    if active then
        clearClientWeaponReadings()
        lastPacket = nil
        FrameWindow.clear(frameWindow)
        latestFrameStats = nil
        frameSeconds = 0
        updateLabel()
    end
    remote:FireServer(active and "start" or "stop")
end)

RunService.RenderStepped:Connect(function(dt)
    if not active then return end
    local accepted, restarted = FrameWindow.push(frameWindow, dt)
    if restarted then
        -- The phone was backgrounded (or returned an invalid frame delta).
        -- Old FPS, weapon CPU and server timings must not masquerade as a
        -- freshly measured in-game second after the player resumes.
        frameSeconds = 0
        latestFrameStats = nil
        lastPacket = nil
        clearClientWeaponReadings()
        updateLabel()
    end
    if not accepted then return end
    frameSeconds += dt
    if frameSeconds >= 1.0 then
        latestFrameStats = FrameWindow.snapshot(frameWindow)
        frameSeconds %= 1.0
        updateLabel()
    end
end)
