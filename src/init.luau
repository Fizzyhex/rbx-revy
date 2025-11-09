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
local system_utils = require("@self/system_utils")
local types = require("@self/types")
local bundles = require("@self/bundles/bundles")

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

local updates_interval = interval(1 / 20)
local unreliables_interval = interval(1 / 30)

local PLANCK_INJECTION_KEY = "revy_id"

local revy = {
	--- This is Jecs. Docs: https://ukendio.github.io/jecs/
	ecs = jecs,
}

revy.bundles = bundles
revy.plugin = new_plugin
revy.collect = collect
revy.interval = interval
revy.exporters = text_entity_default_parsers

local Export = jecs.component()
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

function revy.system(id: string, func: (world: jecs.World) -> ())
	local system: types.System = { type = "revy_system", id = id, system = func :: SystemFn }
	return system
end

function revy.resource<T>(id: string)
	return id :: any
end

function revy.app()
	local plugins = {}
	local resources: { [any]: Resource } = {}

	local system_map: { [string]: SystemFn } = {}
	local plugin_cleanup_map: { [string]: () -> () } = {}

	local system_loading_behaviour = "instant" :: "instant" | "queue"
	local system_loading_queue: { [string]: { system: any, phase: Schedule } } = {}

	local hot_reloader = rewire.HotReloader.new()

	local app = {} :: RevyAppCommands
	app.network = replecs.create()
	app.world = jecs.world()

	local event_context = event_util.context(app.world)

	app.event_context = event_context

	local parser_context = text_entity_util.new_parser_context(app.world, {
		reliable = revy.reliable,
		unreliable = revy.unreliable,
	})

	local function load_plugin(plugin: Plugin)
		plugin_cleanup_map[plugin.id] = plugin.build(app)
	end

	local scheduler =
		planck.Scheduler.new(app.world):addPlugin(planck_run_service.Plugin.new()):addPlugin(planck_jabby.new())

	local function collect_systems(plugin_id: string)
		local systems = {}

		for map_id, map_system in system_map do
			if map_id == plugin_id or map_id:match(`^{plugin_id}.`) then
				systems[map_id] = map_system
			end
		end

		return systems
	end

	local function add_system(id: string, system)
		scheduler:addSystems(system)
		scheduler._systemInfo[system.system][PLANCK_INJECTION_KEY] = id
		system_map[id] = system
	end

	local function remove_system(id: string)
		if system_map[id] then
			scheduler:removeSystem(system_map[id])
			system_map[id] = nil
		else
			warn(`System {id} not found - nothing will be unloaded`, debug.traceback())
		end
	end

	local function replace_or_add_system(id: string, new)
		if system_map[id] then
			for key, value in scheduler._systemInfo do
				if value[PLANCK_INJECTION_KEY] == id then
					scheduler:replaceSystem(key, new)
					return
				end
			end

			print(scheduler._systemInfo)
			error("system replace found no matches")
		else
			add_system(id, new)
		end

		system_map[id] = new
	end

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

	function app:load_text_entity(entity, text_entity: types.TextEntityContext, context)
		text_entity_util.parse(
			parser_context,
			entity,
			text_entity.data,
			context,
			{ [text_entity_util.LOG_TEXT_ENTITY_NAME] = text_entity.name }
		)
		return entity
	end

	function app:add_plugins(...)
		for _, plugin in { ... } do
			table.insert(plugins, plugin)
		end

		return self
	end

	function app:add_systems(schedule: Schedule, ...)
		local phase = schedule_phase_map[schedule]
		assert(phase, `Invalid schedule '{schedule}'`)

		for _, module in { ... } do
			if module.type ~= "revy_system" then
				logger.lib_warn(
					`module.type == {module.type} --- it should == 'revy_system'.\n{logger.BULLET} it can't be loaded.\n{logger.BULLET} make sure you create systems with \`revy.system()\`.`
				)
				continue
			end

			local system_fn = system_utils.to_planck(module)
			local system_table = { system = system_fn, phase = schedule }

			system_map[module.id] = system_table

			if system_loading_behaviour == "queue" then
				system_loading_queue[module.id] = system_table
			else
				add_system(module.id, system_table)
			end
		end

		return self
	end

	function app:open_debugger()
		return self
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
				entities = entity_instance_map,
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

		for _, plugin in plugins do
			load_plugin(plugin)
		end

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

				logger.lib_print(`Unloading plugin {id}...`)
				print("|----------------------")

				if plugin_cleanup_map[id] then
					plugin_cleanup_map[id]()
				end

				local old_systems = collect_systems(id)

				if system_or_plugin.type == "revy_plugin" then
					print(`| + loading plugin {id}...`)
					print("|----------------------")
					print(`|*log for {id} here`)

					system_loading_behaviour = "queue"
					load_plugin(system_or_plugin)
					system_loading_behaviour = "instant"
					local new_systems = table.clone(system_loading_queue)
					table.clear(system_loading_queue)

					for key in old_systems do
						if new_systems[key] then
							-- replace
							print(`> {key}`)
							replace_or_add_system(key, new_systems[key])
						else
							-- remove
							print(`- {key}`)
							remove_system(key)
						end
					end

					for key, value in new_systems do
						if not old_systems[key] then
							-- add
							print(`+ {key}`)
							add_system(key, value)
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

				if plugin_cleanup_map[system_or_plugin.id] then
					plugin_cleanup_map[system_or_plugin.id]()
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

--- Alias for `revy.network.networked`
revy.networked = replecs.networked :: typeof(jecs.tag())
--- Alias for `revy.network.reliable`
revy.reliable = replecs.reliable :: typeof(jecs.tag())
--- Alias for `revy.network.unreliable`
revy.unreliable = replecs.unreliable :: typeof(jecs.tag())
--- Alias for `revy.network.pair`
revy.net_pair = replecs.pair :: typeof(jecs.tag())

--- This is Replecs. Docs: https://pepeeltoro41.github.io/replecs/
revy.network = replecs

--- Built-in plugins that are enabled by default.
revy.plugins = {}

revy.resources = {}

revy.plugins.events_plugin = revy.plugin("revy.events", function(app)
	local flush = event_util.system.flush

	app:add_systems(
		"last",
		revy.system("revy.frame_event.flush", function()
			flush(app.event_context)
		end)
	)

	return nil
end)

revy.plugins.network_plugin = revy.plugin("revy.network", function(app)
	if RunService:IsServer() then
		remotes.receive_full.OnServerInvoke = function(player): ...any
			if app.network.server:is_player_ready(player) then
				return nil
			end

			app.network.server:mark_player_ready(player)
			return app.network.server:get_full(player)
		end

		app:add_systems(
			"update",
			revy.system("revy.network.update", function()
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

		app:add_systems(
			"update",
			revy.system("revy.network.update", function()
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

revy.plugins.time_plugin = revy.plugin("revy.time", function(app)
	local time = { delta = 0 }

	app:insert_resource(revy.resources.time, time)
	local last_tick = os.clock()

	app:add_systems(
		"update",
		revy.system("revy.time.update", function(_)
			local now = os.clock()
			time.delta = now - last_tick
			last_tick = now
		end)
	)

	return nil
end)

return table.freeze(revy)
