local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local make_jabby_remotes = require("@self/make_jabby_remotes")

do
	if RunService:IsServer() and not ReplicatedStorage:FindFirstChild("JABBY_REMOTES") then
		make_jabby_remotes().Parent = ReplicatedStorage
	end
end

local jabby, planck, planck_jabby, planck_run_service, rewire

-- Darklua flag - lowers the amount of types that need to be loaded by the requirer for language
-- server performance.
if not _G.REVY_OPTIMISE_REQUIRES then
	jabby = require("@packages/jabby")
	planck = require("@packages/planck")
	planck_jabby = require("@packages/planck_jabby")
	planck_run_service = require("@packages/planck_runservice")
	rewire = require("@packages/rewire")
else
	local roblox_packages = script.Parent.roblox_packages
	local untyped_require = require :: any

	jabby = untyped_require(roblox_packages.jabby)
	planck = untyped_require(roblox_packages.planck)
	planck_jabby = untyped_require(roblox_packages.planck_jabby)
	planck_run_service = untyped_require(roblox_packages.planck_runservice)
	rewire = untyped_require(roblox_packages.rewire)
end

local replecs = require("@packages/replecs")
local jecs = require("@packages/jecs")

local event_util = require("@revy/events/event_util")
local logger = require("@revy/log/logger")
local text_entity_default_parsers = require("@revy/text_entity/text_entity_default_parsers")

local collect = require("@self/collect")
local interval = require("@self/interval")
local new_plugin = require("@self/new_plugin")
local remotes = require("@self/remotes")
local types = require("@self/types")
local bundles = require("@self/bundles/bundles")
local jecs_internal = require("@self/jecs_internal")

export type Archetype = jecs.Archetype
export type QueryInner = jecs.QueryInner
export type Entity<T = any> = jecs.Entity<T>
export type Id<T = any> = jecs.Id<T>
export type Pair<P, O> = jecs.Pair<P, O>
export type Item<T...> = jecs.Item<T...>
export type Iter<T...> = jecs.Iter<T...>
export type Query<T...> = jecs.Query<T...>
export type Observer = jecs.Observer
export type observer = jecs.observer
export type World = jecs.World
export type Record = jecs.Record
export type ComponentRecord = jecs.ComponentRecord
export type ComponentIndex = jecs.ComponentIndex
export type Archetypes = jecs.Archetypes
export type EntityIndex = jecs.EntityIndex

type SystemFn = types.SystemFn
export type RevyApp = types.RevyApp<{}>
export type RevyAppCommands = types.RevyAppCommands
export type System = types.System
export type Schedule = types.Schedule
export type PluginDef = types.PluginDef<RevyApp>
export type Plugin = types.Plugin<RevyApp>
export type Resource<T = any> = types.Resource<T>
export type Signal<T... = ...any> = types.Signal<T...>

export type Bundle<T...> = bundles.Bundle<T...>

local schedule_phase_map = {
	start = planck.Phase.Startup,
	first = planck_run_service.Phases.First,
	events = planck_run_service.Phases.PreUpdate,
	update = planck_run_service.Phases.Update,
	last = planck_run_service.Phases.Last,
	pre_render = planck_run_service.Phases.PreRender,
}

local DO_NOTHING = function() end

local updates_interval = interval(1 / 20)
local unreliables_interval = interval(1 / 30)

local revy = {
	--- This is Jecs. Docs: https://ukendio.github.io/jecs/
	ecs = jecs,
}

revy.bundles = bundles
revy.plugin = new_plugin.new
revy.collect = collect
revy.interval = interval
revy.exporters = text_entity_default_parsers

local Export = jecs.component() :: Id
local text_entity_util = require("@self/text_entity/text_entity_util")(Export)

--[=[
	Creates a new `Text Entity`.

	Provide a name for improved logging.
]=]
function revy.text_entity(data: any, name: string?): types.TextEntityContext
	return {
		data = data,
		name = name,
	}
end

