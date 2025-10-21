local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local jabby = require("@packages/jabby")
local jecs = require("@packages/jecs")
local planck = require("@packages/planck")
local planck_jabby = require("@packages/planck_jabby")
local planck_run_service = require("@packages/planck_run_service")
local rewire = require("@packages/rewire")
local new_plugin = require("@self/new_plugin")
local system_utils = require("@self/system_utils")
local types = require("@self/types")

export type Archetype = jecs.Archetype
export type QueryInner = jecs.QueryInner
export type Record = jecs.Record
export type ComponentRecord = jecs.ComponentRecord
export type ComponentIndex = jecs.ComponentIndex
export type Archetypes = jecs.Archetypes
export type EntityIndex = jecs.EntityIndex
export type Entity<T = any> = jecs.Entity<T>
export type Id<T = any> = jecs.Id<T>
export type Pair<P, O> = jecs.Pair<P, O>
export type Item<T...> = jecs.Item<T...>
export type Iter<T...> = jecs.Iter<T...>
export type Query<T...> = jecs.Query<T...>
export type Observer = jecs.Observer
export type Observable = jecs.Observable
export type World = jecs.World

type SystemFn = types.SystemFn
export type RevyApp = types.RevyApp
export type System = types.System
export type Schedule = types.Schedule
export type Plugin = types.Plugin
export type Resource<T = any> = types.Resource<T>

local schedule_phase_map = {
	update = planck_run_service.Phases.PostSimulation,
	pre_render = planck_run_service.Phases.PreRender,
}

local revy = { ecs = jecs }

revy.plugin = new_plugin

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

	local system_map = {}
	local system_update_cache = {}

	local hot_reloader = rewire.HotReloader.new()

	local app = {} :: RevyApp
	app.world = jecs.world()

	local scheduler =
		planck.Scheduler.new(app.world):addPlugin(planck_jabby.new()):addPlugin(planck_run_service.Plugin.new())

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
		jabby.register({
			applet = jabby.applets.world,
			name = "Revy World",
			configuration = {
				world = app.world,
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

	function app:enable_hot_reloading(container: Instance)
		hot_reloader:scan(container, function(module)
			local ok, system = pcall(require, module)

			if not ok then
				warn(`Error while hot reloading {module.Name}: {system}`)
				return
			end

			if system_map[system.id] then
				scheduler:replaceSystem(system_map[system.id], system)
				print(`Hot reloading {system.id}`)
			else
				local schedule = system_update_cache[system.id] or "update"
				app:add_systems(schedule, system)
				print(`Added new system {system.id} on schedule '{schedule}'`)
			end
		end, function(module, context)
			if context.isReloading then
				return
			end

			local ok, system = pcall(require, module)

			if not ok then
				warn(`Error while unreloading {module.Name}: {system}`)
				return
			end

			if system_map[system.id] then
				scheduler:removeSystem(system_map[system.id])
				print(`Removed system '{system.id}'`)
			end
		end)

		return self
	end

	app:add_plugin(revy.time_plugin)

	return app
end

revy.time = revy.resource("Time") :: Resource<{ delta: number }>
revy.time_plugin = revy.plugin("Time", function(app)
	local resource = revy.resource("Time") :: Resource<{ delta: number }>
	local time = { delta = 0 }

	app:insert_resource(resource, time)
	local last_tick = os.clock()

	app:add_systems(
		"update",
		revy.system("revy.time", function(_)
			local now = os.clock()
			time.delta = now - last_tick
			last_tick = now
		end)
	)
end)

return revy
