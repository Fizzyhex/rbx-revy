local jecs = require("@packages/jecs")

export type Bundler = {
	add: <Data>(component: jecs.Id<Data>, Data) -> (),
	set: <Data>(component: jecs.Id<Data>) -> (),
}

export type BundleFn = (Bundler) -> ()
export type Bundle =
	((world: jecs.World, compose_with: Bundle?) -> jecs.Id)
	& (world: jecs.World, compose_with: Bundle?, _internal_return_ids: true?) -> (jecs.Id, { jecs.Id })
export type BundleConstructor = (bundle_fn: BundleFn) -> Bundle

local function make_bundle(bundle_fn: BundleFn)
	local index = 0

	local components: { [number]: jecs.Id } = {}
	local datas: { [number]: jecs.Entity } = {}
	local ids: { jecs.Id } = {}

	local function add<T>(component: jecs.Id<T>, data: T)
		if ids[component :: T] then
			return
		end

		index += 1
		components[index] = component
		datas[index] = data
	end

	local function set<T>(component: jecs.Id<T>)
		if ids[component :: T] then
			return
		end

		index += 1
		components[index] = component
	end

	local bundler = { add = add, set = set } :: Bundler

	local function spawn(world: jecs.World, compose_with, return_ids: true?): (jecs.Id, { jecs.Id }?)
		local id

		if compose_with then
			id, ids = compose_with(world, nil, true)
		else
			id = world:entity()
		end

		bundle_fn(bundler)

		jecs.bulk_insert(world, id, components, datas)

		if return_ids then
			for _, value in components do
				table.insert(ids, value)
			end

			table.clear(components)
			table.clear(datas)
			table.clear(ids)

			return id, ids
		else
			table.clear(components)
			table.clear(datas)
			table.clear(ids)

			return id, nil
		end
	end

	return spawn :: Bundle
end

return make_bundle :: BundleConstructor
