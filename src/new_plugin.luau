local types = require("./types")

return function(id: string, build: types.PluginBuildFn<types.RevyApp>)
	local plugin: types.Plugin<types.RevyApp> = { type = "revy_plugin", id = id, build = build }
	return plugin
end
