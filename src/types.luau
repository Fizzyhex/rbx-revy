local jecs = require("@packages/jecs")
local planck = require("@packages/planck")
local replecs = require("@packages/replecs")
local event_util = require("@revy/events/event_util")

export type SystemFn = planck.SystemFn<>

export type Signal<T... = ...any> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	ConnectParallel: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> RBXScriptConnection,
	Wait: (self: Signal<T...>) -> T...,
}

type OptionalPluginCleanup = () -> ()?
export type PluginBuildFn<T> = (app: T) -> OptionalPluginCleanup | never

export type System = { type: "revy_system", id: string, system: SystemFn }

export type Plugin<App> = {
	type: "revy_plugin",
	id: string,
	build: PluginBuildFn<App>,
}

export type Resource<T = any> = string & { __T: T }

export type TextEntityContext = {
	name: string?,
	data: any,
}

export type RevyApp<App = {}> = App & {
	world: jecs.World,

	-- Networking
	network: replecs.ReplecsLib,

	-- Scheduler
	add_systems: (self: RevyApp<App>, schedule: Schedule, ...System) -> RevyApp<App>,

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
	net_add: <T, a>(self: RevyApp<App>, entity: jecs.Entity, component: jecs.Id<T>, first_pair: jecs.Id<a>?) -> (jecs.Entity),
	--[=[
		Similar to `world:add`, but also adds a pair between `revy.reliable` (or an optionally provided `first_pair`) and your component.

		Equivilant to you doing:
		```luau
		app.world:set(entity, component, value)
		app.world:add(entity, jecs.pair(pair, component))
		```
	]=]
	net_set: <T, a>(entity: jecs.Entity, component: jecs.Id<T>, value: T, first_pair: jecs.Id<a>?) -> (jecs.Entity),

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
	network_components: (self: RevyAppCommands, components: {}) -> RevyAppCommands,

	run: (self: RevyAppCommands) -> RevyApp,
}>

export type Schedule = "start" | "pre_render" | "first" | "events" | "update" | "last"

--- Default components

export type Renderer = jecs.Id<Model>
export type Transform = jecs.Id<CFrame>

return nil
