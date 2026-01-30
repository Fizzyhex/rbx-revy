--!nolint BuiltinGlobalWrite
-- contains all of revy's types.

if _G.ENGINE == "prison" then
	require = require("@self/../roblox_require") :: any
end

local jecs = require("@packages/jecs")
local planck = require("@packages/planck")
local replecs = require("@packages/replecs")
local event_util = require("@revy/events/event_util")

export type Phase = planck.Phase
export type SystemTable = planck.SystemTable<>
export type SystemFn = planck.SystemFn<>

export type NetworkContext = "server" | "client"

type function ResourceTable(resources: type)
	local resource_table = types.newtable()

	for key, property in resources:properties() do
		local read = property.read
		assert(read, "invalid resource (1)")

		-- (1: Key, 2: Value)
		local resource_type = read:components()[2]
		assert(resource_type, `missing generic from key`)

		-- Read Resource.__T
		local _, inner_type = next(resource_type:properties())
		assert(inner_type, "invalid resource (2)")
		assert(inner_type.read, "resource could not be read")
		local inner_type_value = inner_type.read
		assert(inner_type_value, "failed to read resource's data")

		resource_table:setproperty(key, inner_type_value)
	end

	return resource_table
end

export type Signal<T... = ...any> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	ConnectParallel: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	Wait: (self: Signal<T...>) -> T...,
}

--- Type for the first return value of collectors, created with `revy.collect`
export type Collector<T...> = () -> T...

type OptionalPluginCleanup = () -> ()?

--- User defined function that configures the plugin's data and (optionally) describes how to clean it up for hot-reloading.
export type PluginBuildFn<T, Addons...> = (plugin: T, Addons...) -> OptionalPluginCleanup | never

export type System = {
	type: "revy_system",
	id: string,
	system: SystemFn,
	-- interval: number?,
	-- set_interval: (self: System, interval: number) -> System,
}

export type PluginDef<App, Addons...> = {
	type: "revy_plugin_def",
	id: string,
	build: PluginBuildFn<Plugin<RevyApp>, Addons...>,
	addons: { [number]: (Plugin<App>) -> unknown },
}

export type Plugin<App> = {
	type: "revy_plugin",
	id: string,
	schedule: { [Schedule]: { [string]: System } },
	next_number: number,
	app: App,
	acquire_resources: <InputTable, Key, Value>(plugin: Plugin<App>, input: InputTable) -> ResourceTable<InputTable>,
	--- Adds a new system to be scheduled with a unique id. Create new systems with `revy.system`.
	add_system: (plugin: Plugin<App>, schedule: Schedule, def: System) -> (),
	cleanup: () -> (),

	--- Same as `World:added`, but automatically unregisters when the plugin is cleaned up for hot reloading support.
	world_added: <T>(
		plugin: Plugin<App>,
		jecs.Entity<T>,
		(e: jecs.Entity, id: jecs.Id<T>, value: T, oldarchetype: jecs.Archetype) -> ()
	) -> () -> (),
	--- Same as `World:removed`, but automatically unregisters when the plugin is cleaned up for hot reloading support.
	world_removed: <T>(plugin: Plugin<App>, jecs.Entity<T>, (e: jecs.Entity, id: jecs.Id<T>) -> ()) -> () -> (),
	--- Same as `World:changed`, but automatically unregisters when the plugin is cleaned up for hot reloading support.
	world_changed: <T>(
		plugin: Plugin<App>,
		jecs.Entity<T>,
		(e: jecs.Entity, id: jecs.Id<T>, value: T, oldarchetype: jecs.Archetype) -> ()
	) -> () -> (),
}

export type Resource<T = any> = { __T: T }

export type TextEntityContext = {
	name: string?,
	data: any,
}

export type TextEntityExporter = (data: any, entity_tree: { jecs.Entity }) -> any
export type TextEntityExport = jecs.Id<TextEntityExporter>

