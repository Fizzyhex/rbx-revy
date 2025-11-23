local jecs = require("@packages/jecs")

type EventityCyclesData = number
type EventityCycles = jecs.Entity<EventityCyclesData>

local eventity_cycles = jecs.component() :: EventityCycles
jecs.meta(eventity_cycles, jecs.Name, "revy.event.is_eventity")

-- amount of cycles that events stay in the world for
local MAX_CYCLES = 2
-- how many cycles between consumer garbage collection
local CLEAN_RATE = 50

export type EventContext = {
	world: jecs.World,
	reserved_entity: jecs.Entity,
	event_ids: { jecs.Id },
	pending_assertions: { any },
	flush_query: jecs.Query<EventityCyclesData>,
	last_clean: number,
}

type EventConsumerCachedQuery<T> = jecs.Query<T> & { __cached_event_query: true }

--- an event consumer is an interface for querying events in the world.
export type EventConsumer = {
	--- collects all of an event. use `collect_cached` if applicable for better performance.
	collect: <T>(self: EventConsumer, event_id: jecs.Id<T>) -> () -> (jecs.Id?, T?),
	--- collects all of an event - caching queries internally for performance.
	collect_cached: <T>(self: EventConsumer, cached_event: EventConsumerCachedQuery<T>?) -> () -> (jecs.Id?, T),
	--- caches an event for use with `collect_cached`.
	cache_event: <T>(self: EventConsumer, event_id: jecs.Id<T>) -> EventConsumerCachedQuery<T>,
}

local event_util = { system = {} }

--- creates a new event consumer, which is an interface for querying events in the world.
function event_util.consumer(context: EventContext)
	local last_clean = 0
	local already_collected: { [jecs.Id]: true } = {}
	local event_consumer = {} :: EventConsumer

	local function clean()
		last_clean = context.last_clean
		local to_remove = {}

		for id in already_collected do
			if not context.world:contains(id) then
				table.insert(to_remove, id)
			end
		end

		for _, key in to_remove do
			already_collected[key] = nil
		end
	end

	function event_consumer:cache_event<T>(event_id: jecs.Id<T>)
		return context.world:query(event_id):cached() :: EventConsumerCachedQuery<T>
	end

	function event_consumer:collect<T>(event_id: jecs.Id<T>)
		if context.last_clean - last_clean > CLEAN_RATE then
			clean()
		end

		local iterator = context.world:query(event_id):iter()

		local function custom_iterator(): (jecs.Id?, T?)
			local id, component_to_add = iterator()

			if id == nil then
				return nil, nil
			end

			if already_collected[id] then
				return custom_iterator()
			end

			already_collected[id] = true
			local parent = context.world:parent(id)
			local data = context.world:get(id, component_to_add)

			return parent, data
		end

		return custom_iterator
	end

	function event_consumer:collect_cached<T>(cached_query: EventConsumerCachedQuery<T>)
		if context.last_clean - last_clean > CLEAN_RATE then
			clean()
		end

		local iterator = cached_query:iter()

		local function custom_iterator(): (jecs.Id?, T?)
			local id, component_to_add = iterator()

			if id == nil then
				return nil, nil
			end

			if already_collected[id] then
				return custom_iterator()
			end

			already_collected[id] = true
			local parent = context.world:parent(id)
			local data = context.world:get(id, component_to_add)

			return parent, data
		end

		return custom_iterator
	end

	return event_consumer
end

function event_util.eventity<T, a>(context: EventContext, id: jecs.Id<T>, component: jecs.Entity<a>, data: a)
	local eventity = context.world:entity()
	context.world:set(eventity, component, data)
	context.world:set(eventity, eventity_cycles, 0)
	context.world:add(eventity, jecs.pair(jecs.ChildOf, id))
	return eventity
end

function event_util.context(world: jecs.World)
	return {
		world = world,
		reserved_entity = world:entity(),
		event_ids = {},
		pending_assertions = {},
		flush_query = world:query(eventity_cycles):cached(),
		last_clean = 0,
	} :: EventContext
end

function event_util.query_event<T>(context: EventContext, event_id: jecs.Id<T>)
	local query = context.world:query(event_id):iter()

	return function(): (jecs.Id?, T?)
		local id, component_to_add = query()

		if id == nil then
			return nil, nil
		end

		local parent = context.world:parent(id)
		local data = context.world:get(id, component_to_add)
		return parent, data
	end
end

function event_util.system.flush<T, a>(context: EventContext)
	context.last_clean += 1

	for id, cycles in context.flush_query do
		local new = cycles + 1

		if new > MAX_CYCLES then
			context.world:delete(id)
		else
			context.world:set(id, eventity_cycles, new)
		end
	end
end

return event_util
