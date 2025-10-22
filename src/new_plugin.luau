local types = require("./types")

return function(id: string, build: types.PluginBuildFn)
	local plugin: types.Plugin = { type = "revy_plugin", id = id, build = build }
	return plugin
end