export type RevyApp<App = {}> = App & {
	world: jecs.World,

	-- Networking
	network: replecs.ReplecsLib,

	-- Debugging
	open_debugger: (self: RevyApp<App>) -> RevyApp<App>,
	bind_debugger: (self: RevyApp<App>, key: Enum.KeyCode) -> RevyApp<App>,

	-- Resources
	get_resource: <T>(self: RevyApp<App>, resource: Resource<T>) -> T,
	insert_resource: <T>(self: RevyApp<App>, resource: Resource<T>, data: T) -> RevyApp<App>,

	-- Events
	event_context: event_util.EventContext,
	event: <T, a>(self: RevyApp<App>, jecs.Entity<T>, component: jecs.Entity<a>, data: a?) -> jecs.Id<a>,
	event_consumer: (self: RevyApp<App>) -> event_util.EventConsumer,

	-- Shorthand
	--[=[
		Similar to `world:add`, but also adds a pair between `revy.reliable` (or an optionally provided `first_pair`) and your component.

		Equivilant to you doing:
		```luau
		app.world:add(entity, component)
		app.world:add(entity, jecs.pair(pair, component))
		```
	]=]
	net_add: <T, a>(
		self: RevyApp<App>,
		entity: jecs.Entity,
		component: jecs.Id<T>,
		first_pair: jecs.Id<a>?
	) -> jecs.Entity,
	--[=[
		Similar to `world:add`, but also adds a pair between `revy.reliable` (or an optionally provided `first_pair`) and your component.

		Equivilant to you doing:
		```luau
		app.world:set(entity, component, value)
		app.world:add(entity, jecs.pair(pair, component))
		```
	]=]
	net_set: <T, a>(
		self: RevyApp<App>,
		entity: jecs.Entity,
		component: jecs.Id<T>,
		value: T,
		first_pair: jecs.Id<a>?
	) -> jecs.Entity,

	-- Text Entities
	--[=[
# Text Entities

A `Text Entity` is an entity's data stored in a readable format, often parsed to a table by Rojo. This example uses `toml`.

Take this pseudo code for a 'fire' entity:

```lua
{
	Tag(Fire),
	Component(Damage, 20),
	Component(Radius, 4),
	Component(Transform, CFrame.new(2, 0, 0))
	Component(BallTouchTrigger, { offset = Vector3.new(0, -2, 0) })

	Component(FireVisualRbx, {
		part = Part,
		attachment = Attachment,
		emitter = Emitter
	})
	
	Component(BallTouchTriggerRbx, {
		part = Part
	})
}
```

Here's how we may represent it with a `Text Entity`:

```toml
tags = ["fire"]

[components]
Damage = 20
Radius = 4
Transform = [] # equivilant to CFrame.identity

[components.FireVisualRbx]
part = "/"
attachment = "/Attachment"
emitter = "/Attachment/Emitter"

[components.BallTouchTrigger]
part = "/part"
```

## Exporters

Text Entities's strictly only store plain old data. As a result, what you literally write in the toml file will be what you literally get in your created components.

This isn't always desired behaviour - for example here our `FireVisualRbx` represents paths to instances, and our `Transform` component represents a CFrame. We want CFrames and instances, not arrays of numbers and strings.

If you need to parse your data to something else, specify an exporter with `ecs.meta(component, revy.Export, exporter)`.

Default exporters can be found in `revy.exporters` - have a look before making your own!
	]=]
	load_text_entity: (
		self: RevyApp<App>,
		entity: jecs.Entity,
		text_entity: TextEntityContext,
		context: Instance
	) -> jecs.Entity,
}

-- Anything that can only happen before an app is ran goes here
export type RevyAppCommands = RevyApp<{
	add_plugins: (self: RevyAppCommands, ...PluginDef<RevyApp>) -> RevyAppCommands,
	enable_hot_reloading: (self: RevyAppCommands, ...Instance) -> RevyAppCommands,

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
	network_components: (self: RevyAppCommands, components: {}) -> RevyAppCommands,

	run: (self: RevyAppCommands) -> RevyApp,
}>

--[=[
	the schedule decides when a system should be executed.

	1. `addons` - ran once, for addons (such as the built-in resources) to load their stuff.
	2. `start` - ran once.
	3. `pre_render` - right before rendering is done.
	4. `first` - before other systems update.
	5. `events` - after events fire off.
	6. `update` - where most systems update.
	7. `last` - at the end, after everything else.

	`update` is generally a good place to start.
]=]
export type Schedule = "addons" | "start" | "pre_render" | "first" | "events" | "update" | "last"

-- Default components

export type Renderer = jecs.Id<Model>
export type Transform = jecs.Id<CFrame>

return nil
