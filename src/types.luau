local jecs = require("@packages/jecs")
local planck = require("@packages/planck")

export type SystemFn = planck.SystemFn<>

export type PluginBuildFn = (app: RevyApp) -> ()

export type System = { type: "revy_system", system: SystemFn }

export type Plugin = {
	type: "revy_plugin",
	build: PluginBuildFn,
}

export type Resource<T = any> = string & { __T: T }

export type RevyApp = {
	world: jecs.World,
	add_plugin: (self: RevyApp, plugin: Plugin) -> RevyApp,
	add_systems: (self: RevyApp, schedule: Schedule, ...System) -> RevyApp,
	run: (self: RevyApp) -> RevyApp,
	open_debugger: (self: RevyApp) -> RevyApp,
	bind_debugger: (self: RevyApp, key: Enum.KeyCode) -> RevyApp,
	get_resource: <T>(self: RevyApp, resource: Resource<T>) -> T,
	insert_resource: <T>(self: RevyApp, resource: Resource<T>, data: T) -> RevyApp,
}

export type Schedule = "update" | "pre_render"

return nil
