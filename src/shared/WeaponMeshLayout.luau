-- IRON YARD / resilient, deterministic GLB component grouping policy.
-- Roblox glTF importer nests a Model per authored mesh and creates a
-- MeshPart for EACH glTF material primitive. Never assume one part per node.
local Layout = {}
Layout.ORIGIN_NAME = "IRONYARD_WeaponOrigin"
Layout.MAX_PER_COMPONENT = 8
Layout.MAX_TOTAL = 32

function Layout.componentName(candidate, required)
    if type(candidate) ~= "string" or type(required) ~= "table" then
        return nil
    end
    for _, name in ipairs(required) do
        if candidate == name or candidate == name .. "_Node" then
            return name
        end
    end
    return nil
end

-- Returns { [authored_component_name] = { MeshPart, ... } } or nil.
-- Name validation happens on an ancestor Model first, because Roblox may
-- rename MeshPart primitives inside the authored *_Node Model. Unknown
-- meshes are ignored; malformed or duplicated known components fail closed.
function Layout.collect(root, required, validate)
    if not root or type(required) ~= "table" or type(validate) ~= "function" then
        return nil
    end
    local groups = {}
    local owners = {}
    local count = 0
    for _, part in ipairs(root:GetDescendants()) do
        if part:IsA("MeshPart") then
            local key, owner = nil, nil
            local parent = part.Parent
            while parent and parent ~= root do
                if (parent:IsA("Model") or parent:IsA("Folder")) then
                    key = Layout.componentName(parent.Name, required)
                    if key then
                        owner = parent
                        break
                    end
                end
                parent = parent.Parent
            end
            if not key then
                key = Layout.componentName(part.Name, required)
                owner = part
            end
            if key then
                if owners[key] and owners[key] ~= owner then return nil end
                owners[key] = owner
                if not validate(part) then return nil end
                if not groups[key] then groups[key] = {} end
                if #groups[key] >= Layout.MAX_PER_COMPONENT then return nil end
                count += 1
                if count > Layout.MAX_TOTAL then return nil end
                table.insert(groups[key], part)
            end
        end
    end
    for _, name in ipairs(required) do
        if not groups[name] or #groups[name] == 0 then return nil end
    end
    return groups
end

-- Roblox may wrap uploaded Models and recenter Model:GetPivot().
-- The authored marker is a tiny physical mesh, so it survives glTF import.
-- Exactly ONE marker must remain, regardless of Model nesting.
function Layout.origin(root, validate)
    if type(validate) ~= "function" then return nil end
    local groups = Layout.collect(root, {Layout.ORIGIN_NAME}, validate)
    if not groups then return nil end
    local matches = groups[Layout.ORIGIN_NAME]
    return matches and #matches == 1 and matches[1] or nil
end

return Layout
