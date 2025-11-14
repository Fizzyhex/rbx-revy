--!optimize 2
--!native
--!strict
--draft 4

type i53 = number
type i24 = number

type Ty = { Entity }
type ArchetypeId = number

type Column = { any }

type Map<K, V> = { [K]: V }

type Archetype = {
	id: number,
	types: Ty,
	type: string,
	entities: { Entity },
	columns: { Column },
	columns_map: { [Id]: Column }
}

type QueryInner = {
	compatible_archetypes: { Archetype },
	ids: { Id },
	filter_with: { Id },
	filter_without: { Id },
	next: () -> (Entity, ...any),
	world: World,
}

type Entity<T = any> ={ __T: T }
type Id<T = any> = { __T: T }
type Pair<P, O> = Id<P>
type ecs_id_t<T = unknown> = Id<T> | Pair<T, "Tag"> | Pair<"Tag", T>
type Item<T...> = (self: Query<T...>) -> (Entity, T...)
type Iter<T...> = (query: Query<T...>) -> () -> (Entity, T...)

type Query<T...> = typeof(setmetatable(
	{} :: {
		iter: Iter<T...>,
		with: ((Query<T...>, ...Id) -> Query<T...>),
		without: ((Query<T...>, ...Id) -> Query<T...>),
		archetypes: (self: Query<T...>) -> { Archetype },
		cached: (self: Query<T...>) -> Query<T...>,
		ids: { Id<any> },
		filter_with: { Id<any> }?,
		filter_without: { Id<any> }?
		-- world: World
	},
	{} :: {
		__iter: Iter<T...>,
	}
	))

type QueryArm<T...> = () -> ()

type Observer = {
	callback: (archetype: Archetype) -> (),
	query: QueryInner,
}

type query = {
	compatible_archetypes: { archetype },
	ids: { i53 },
	filter_with: { i53 },
	filter_without: { i53 },
	next: () -> (i53, ...any),
	world: world,
}

type observer = {
	callback: (archetype: archetype) -> (),
	query: query,
}

type archetype = {
	id: number,
	types: { i53 },
	type: string,
	entities: { i53 },
	columns: { Column },
	columns_map: { [i53]: Column }
}

type componentrecord = {
	component: i53,
	records: { [number]: number },
	counts: { [i53]: number },
	flags: number,
	size: number,

	on_add: ((entity: i53, id: i53, value: any, oldarchetype: archetype) -> ())?,
	on_change: ((entity: i53, id: i53, value: any, oldarchetype: archetype) -> ())?,
	on_remove: ((entity: i53, id: i53) -> ())?,

	wildcard_pairs: { [number]: componentrecord },
}
type record = {
	archetype: archetype,
	row: number,
	dense: i24,
}
type entityindex = {
	dense_array: Map<number, i53>,
	sparse_array: Map<i24, record>,
	alive_count: number,
	max_id: number,
	range_begin: number?,
	range_end: number?,
}
type world = {
	archetype_edges: Map<i53, Map<i53, archetype>>,
	archetype_index: { [string]: archetype },
	archetypes: { [i53]: archetype },
	component_index: Map<i53, componentrecord>,
	entity_index: entityindex,
	ROOT_ARCHETYPE: archetype,

	max_component_id: number,
	max_archetype_id: number,

	observable: Map<i53, Map<i53, { Observer }>>,

	range: (self: world, range_begin: number, range_end: number?) -> (),
	entity: (self: world, id: i53?) -> i53,
	component: (self: world) -> i53,
	target: (self: world, id: i53, relation: i53, index: number?) -> i53?,
	delete: (self: world, id: i53) -> (),
	add: (self: world, id: i53, component: i53) -> (),
	set: (self: world, id: i53, component: i53, data: any) -> (),
	cleanup: (self: world) -> (),
	clear: (self: world, entity: i53) -> (),
	remove: (self: world, id: i53, component: i53) -> (),
	get: (world, ...i53) -> (),
	has: (world, ...i53) -> boolean,
	parent: (self: world, entity: i53) -> i53?,
	contains: (self: world, entity: i53) -> boolean,
	exists: (self: world, entity: i53) -> boolean,
	each: (self: world, id: i53) -> () -> i53,
	children: (self: world, id: i53) -> () -> i53,
	query: (world, ...i53) -> Query<...any>,

	added: (world, i53, (e: i53, id: i53, value: any?) -> ()) -> () -> (),
	changed: (world, i53, (e: i53, id: i53, value: any?) -> ()) -> () -> (),
	removed: (world, i53, (e: i53, id: i53) -> ()) -> () -> (),
}

