-- whoever decided on the shitty '@self' syntax instead of just doing what everyone else was
-- already doing, it totallyy doesn't come of as yet another move to keep people within
-- the walled garden that is the roblox eco-system.
--
-- you can prob solve this more cleanly with OSS tooling in the future.
return function(path: string)
	if typeof(path) ~= "string" then
		return require(path)
	end

	local new_path = path:gsub("@revy", "@self/../"):gsub("@packages", "@self/../../roblox_packages")
	return require(new_path)
end :: typeof(require)
