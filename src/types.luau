local jecs = require("@packages/jecs")
local planck = require("@packages/planck")
local replecs = require("@packages/replecs")

export type SystemFn = planck.SystemFn<>

export type PluginBuildFn<T> = (app: T) -> ()

export type System = { type: "revy_system", id: string, system: SystemFn }

export type Plugin<App> = {
	type: "revy_plugin",
	build: PluginBuildFn<App>,
}

export type Resource<T = any> = string & { __T: T }

export type RevyApp<App = {}> = App & {
	world: jecs.World,
	network: replecs.ReplecsLib,
	add_systems: (self: RevyApp<App>, schedule: Schedule, ...System) -> RevyApp<App>,
	open_debugger: (self: RevyApp<App>) -> RevyApp<App>,
	bind_debugger: (self: RevyApp<App>, key: Enum.KeyCode) -> RevyApp<App>,
	get_resource: <T>(self: RevyApp<App>, resource: Resource<T>) -> T,
	insert_resource: <T>(self: RevyApp<App>, resource: Resource<T>, data: T) -> RevyApp<App>,
}

-- Anything that can only happen before an app is ran goes here
export type RevyAppCommands = RevyApp<{
	add_plugins: (self: RevyAppCommands, ...Plugin<RevyApp>) -> RevyAppCommands,
	enable_hot_reloading: (self: RevyAppCommands, container: Instance) -> RevyAppCommands,

	--[=[
		In-depth example: https://pepeeltoro41.github.io/replecs/started/summary/

		```luau
		local components = {
			position = world:component(),
			velocity = world:component(),
			player = world:component(),
			health = world:component(),
			alive = world:tag(),
		}

		revy:network_components(components)
		```
	]=]
	network_components: (self: RevyAppCommands, components: { [string]: jecs.Entity }) -> RevyAppCommands,

	run: (self: RevyAppCommands) -> RevyApp,
}>

export type Schedule = "update" | "pre_render" | "start" | "last" | "first"

--- Default components

export type Renderer = jecs.Entity<Model>
export type Transform = jecs.Entity<CFrame>

return nil
