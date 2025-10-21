local types = require("./types")

return function(_name: string, build: types.PluginBuildFn)
	local plugin: types.Plugin = { type = "revy_plugin", build = build }
	return plugin
end
