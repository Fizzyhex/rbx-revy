local jecs = require("@packages/jecs")

type BundleTable = { __is_bundle_context: nil, [jecs.Id]: any }
type BundleSwitch = BundleContext | BundleTable

type NewComponentFn = <T>(ctx: BundleSwitch | { [jecs.Id]: any }, component: jecs.Id<T>, data: T) -> ()
type NewTagFn = <T>(ctx: BundleSwitch, component: jecs.Id<T>) -> ()

type BundleContext = {
	__is_bundle_context: true,
	components: { [jecs.Id]: any },
	tags: { [jecs.Id]: any },
	pairs: { { jecs.Entity } },
}

type NewBundleFn = <T...>(builder: BundleBuilderFn<T...>) -> Bundle<T...>
type BundleBuilderFn<T...> = (ctx: BundleContext, T...) -> ()
export type Bundle<T...> = (components: { [jecs.Id]: any }?, tags: { [jecs.Id]: any }?) -> (T...) -> BundleContext

type SpawnFn = <T...>(context: BundleContext | (T...) -> BundleContext, world: jecs.World, entity: jecs.Entity?) -> ()

local function new_component<T>(ctx: BundleSwitch, component: jecs.Id<T>, data: T)
	if ctx.__is_bundle_context then
		if ctx.components[component] == nil then
			ctx.components[component] = data
		end
	else
		ctx[component] = data
	end
end

local function new_tag<T>(ctx: BundleSwitch, tag: jecs.Id<T>)
	if ctx.__is_bundle_context then
		ctx.tags[tag] = true
	else
		ctx[tag] = true
	end
end

local function new_bundle<T...>(builder: BundleBuilderFn<T...>)
	return function(components: { [jecs.Id]: any }?, tags: { [jecs.Id]: any }?)
		local context =
			{ __is_bundle_context = true, components = components or {}, tags = tags or {} } :: BundleContext

		return function(...: T...)
			builder(context, ...)
			return context
		end
	end :: Bundle<T...>
end

local function spawn_from_context(context: BundleContext, world: jecs.World, entity: jecs.Entity?)
	entity = entity or world:entity()

	-- i dont think bulk_insert currently yields signficiant enough performance gain to implement it here.
	-- but we could in the future. - @Fizzyhex

	for key, value in context.components do
		world:set(entity, key, value)
	end

	for key in context.tags do
		world:add(entity, key)
	end
end

local function spawn(context, world, entity)
	if typeof(context) == "function" then
		return spawn_from_context(context(), world, entity)
	else
		return spawn(context, world, entity)
	end
end

--[[
```luau
local Name = jecs.component() :: jecs.Id<string>
local Player = jecs.tag() :: jecs.Id

local nb = new_bundle :: NewBundleFn
local spwn = spawn :: SpawnFn

local player_bundle = nb(function(ctx, name: string?)
	new_component(ctx, Name, name or "Unnamed Player")
	new_tag(ctx, Player)
end) :: Bundle<string?>

player_bundle({ [Name] = "Jenson" }, { [Player] = true })("")
spwn(player_bundle()("Jack"), jecs.world())
spwn(player_bundle(), jecs.world())
```
]]

return {
	bundle = new_bundle :: NewBundleFn,
	spawn = spawn :: SpawnFn,

	component = new_component :: NewComponentFn,
	tag = new_tag :: NewTagFn,
}
