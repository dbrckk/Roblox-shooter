local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrecisionNet = {}

local REMOTE_FOLDER_NAME = "PrecisionRemotes"
local REMOTES = {
	EquipWeapon = "RemoteEvent",
	FireWeapon = "RemoteEvent",
    ReloadWeapon = "RemoteEvent",
	MovementAction = "RemoteEvent",
	MovementState = "RemoteEvent",
	SetSprinting = "RemoteEvent",
	WeaponFeedback = "RemoteEvent",
	WeaponFx = "RemoteEvent",
    KillFeed = "RemoteEvent",
}

local function getOrCreateRemote(folder, remoteName, className, shouldCreate)
	local remote = folder:FindFirstChild(remoteName)
	if remote then
		return remote
	end

	if shouldCreate then
		remote = Instance.new(className)
		remote.Name = remoteName
		remote.Parent = folder
		return remote
	end

	return folder:WaitForChild(remoteName)
end

function PrecisionNet.getRemotes(shouldCreate)
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if not folder and shouldCreate then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	if not folder then
		folder = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME)
	end

	local remotes = {
		Folder = folder,
	}

	for remoteName, className in pairs(REMOTES) do
		remotes[remoteName] = getOrCreateRemote(folder, remoteName, className, shouldCreate)
	end

	return remotes
end

return PrecisionNet
