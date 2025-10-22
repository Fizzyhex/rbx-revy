local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_CREATOR = Players.LocalPlayer == nil
local FOLDER_NAME = "revy_net"

local function with_folder(folder: Folder)
	local index = 0

	local function next_name()
		index += 1
		return tostring(index)
	end

	local function new_reliable()
		local name = next_name()

		if IS_CREATOR then
			local existing = folder:FindFirstChild(name)

			if existing then
				return existing :: RemoteEvent
			end

			local new = Instance.new("RemoteEvent")
			new.Name = name
			new.Parent = folder
			return new
		else
			return folder:WaitForChild(name) :: RemoteEvent
		end
	end

	local function new_unreliable()
		local name = next_name()

		if IS_CREATOR then
			local existing = folder:FindFirstChild(name)

			if existing then
				return existing :: UnreliableRemoteEvent
			end

			local new = Instance.new("UnreliableRemoteEvent")
			new.Name = name
			new.Parent = folder
			return new
		else
			return folder:WaitForChild(name) :: UnreliableRemoteEvent
		end
	end

	local function new_remote_function()
		local name = next_name()

		if IS_CREATOR then
			local existing = folder:FindFirstChild(name)

			if existing then
				return existing :: RemoteFunction
			end

			local new = Instance.new("RemoteFunction")
			new.Name = name
			new.Parent = folder
			return new
		else
			return folder:WaitForChild(name) :: RemoteFunction
		end
	end

	return {
		receive_full = new_remote_function(),
		collect_updates = new_reliable(),
		collect_unreliable = new_unreliable(),
	}
end

if IS_CREATOR then
	if ReplicatedStorage:FindFirstChild(FOLDER_NAME) then
		return with_folder(ReplicatedStorage:FindFirstChild(FOLDER_NAME))
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Archivable = false
	folder.Parent = ReplicatedStorage

	return with_folder(folder)
else
	return with_folder(ReplicatedStorage:WaitForChild(FOLDER_NAME))
end
