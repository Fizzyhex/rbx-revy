--!nolint BuiltinGlobalWrite
if _G.ENGINE == "prison" then
	require = require("@self/../roblox_require") :: any
end

local planck = require("@packages/planck")

local types = require("@revy/types")

local system_utils = {}

function system_utils.to_planck(system: types.System)
	return system.system :: planck.SystemFn<>
end

return system_utils