--[=[
	Sugar for `revy.ecs.meta(component, revy.Export, exporter_fn)` - but may provide better types.
]=]
function revy.set_exporter(id: jecs.Id, exporter: types.TextEntityExporter)
	return jecs.meta(id, revy.Export, exporter)
end

local function new_system(id: string, func: (world: jecs.World) -> ())
	local system: types.System = { type = "revy_system", id = id, system = func :: SystemFn }
	return system
end

local function new_system_unnamed(func: (world: jecs.World) -> ())
	local system: types.System = { type = "revy_system", id = "system", system = func :: SystemFn }
	return system
end

--- Defines a new system
revy.system = new_system_unnamed
--- Defines a new system with the provided name
revy.named_system = new_system

-- type inference is bad with this :(
-- revy.system = function(a, b)
-- 	if typeof(a) == "string" then
-- 		return new_system(a, b)
-- 	else
-- 		return new_system_unnamed(a)
-- 	end
-- end :: ((func: (world: jecs.World) -> ()) -> System) & (id: string, func: (world: jecs.World) -> ()) -> System

--[=[
Defines a new resource. Resources are plugin-managed data that can be shared between plugins.

```luau
export type DialogResourceData = {
	say: (entity: revy.Entity, text: string) -> (),
}

type DialogResource = revy.Resource<DialogResourceData>

local RESOURCE = revy.resource("game.dialog_resource") :: DialogResource

return {
	plugin = revy.plugin("game.dialog_resource", function(plugin: revy.Plugin)
		local app = plugin.app	
		local data = {} :: DialogResourceData

		function data.say(entity, text)
			local dialog_emitter_rbx = app.world:get(entity, game_components.DialogEmitterRbx)

			if not dialog_emitter_rbx then
				return
			end

			if dialog_emitter_rbx.sound then
				dialog_emitter_rbx.sound:Play()
			end

			TextChatService:DisplayBubble(dialog_emitter_rbx.source, text)
		end

		app:insert_resource(RESOURCE, data)

		return nil
	end),

	RESOURCE = RESOURCE,
}
```
]=]
function revy.resource<T>(id: string)
	return id :: any
end

function revy.app()
	--- keeps track of what systems are loaded, as well as the plugin that they belong to, based on hot-reload friendly ids.
	local loaded_systems: { [string]: { owner: string, system_table: types.SystemTable } } = {}

	--- keeps track of plugins the user wants loaded.
	local plugin_defs: { PluginDef } = {}

	--- keeps track of all currently loaded plugins by id.
	local loaded_plugins: { [string]: types.Plugin<RevyApp> } = {}

	--- all currently loaded resources
	local resources: { [any]: Resource } = {}

	local hot_reloader = rewire.HotReloader.new()

	local app = {} :: RevyAppCommands
	app.network = replecs.create()
	app.world = jecs.world()

	local event_context = event_util.context(app.world)

	app.event_context = event_context

	local parser_context = text_entity_util.new_parser_context(app.world, {
		reliable = revy.reliable,
		unreliable = revy.unreliable,
		networked = revy.networked,
	})

	local scheduler =
		planck.Scheduler.new(app.world):addPlugin(planck_run_service.Plugin.new()):addPlugin(planck_jabby.new())

	function app:insert_resource<T>(resource: Resource<T>, data: T)
		resources[resource] = data :: any
		return self
	end

	function app:event(entity, component, data)
		return event_util.eventity(event_context, entity, component, data)
	end

	function app:event_consumer()
		return event_util.consumer(event_context)
	end

	function app:get_resource<T>(resource: Resource<T>)
		return resources[resource :: any] :: any
	end

	function app:load_text_entity(entity, text_entity: types.TextEntityContext, context: any)
		text_entity_util.parse(
			parser_context,
			entity,
			text_entity.data,
			context,
			{ [text_entity_util.LOG_TEXT_ENTITY_NAME] = text_entity.name or nil }
		)
		return entity
	end

	function app:add_plugins(...: PluginDef)
		for _, plugin_def in { ... } do
			table.insert(plugin_defs, plugin_def)
		end

		return self
	end

	function app:open_debugger()
		return self
	end

	local function phase_from_schedule(schedule: Schedule): types.Phase
		local phase = schedule_phase_map[schedule]
		assert(phase, `phase for {schedule} could not be found!`)
		return phase
	end

	local function new_system_table(schedule: Schedule, system: System)
		return {
			phase = phase_from_schedule(schedule),
			system = system.system,
			name = system.id,
		} :: types.SystemTable
	end

	local function destroy_system(id: string)
		local system_data = loaded_systems[id]
		assert(system_data, `system {id} doesn't exist`)
		scheduler:removeSystem(system_data.system_table)
		loaded_systems[id] = nil
	end

	local function load_plugin(plugin_def: PluginDef, is_hot_reload: true?)
		local log = if is_hot_reload then print else DO_NOTHING
		local successful_loads = {}
		local plugin = new_plugin.build(plugin_def, app)

		if loaded_plugins[plugin.id] then
			loaded_plugins[plugin.id].cleanup()
		end

		for schedule, systems in plugin.schedule do
			if is_hot_reload and schedule == "start" then
				-- startup systems seem to not play well with `planck:replaceSystems`.
				-- we also need them to run again on hot reload, so that'll be handled here
				for system_uid, system in systems do
					local existing = loaded_systems[system_uid]

					if existing then
						loaded_systems[system_uid] = nil
					end

					log(`running start system {system_uid}`)

					xpcall(function()
						(system.system :: any)(app.world)
					end, function(...)
						warn(`error after running system {system_uid}: `, ...)
					end)

					successful_loads[system_uid] = true
				end

				continue
			end

			for system_uid, system in systems do
				local existing = loaded_systems[system_uid]
				local system_table = new_system_table(schedule, system)
				system_table.name = system_uid

				if existing then
					log(`replacing existing system {system_uid}`)
					scheduler:replaceSystem(existing.system_table, system_table)
				else
					log(`adding new system {system_uid}`)
					scheduler:addSystem(system_table)
				end

				successful_loads[system_uid] = true

				loaded_systems[system_uid] = {
					owner = plugin_def.id,
					system_table = system_table,
				}
			end
		end

		loaded_plugins[plugin.id] = plugin

		return {
			successful_loads = successful_loads,
		}
	end

	local function load_user_plugins()
		for _, plugin_def in plugin_defs do
			load_plugin(plugin_def)
		end
	end

	function app:run()
		if RunService:IsClient() then
			app.network.client:init(app.world)
		else
			app.network.server:init(app.world)
		end

		local entity_instance_map: { [Instance]: types.Renderer } = {}

		app.world:added(revy.renderer, function(entity, _id, model)
			entity_instance_map[model] = entity
		end)

		app.world:removed(revy.renderer, function(entity)
			for model_key, entity_value in entity_instance_map do
				if entity_value == entity then
					entity_instance_map[model_key] = nil
					break
				end
			end
		end)

		jabby.register({
			applet = jabby.applets.world,
			name = "Revy World",
			configuration = {
				world = app.world,
				get_entity_from_part = function(part)
					while part.Parent do
						if entity_instance_map[part] then
							return entity_instance_map[part], part
						end

						part = part.Parent
					end
				end,
			},
		})

		if RunService:IsClient() then
			local client = jabby.obtain_client()

			local function create_widget()
				client.spawn_app(client.apps.home :: any, nil)
			end

			app.open_debugger = function(_self)
				create_widget()
				return _self
			end
		end

		load_plugin(revy.plugins.network_plugin)
		load_plugin(revy.plugins.events_plugin)
		load_user_plugins()

		return self
	end

	function app:bind_debugger(key_code: Enum.KeyCode)
		ContextActionService:BindAction("Open Debugger (Jabby)", function(_, state, _)
			if state == Enum.UserInputState.Begin then
				app:open_debugger()
				return Enum.ContextActionResult.Sink
			end

			return Enum.ContextActionResult.Pass
		end, false, key_code)

		return self
	end

	--- Enables hot reloading for all descendants of the provided instances.
	function app:enable_hot_reloading(...: Instance)
		for _, container in { ... } do
			hot_reloader:scan(container, function(module, context)
				local ok, system_or_plugin = pcall(require :: any, module)

				if not ok then
					logger.lib_warn(`hot reload failed - require({module:GetFullName()}) -> {system_or_plugin}`)
					return
				end

				if typeof(system_or_plugin) ~= "table" then
					logger.lib_warn(`hot reload failed - typeof(require({module:GetFullName()})) ~= table`)
					return
				end

				if system_or_plugin.plugin then
					system_or_plugin = system_or_plugin.plugin
				end

				local id = system_or_plugin.id

				if typeof(id) ~= "string" then
					logger.lib_warn(
						`hot reload failed - require({module:GetFullName()}).id == {id} --- expected string`
					)
					return
				end

				if not context.isReloading then
					return
				end

				if system_or_plugin.type == "revy_plugin_def" then
					print(`| + loading plugin {id}...`)
					print("|----------------------")
					print(`|*log for {id} here`)

					local old = loaded_plugins[system_or_plugin.id]
					local result = load_plugin(system_or_plugin, true)

					if old then
						-- unload any systems from the old plugin that aren't being replaced
						for loaded_id, loaded_data in loaded_systems do
							if loaded_data.owner == system_or_plugin.id and not result.successful_loads[loaded_id] then
								print(`destroying dead system {loaded_id}`)
								destroy_system(loaded_id)
							end
						end
					end

					print("|----------------------")
					print("|✅ Done!")
				elseif system_or_plugin.type == "revy_system" then
					logger.lib_warn(
						`systems cannot be hot reloaded currently - use revy.plugin instead of revy.system.\n(source: {id} @ {module:GetFullName()})`
					)
				else
					logger.lib_warn(
						`require({module:GetFullName()}).type hasn't been identified as a revy plugin or system. No loading will occur.`
					)
				end
			end, function(module, context)
				if context.isReloading then
					return
				end

				local ok, system_or_plugin = pcall(require :: any, module)

				if not ok then
					logger.lib_warn(
						`require({module:GetFullName()}) failed - cannot unload system. error: {system_or_plugin}`
					)
					return
				end

				local to_cleanup = loaded_plugins[system_or_plugin.id]

				if to_cleanup then
					to_cleanup.cleanup()
				end
			end)
		end

		return self
	end

	function app:network_components(components: { [string]: jecs.Entity })
		for name, component in components do
			if not app.world:get(component, jecs.Name) then
				logger.lib_warn(
					`Component '{name}' is missing jecs.Name metadata - it won't be networked correctly.`
						.. `\n{logger.TINY_TAB}{_G.PACKAGE_NAME}.ecs.meta(component, {_G.PACKAGE_NAME}.ecs.Name, "Rotator")`
				)
			end

			app.world:add(component, replecs.shared)
		end

		return self
	end

	function app:net_add<T, a>(entity: jecs.Entity, component: jecs.Id<T>, first_pair: jecs.Id<a>?)
		app.world:add(entity, component)

		if jecs_internal.ECS_IS_PAIR(component) then
			first_pair = first_pair or revy.net_pair
			app.world:add(entity, jecs.pair(first_pair, jecs.pair_first(app.world, component)))
		else
			first_pair = first_pair or revy.reliable
			app.world:add(entity, jecs.pair(first_pair, component))
		end

		return entity
	end

	function app:net_set<T, a>(entity: jecs.Entity, component: jecs.Id<T>, value: T, first_pair: jecs.Id<a>?)
		app.world:set(entity, component, value)

		if jecs_internal.ECS_IS_PAIR(component) then
			first_pair = first_pair or revy.net_pair
			local relation = jecs_internal.entity_index_get_alive(jecs_internal.ecs_pair_first(app.world, component))
			app.world:add(entity, jecs.pair(first_pair, relation))
		else
			first_pair = first_pair or revy.reliable
			app.world:add(entity, jecs.pair(first_pair, component))
		end

		return entity
	end

	app:add_plugins(revy.plugins.time_plugin)
	return app
end

revy.Export = Export

local Renderer = jecs.component() :: types.Renderer
jecs.meta(Renderer, jecs.Name, "Renderer")
jecs.meta(Renderer, revy.Export, text_entity_default_parsers.path)

local Transform = jecs.component() :: types.Transform
jecs.meta(Transform, jecs.Name, "Transform")
jecs.meta(Transform, revy.Export, text_entity_default_parsers.CFrame)

local FrameEvent = jecs.component()
jecs.meta(FrameEvent, jecs.Name, "revy.FrameEvent")

--- A built-in component used for displaying models in the datamodel.
revy.renderer = Renderer

--- A built-in component that represents object transforms.
revy.transform = Transform

--- Alias for `revy.network.networked` / `replecs.networked`
revy.networked = replecs.networked
--- Alias for `revy.network.reliable` / `replecs.reliable`
revy.reliable = replecs.reliable
--- Alias for `revy.network.unreliable` / `replecs.unreliable`
revy.unreliable = replecs.unreliable
--- Alias for `revy.network.pair` / `replecs.pair`
revy.net_pair = replecs.pair
--- Alias for `revy.network.custom` / `replecs.custom`
revy.net_custom = replecs.custom
--- Alias for `revy.network.custom_handler` / `replecs.custom_handler`
revy.net_custom_handler = replecs.custom_handler :: Id -- this doesn't type well in the new solver currently.
--- Alias for `revy.network.global` / `replecs.global`
revy.net_global = replecs.global

--- This is Replecs. Docs: https://pepeeltoro41.github.io/replecs/
revy.network = replecs

--- Built-in plugins that are enabled by default.
revy.plugins = {}

revy.resources = {}

revy.plugins.events_plugin = revy.plugin("revy.events", function(plugin)
	local app = plugin.app
	local flush = event_util.system.flush

	plugin:add_system(
		"last",
		revy.system(function()
			flush(app.event_context)
		end)
	)

	return nil
end)

revy.plugins.network_plugin = revy.plugin("revy.network", function(plugin)
	local app = plugin.app

	if RunService:IsServer() then
		remotes.receive_full.OnServerInvoke = function(player): ...any
			if app.network.server:is_player_ready(player) then
				return nil
			end

			app.network.server:mark_player_ready(player)
			return app.network.server:get_full(player)
		end

		plugin:add_system(
			"update",
			revy.system(function()
				if updates_interval() then
					for player, buf, variants in app.network.server:collect_updates() do
						remotes.collect_updates:FireClient(player, buf, variants)
					end
				end

				if unreliables_interval() then
					for player, buf, variants in app.network.server:collect_unreliable() do
						remotes.collect_unreliable:FireClient(player, buf, variants)
					end
				end
			end)
		)
	else
		local updates = revy.collect(remotes.collect_updates.OnClientEvent)
		local unreliables = revy.collect(remotes.collect_unreliable.OnClientEvent)

		task.spawn(function()
			local buf, variants = remotes.receive_full:InvokeServer()
			app.network.client:apply_full(buf, variants)
		end)

		plugin:add_system(
			"update",
			revy.system(function()
				for buf, variants in updates do
					app.network.client:apply_updates(buf, variants)
				end

				for buf, variants in unreliables do
					app.network.client:apply_unreliable(buf, variants)
				end
			end)
		)
	end

	return nil
end)

revy.resources.time = revy.resource("revy.time") :: Resource<{ delta: number }>

revy.plugins.time_plugin = revy.plugin("revy.time", function(plugin)
	local app = plugin.app
	local time = { delta = 0 }

	app:insert_resource(revy.resources.time, time)
	local last_tick = os.clock()

	plugin:add_system(
		"update",
		revy.system(function(_)
			local now = os.clock()
			time.delta = now - last_tick
			last_tick = now
		end)
	)

	return nil
end)

return table.freeze(revy)
