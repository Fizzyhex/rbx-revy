--!nolint BuiltinGlobalWrite
if _G.ENGINE == "prison" then
	require = require("@self/../roblox_require") :: any
end

local t = require("@revy/types")

type Plugin = t.Plugin<t.RevyApp>

local function next_number(plugin: Plugin)
	plugin.next_number += 1
	return plugin.next_number
end

local function schedule_system(plugin: Plugin, schedule: t.Schedule, def: t.System)
	plugin.schedule[schedule] = plugin.schedule[schedule] or {}
	local schedule_id = `{plugin.id} > {def.id} ({schedule} {next_number(plugin)})`
	assert(plugin.schedule[schedule][schedule_id] == nil, `schedule already contains {schedule_id}!`)
	plugin.schedule[schedule][schedule_id] = def
end

local function acquire_resources<InputTable, Key, Value>(
	plugin: Plugin,
	input: InputTable & { [Key]: Value }
): { [keyof<InputTable>]: index<InputTable, Key> }
	local name = `acquire_resources`

	schedule_system(plugin, "start", {
		type = "revy_system" :: "revy_system",
		id = name,
		system = function()
			for key, id in input :: { [string]: any } do
				input[key] = plugin.app:get_resource(id :: any)
			end
		end,
	})

	return input :: any
end

local function build(plugin_def: t.PluginDef<t.RevyApp>, app: t.RevyApp)
	local hook_cleanup: { () -> () } = {}

	local function wrap_hook(hook_constructor)
		return function(_plugin, ...)
			local hook = hook_constructor(app.world, ...)
			table.insert(hook_cleanup, hook)
			return hook
		end
	end

	local plugin = {
		id = plugin_def.id,
		schedule = {},
		next_number = 0,
		app = app,

		world_added = wrap_hook(app.world.added),
		world_removed = wrap_hook(app.world.removed),
		world_changed = wrap_hook(app.world.changed),
	} :: Plugin

	plugin.acquire_resources = acquire_resources :: any
	plugin.add_system = schedule_system

	local extra_args = {}

	for index, addon in plugin_def.addons do
		print("addons", plugin_def.addons)
		extra_args[index] = addon(plugin)
	end

	local custom_cleanup_fn = plugin_def.build(plugin :: any, table.unpack(extra_args))

	plugin.cleanup = function()
		for _, cleanup_fn in hook_cleanup do
			cleanup_fn()
		end

		if custom_cleanup_fn then
			custom_cleanup_fn()
		end
	end

	return plugin
end

return {
	new = function<Addons...>(id: string, build_fn: t.PluginBuildFn<Plugin, Addons...>, ...: Addons...)
		local plugin: t.PluginDef<t.RevyApp, Addons...> =
			{ type = "revy_plugin_def", id = id, build = build_fn, addons = { ... :: any } }
		return plugin
	end,

	build = build,
}