type World = {
	archetype_edges: Map<number, Map<Entity, Archetype>>,
	archetype_index: { [string]: Archetype },
	archetypes: Archetypes,
	component_index: ComponentIndex,
	entity_index: EntityIndex,
	ROOT_ARCHETYPE: Archetype,

	max_component_id: number,
	max_archetype_id: number,

	observable: Map<Id, Map<Id, { Observer }>>,

	added: <T>(World, Entity<T>, (e: Entity, id: Id<T>, value: T, oldarchetype: Archetype) -> ()) -> () -> (),
	removed: <T>(World, Entity<T>, (e: Entity, id: Id<T>) -> ()) -> () -> (),
	changed:  <T>(World, Entity<T>, (e: Entity, id: Id<T>, value: T, oldarchetype: Archetype) -> ()) -> () -> (),

	--- Enforce a check on entities to be created within desired range
	range: (self: World, range_begin: number, range_end: number?) -> (),

	--- Creates a new entity
	entity: <T>(self: World, id: (number | Entity<T>)?) -> Entity<T>,
	--- Creates a new entity located in the first 256 ids.
	--- These should be used for static components for fast access.
	component: <T>(self: World) -> Entity<T>,
	--- Gets the target of an relationship. For example, when a user calls
	--- `world:target(id, ChildOf(parent), 0)`, you will obtain the parent entity.
	target: <T, a>(self: World, id: Entity<T>, relation: Id<a>, index: number?) -> Entity?,
	--- Deletes an entity and all it's related components and relationships.
	delete: <T>(self: World, id: Entity<T>) -> (),

	--- Adds a component to the entity with no value
	add: <T, a>(self: World, id: Entity<T>, component: Id<a>) -> (),
	--- Assigns a value to a component on the given entity
	set: <T, a>(self: World, id: Entity<T>, component: Id<a>, data: a) -> (),

	cleanup: (self: World) -> (),

	-- Removes all components from the entity
	clear: (self: World, entity: Entity) -> (),
	--- Removes a component from the given entity
	remove: <T, a>(self: World, id: Entity<T>, component: Id<a>) -> (),
	--- Retrieves the value of up to 4 components. These values may be nil.
	get: & (<T, a>(World, Entity<T>, Id<a>) -> a?)
	& (<T, a, b>(World, Entity<T>, Id<a>, Id<b>) -> (a?, b?))
	& (<T, a, b, c>(World, Entity<T>, Id<a>, Id<b>, Id<c>) -> (a?, b?, c?))
	& (<T, a, b, c, d>(World, Entity<T>, Id<a>, Id<b>, Id<c>, Id<d>) -> (a?, b?, c?, d?)),

	--- Returns whether the entity has the ID.
	has: (<T, a>(World, Entity<T>, Id<a>) -> boolean)
	& (<T, a, b>(World, Entity<T>, Id<a>, Id<a>) -> boolean)
	& (<T, a, b, c>(World, Entity<T>, Id<a>, Id<b>, Id<c>) -> boolean)
	& <T, a, b, c, d>(World, Entity<T>, Id<a>, Id<b>, Id<c>, Id<d>) -> boolean,

	--- Get parent (target of ChildOf relationship) for entity. If there is no ChildOf relationship pair, it will return nil.
	parent: <T>(self: World, entity: Entity<T>) -> Entity?,

	--- Checks if the world contains the given entity
	contains: <T>(self: World, entity: Entity<T>) -> boolean,

	--- Checks if the entity exists
	exists: <T>(self: World, entity: Entity<T>) -> boolean,

	each: <T>(self: World, id: Id<T>) -> () -> Entity,

	children: <T>(self: World, id: Id<T>) -> () -> Entity,

	--- Searches the world for entities that match a given query
	query: ((World) -> Query<nil>)
	& (<A>(World, Id<A>) -> Query<A>)
	& (<A, B>(World, Id<A>, Id<B>) -> Query<A, B>)
	& (<A, B, C>(World, Id<A>, Id<B>, Id<C>) -> Query<A, B, C>)
	& (<A, B, C, D>(World, Id<A>, Id<B>, Id<C>, Id<D>) -> Query<A, B, C, D>)
	& (<A, B, C, D, E>(World, Id<A>, Id<B>, Id<C>, Id<D>, Id<E>) -> Query<A, B, C, D, E>)
	& (<A, B, C, D, E, F>(World, Id<A>, Id<B>, Id<C>, Id<D>, Id<E>, Id<F>) -> Query<A, B, C, D, E, F>)
	& (<A, B, C, D, E, F, G>(
		World,
		Id<A>,
		Id<B>,
		Id<C>,
		Id<D>,
		Id<E>,
		Id<F>,
		Id<G>
		) -> Query<A, B, C, D, E, F, G>)
	& (<A, B, C, D, E, F, G, H>(
		World,
		Id<A>,
		Id<B>,
		Id<C>,
		Id<D>,
		Id<E>,
		Id<F>,
		Id<G>,
		Id<H>,
		...Id<any>
		) -> Query<A, B, C, D, E, F, G, H>),
}

