local types = require("./types")

type Plugin = types.Plugin<types.RevyApp>

local function next_number(plugin: Plugin)
	plugin.next_number += 1
	return plugin.next_number
end

local function schedule_system(plugin: Plugin, schedule: types.Schedule, def: types.System)
	plugin.schedule[schedule] = plugin.schedule[schedule] or {}
	local schedule_id = `{plugin.id}.{def.id} (⟳ {schedule}) #{next_number(plugin)}`
	assert(plugin.schedule[schedule][schedule_id] == nil, `schedule already contains {schedule_id}!`)
	plugin.schedule[schedule][schedule_id] = def
end

local function acquire_resources<T...>(plugin: Plugin, fn: (T...) -> (), ...: T...)
	local name = `acquire_resources`
	local to_fetch: { unknown } = { ... }

	schedule_system(plugin, "start", {
		type = "revy_system" :: "revy_system",
		id = name,
		system = function()
			local gathered = {}

			for index, id in to_fetch do
				gathered[index] = plugin.app:get_resource(id :: any)
			end

			fn(table.unpack(gathered) :: any)
		end,
	})
end

local function build(plugin_def: types.PluginDef<types.RevyApp>, app: types.RevyApp)
	local plugin = {
		id = plugin_def.id,
		schedule = {},
		next_number = 0,
		app = app,
	} :: Plugin

	plugin.acquire_resources = acquire_resources
	plugin.add_system = schedule_system

	local cleanup = plugin_def.build(plugin)
	plugin.cleanup = if cleanup then cleanup else function() end

	return plugin
end

return {
	new = function(id: string, build_fn: types.PluginBuildFn<Plugin>)
		local plugin: types.PluginDef<types.RevyApp> = { type = "revy_plugin_def", id = id, build = build_fn }
		return plugin
	end,

	build = build,
}
