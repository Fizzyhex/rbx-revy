local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

do
	if RunService:IsServer() and not ReplicatedStorage:FindFirstChild("JABBY_REMOTES") then
		script.JABBY_REMOTES.Parent = ReplicatedStorage
	end
end

local replecs = require("@packages/replecs")
local jabby = require("@packages/jabby")
local jecs = require("@packages/jecs")
local planck = require("@packages/planck")
local planck_jabby = require("@packages/planck_jabby")
local planck_run_service = require("@packages/planck_runservice")
local rewire = require("@packages/rewire")
local collect = require("@self/collect")
local interval = require("@self/interval")
local new_plugin = require("@self/new_plugin")
local remotes = require("@self/remotes")
local system_utils = require("@self/system_utils")
local types = require("@self/types")

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
export type Plugin = types.Plugin
export type Resource<T = any> = types.Resource<T>

local schedule_phase_map = {
	update = planck_run_service.Phases.PostSimulation,
	pre_render = planck_run_service.Phases.PreRender,
	start = planck.Phase.Startup,
}

local FRESH_TAG = "___revy_fresh"

local updates_interval = interval(1 / 20)
local unreliables_interval = interval(1 / 30)

local revy = { ecs = jecs }

revy.plugin = new_plugin
revy.collect = collect
revy.interval = interval

function revy.system(id: string, func: (world: jecs.World) -> ())
	local system: types.System = { type = "revy_system", id = id, system = func :: SystemFn }
	return system
end

function revy.resource<T>(id: string)
	return (id :: any) :: T
end

function revy.app()
	local plugins = {}
	local resources: { [any]: Resource } = {}

	local system_map: { [string]: SystemFn } = {}
	local had_first_load: { [string]: true } = {}

	local hot_reloader = rewire.HotReloader.new()

	local app = {} :: RevyAppCommands
	app.network = replecs.create()
	app.world = jecs.world()

	local scheduler =
		planck.Scheduler.new(app.world):addPlugin(planck_jabby.new()):addPlugin(planck_run_service.Plugin.new())

	local function unload_associated_systems(plugin_id: string)
		for map_id, map_system in system_map do
			if map_id == plugin_id or map_id:match(`^{plugin_id}.`) then
				print("| - Unloading system", map_id)
				scheduler:removeSystem(map_system)
				system_map[map_id] = nil
			end
		end
	end

	function app:insert_resource<T>(resource: Resource<T>, data: T)
		resources[resource] = data :: any
		return self
	end

	function app:get_resource<T>(resource: Resource<T>)
		return resources[resource :: any] :: any
	end

	function app:add_plugin(plugin: Plugin)
		table.insert(plugins, plugin)
		return self
	end

	function app:add_systems(schedule: Schedule, ...)
		local phase = schedule_phase_map[schedule]
		assert(phase, `Invalid schedule '{schedule}'`)
		local systems = {}

		for _, module in { ... } do
			if module.type ~= "revy_system" then
				warn(
					`module.type == {module.type} when it should == 'revy_system' - it's invalid and will not be loaded. Create systems with revy.system().`
				)
				continue
			end

			local system = system_utils.to_planck(module)
			system_map[module.id] = system
			table.insert(systems, system)
		end

		scheduler:addSystems(systems, phase)

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

		revy.network_plugin.build(app)

		for _, plugin in plugins do
			plugin.build(app)
		end

		return self
	end

	function app:bind_debugger(key_code: Enum.KeyCode)
		ContextActionService:BindAction("Open Debugger (Jabby)", function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				app:open_debugger()
			end
		end, false, key_code)

		return self
	end

	--- Enables hot reloading for all descendants of the provided instances.
	function app:enable_hot_reloading(...: Instance)
		for _, container in { ... } do
			hot_reloader:scan(container, function(module)
				local ok, system_or_plugin = pcall(require, module)

				if not ok then
					warn(`Hot reload failed - require({module:GetFullName()}) -> {system_or_plugin}`)
					return
				end

				if typeof(system_or_plugin) ~= "table" then
					warn(`Hot reload failed - typeof(require({module:GetFullName()})) ~= table`)
					return
				end

				local id = system_or_plugin.id

				if typeof(id) ~= "string" then
					warn(`Hot reload failed - require({module:GetFullName()}).id == {id} - expected string`)
					return
				end

				-- Only hot reload on the second detection
				if not had_first_load[id] then
					had_first_load[id] = true
					return
				end

				print(`Unloading plugin {id}...`)
				print("|----------------------")
				unload_associated_systems(id)

				if system_or_plugin.type == "revy_plugin" then
					print(`| + Loading plugin {id}...`)
					print("|----------------------")
					print(`|*log for {id} here`)
					system_or_plugin.build(app)
					print("|----------------------")
					print("|✅ Done!")
				elseif system_or_plugin.type == "revy_system" then
					warn(
						`Systems cannot be hot reloaded currently - use revy.plugin instead of revy.system.\n(Source: {id} @ {module:GetFullName()})`
					)
				else
					warn(
						`require({module:GetFullName()}).type hasn't been identified as a revy plugin or system. No loading will occur.`
					)
				end
			end, function(module, context)
				if context.isReloading then
					return
				end

				local ok, system_or_plugin = pcall(require, module)

				if not ok then
					warn(`require({module:GetFullName()}) failed - cannot unload system. Error: {system_or_plugin}`)
					return
				end

				unload_associated_systems(system_or_plugin.id)
			end)
		end

		return self
	end

	function app:network_components(components)
		for name, component in components do
			if not app.world:get(component, jecs.Name) then
				warn(`Component '{name}' is missing jecs.Name metadata - it won't be networked correctly.`)
				warn(`{_G.PACKAGE_NAME}.ecs.meta(component, {_G.PACKAGE_NAME}.ecs.Name, "Rotator")`)
			end

			app.world:add(component, replecs.shared)
		end

		return self
	end

	app:add_plugin(revy.time_plugin)

	return app
end

local Renderer = jecs.component() :: types.Renderer
jecs.meta(Renderer, jecs.Name, "Renderer")

local Transform = jecs.component() :: types.Transform
jecs.meta(Transform, jecs.Name, "Transform")

revy.renderer = Renderer
revy.transform = Transform
revy.networked = replecs.networked :: typeof(jecs.tag())
revy.reliable = replecs.reliable :: typeof(jecs.tag())
revy.unreliable = replecs.unreliable :: typeof(jecs.tag())

revy.network_plugin = revy.plugin("revy.network", function(app)
	if RunService:IsServer() then
		remotes.receive_full.OnServerInvoke = function(player)
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
end)

revy.time = revy.resource("revy.time") :: Resource<{ delta: number }>
revy.time_plugin = revy.plugin("revy.time", function(app)
	local time = { delta = 0 }

	app:insert_resource(revy.time, time)
	local last_tick = os.clock()

	app:add_systems(
		"update",
		revy.system("revy.time.update", function(_)
			local now = os.clock()
			time.delta = now - last_tick
			last_tick = now
		end)
	)
end)

return revy
