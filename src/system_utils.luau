local planck = require("@packages/planck")
local types = require("./types")

local system_utils = {}

function system_utils.to_planck(system: types.System)
	return system.system :: planck.SystemFn<>
end

return system_utils
