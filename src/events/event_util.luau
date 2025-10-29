local jecs = require("@packages/jecs")

type Queued = jecs.Entity<jecs.Id>

local is_eventity = jecs.tag()
jecs.meta(is_eventity, jecs.Name, "revy.entity.is_eventity")

local queued = jecs.component() :: Queued
jecs.meta(queued, jecs.Name, "revy.entity.queued")

export type EventContext = {
	world: jecs.World,
	event_ids: { jecs.Id },
	pending_assertions: { any },
	flush_query: jecs.Query,
}

local function add_assertion<T, a>(context: EventContext, id: jecs.Id<T>, component: jecs.Entity<a>, data: a)
	table.insert(context.pending_assertions, { id, component, data })
end

local event_util = { internal = {} }

function event_util.internal.queue_event<T, a>(context: EventContext, id: jecs.Id<T>, component: jecs.Entity<a>, data: a)
	add_assertion(context, id, component, data)
end

function event_util.internal.release<T, a>(context: EventContext)
	for id in context.release_query do
		print("allowing", id)
		context.world:remove(id, queued)
	end
end

function event_util.eventity<T, a>(context: EventContext, id: jecs.Id<T>, component: jecs.Entity<a>, data: a)
	local eventity = context.world:entity()
	context.world:set(eventity, component, data)
	context.world:set(eventity, queued, component)
	context.world:add(eventity, is_eventity)
	context.world:add(eventity, jecs.pair(jecs.ChildOf, id))
	print("event live at", eventity)
	return eventity
end

function event_util.context(world: jecs.World)
	return {
		world = world,
		event_ids = {},
		pending_assertions = {},
		release_query = world:query(queued):cached(),
		flush_query = world:query(is_eventity):without(queued):cached(),
	} :: EventContext
end

function event_util.query_event<T>(context: EventContext, event_id: jecs.Id<T>)
	local query = context.world:query(event_id):without(queued):iter()

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

function event_util.internal.flush<T, a>(context: EventContext)
	for id in context.flush_query do
		print("flushed", id)
		context.world:delete(id)
	end
end

return event_util
