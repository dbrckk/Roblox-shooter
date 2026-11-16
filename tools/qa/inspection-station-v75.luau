local expectedSha = "7b8b8091c37c9751ab7b15d1ce5f9491f5602843"
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared", 15)
assert(shared, "No project modules in place")
assert(require(shared.BuildInfo).sourceSha == expectedSha, "Unexpected place source")

local arena = Workspace:FindFirstChild("NeonStrikeArena")
if not arena then
    local server = ServerScriptService:FindFirstChild("Server")
    assert(server and server:FindFirstChild("MapService"), "No arena entry point")
    require(server.MapService).start()
    arena = Workspace:FindFirstChild("NeonStrikeArena")
end
assert(arena, "Arena failed to build")
local decor = arena:FindFirstChild("NeonStrikeDecor")
local station = decor and decor:FindFirstChild("FREIGHT / Inspection station 04")
local cover = arena:FindFirstChild("VAULT / packing station")
assert(station and station:IsA("Model"), "No inspection station")
assert(cover and cover:IsA("BasePart"), "No cover collider")
assert(cover.Anchored and cover.CanCollide and cover.CanQuery and cover.Transparency == 1)
assert(cover.Position == Vector3.new(-10, 2.5, 82) and cover.Size == Vector3.new(14, 5, 9))
assert(cover:GetAttribute("MantleTarget") == true)

local visualParts, labels = 0, 0
for _, item in ipairs(station:GetDescendants()) do
    if item:IsA("BasePart") then
        assert(item.Anchored and not item.CanCollide and not item.CanTouch and not item.CanQuery,
            "Decorative geometry participates in physics: " .. item.Name)
        visualParts += 1
    elseif item:IsA("SurfaceGui") then
        labels += 1
    end
end
assert(visualParts == 90 and labels == 4, "Incomplete visual assembly")
for _, name in ipairs({ "Operator console", "Service hatch 1", "Service hatch 2", "Side amber marker", "Top deck inlay" }) do
    assert(station:FindFirstChild(name), "Missing " .. name)
end

local passes = 0
local up = Vector3.yAxis
local movement = require(shared.MovementConfig)
for _, normal in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
    local extent = math.abs(normal.X) * cover.Size.X / 2 + math.abs(normal.Z) * cover.Size.Z / 2
    local rootPosition = cover.Position + normal * (extent + 2) + up * 0.5
    local ray = Workspace:Raycast(rootPosition + up * 0.4, -normal * movement.mantleDistance)
    assert(ray and ray.Instance == cover and (ray.Normal - normal).Magnitude < 0.01,
        "Stand-height ray did not hit the authored collider")
    local height = cover.Position.Y + cover.Size.Y / 2 - (rootPosition.Y - 3)
    assert(height >= movement.mantleMinHeight and height <= movement.mantleMaxHeight,
        "Collider height is outside the live mantle rule")
    local edgeLanding = cover.Position + normal * (extent - 0.6)
    local down = Workspace:Raycast(edgeLanding + up * 7, -up * 6)
    assert(down and down.Instance == cover and math.abs(down.Position.Y - 5) < 0.001,
        "No solid mantle landing on the station")
    local clear = Workspace:Raycast(rootPosition + up * 2.24, -normal * (extent * 2 + 4))
    assert(not clear or clear.Instance ~= cover and not clear.Instance:IsDescendantOf(station),
        "Shots above the station should clear it")
    passes += 1
end
print(string.format("IRON YARD v75 engine OK: %d approach rays, %d landing probes, %d visual parts, %d labels",
    passes, passes, visualParts, labels))
return true