type Record = {
	archetype: Archetype,
	row: number,
	dense: i24,
}
type ComponentRecord = {
	records: { [i24]: number },
	counts: { [i24]: number },
	flags: number,
	size: number,

	on_add: (<T>(entity: Entity, id: Entity<T>, value: T, oldarchetype: Archetype) -> ())?,
	on_change: (<T>(entity: Entity, id: Entity<T>, value: T, oldArchetype: Archetype) -> ())?,
	on_remove: ((entity: Entity, id: Entity) -> ())?,
}
type ComponentIndex = Map<Id, ComponentRecord>
type Archetypes = { [i24]: Archetype }

type EntityIndex = {
	dense_array: Map<number, Entity>,
	sparse_array: Map<i24, Record>,
	alive_count: number,
	max_id: number,
	range_begin: number?,
	range_end: number?,
}

-- stylua: ignore start

local ECS_ENTITY_MASK =       bit32.lshift(1, 24)
local ECS_PAIR_OFFSET = 	                 2^48

local function ECS_ID(e: i53)
	return e % ECS_ENTITY_MASK
end

local function entity_index_try_get_any(
	entity_index: entityindex,
	entity: i53
): record?
	local r = entity_index.sparse_array[ECS_ID(entity)]

	if not r or r.dense == 0 then
		return nil
	end

	return r
end

local function entity_index_get_alive(entity_index: entityindex, entity: i53): i53?
	local r = entity_index_try_get_any(entity_index, entity :: number)
	if r then
		return entity_index.dense_array[r.dense]
	end
	return nil
end

local function entity_index_try_get(entity_index: entityindex, entity: i53): record?
	local r = entity_index_try_get_any(entity_index, entity)
	if r then
		local r_dense = r.dense
		if r_dense > entity_index.alive_count then
			return nil
		end
		if entity_index.dense_array[r_dense] ~= entity then
			return nil
		end
	end
	return r
end

local function entity_index_is_alive(entity_index: entityindex, entity: i53): boolean
	return entity_index_try_get(entity_index, entity) ~= nil
end

local function ecs_get_alive(world: World, entity: i53): i53
	if entity == 0 then
		return 0
	end

	local eindex = world.entity_index :: entityindex

	if entity_index_is_alive(eindex, entity) then
		return entity
	end

	if (entity :: number) > ECS_ENTITY_MASK then
		return 0
	end

	local current = entity_index_get_alive(eindex, entity)
	if not current or not entity_index_is_alive(eindex, current) then
		return 0
	end

	return current
end

local function ECS_PAIR_FIRST(e: i53): i24
	return (e - ECS_PAIR_OFFSET) // ECS_ENTITY_MASK
end

local function ECS_PAIR_SECOND(e: i53): i24
	return (e - ECS_PAIR_OFFSET) % ECS_ENTITY_MASK
end

local function ecs_pair_first(world: World, e: i53)
	local pred = ECS_PAIR_FIRST(e)
	return ecs_get_alive(world, pred)
end

local function ecs_pair_second(world: World, e: i53)
	local obj = ECS_PAIR_SECOND(e)
	return ecs_get_alive(world, obj)
end

local function ECS_IS_PAIR(e: number): boolean
	return e > ECS_PAIR_OFFSET
end

return {
	ECS_IS_PAIR = ECS_IS_PAIR :: any,
	ecs_pair_first = ecs_pair_first :: any,
	ecs_pair_second = ecs_pair_second :: any,
	entity_index_get_alive = entity_index_get_alive :: any
}