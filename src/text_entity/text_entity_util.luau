--!nolint BuiltinGlobalWrite
if _G.ENGINE == "prison" then
	require = require("@self/../../roblox_require") :: any
end

local jecs = require("@packages/jecs")
local replecs = require("@packages/replecs")
local logger = require("@revy/log/logger")

type Context = any
type NameComponentMap = { [string]: any }
--- Contains an array of all parent ids of the text entity, if present
type EntityTree = { jecs.Entity }
type Parser = (data: any, context: Context, entity_tree: EntityTree) -> any
type ComponentParserMap = { [any]: Parser }

type ParserContext = {
	world: jecs.World,
	name_component_map: NameComponentMap,
	component_parser_map: ComponentParserMap,
	pairs: { [string]: unknown },
}

local function parse_component_data(
	parser_context: ParserContext,
	component: unknown,
	raw_data: any,
	context: Context,
	entity_tree: EntityTree
)
	if parser_context.component_parser_map[component] then
		if typeof(raw_data) == "table" and not table.isfrozen(raw_data) then
			table.freeze(raw_data :: any)
		end

		return parser_context.component_parser_map[component](raw_data, context, entity_tree)
	else
		return raw_data
	end
end

local function get_pair_by_name(parser_context: ParserContext, pair_name: string)
	return parser_context.pairs[pair_name] or parser_context.name_component_map[pair_name]
end

local function did_you_mean(logger_fn, parser_context: ParserContext, pair_name: string)
	local search_result =
		logger.find_maybes(logger.maybe_keys(parser_context.pairs, parser_context.name_component_map), pair_name)

	if #search_result > 0 then
		logger_fn(logger.format_maybes(search_result))
	end
end

local global_parser_tag: jecs.Entity

local text_entity_util = {}
text_entity_util.LOG_TEXT_ENTITY_NAME = "text_entity_name"

local SOURCE = `error in text entity {logger.use_var(text_entity_util.LOG_TEXT_ENTITY_NAME)}:\n`

local function text_entity_path(...: string)
	local result = { logger.use_var(text_entity_util.LOG_TEXT_ENTITY_NAME) }

	for _, value in { ... } do
		table.insert(result, value)
	end

	return table.concat(result, ".")
end

function text_entity_util.parse(
	parser_context: ParserContext,
	entity: jecs.Entity,
	text_entity: any,
	context: Context,
	logger_variables: { [any]: any },
	entity_tree: EntityTree?
)
	local components = (text_entity.components or {}) :: { [any]: any }
	local tags = (text_entity.tags or {}) :: { [any]: any }

	entity_tree = entity_tree or {}
	table.insert(entity_tree, entity)
	local networked = {}

	if text_entity.net_components then
		components = table.clone(components)

		for component_name, raw_data in text_entity.net_components do
			components[component_name] = raw_data
			networked[component_name] = true
		end

		parser_context.world:add(entity, replecs.networked)
	end

	if text_entity.net_tags then
		tags = table.clone(tags)

		for _, tag in text_entity.net_tags do
			table.insert(tags, tag)
			networked[tag] = true
		end

		parser_context.world:add(entity, replecs.networked)
	end

	for component_name, raw_data in components do
		local component = parser_context.name_component_map[component_name]

		if component == nil then
			local warn = logger.inject_variables(logger.lib_warn, logger_variables)

			warn(
				`{SOURCE}{text_entity_path("components", component_name)} could not be found - has it been assigned a jecs.Name?`
			)
			did_you_mean(warn, parser_context, component_name)
			continue
		end

		local ok, data = pcall(function()
			return parse_component_data(parser_context, component, raw_data, context, entity_tree :: EntityTree)
		end)

		if not ok then
			local warn = logger.inject_variables(logger.lib_warn, logger_variables)
			warn(`{SOURCE}{text_entity_path("components", component_name)} contains invalid data and cannot be loaded!`)
			logger.indent(warn)(data)
			warn(`trace: {debug.traceback()}`)
			continue
		end

		parser_context.world:set(entity, component, data)

		if networked[component_name] then
			parser_context.world:add(entity, jecs.pair(replecs.reliable, component))
		end
	end

	for _, tag_name in tags do
		local tag = parser_context.name_component_map[tag_name]

		if not tag then
			local warn = logger.inject_variables(logger.lib_warn, logger_variables)
			warn(`{SOURCE}tag {tag_name} could not be found - has it been assigned a jecs.Name?`)
			did_you_mean(warn, parser_context, tag_name)
			continue
		end

		parser_context.world:add(entity, tag)
		--print("insert tag", entity, tag_name, tag)

		if networked[tag_name] then
			parser_context.world:add(entity, jecs.pair(replecs.reliable, tag))
		end
	end

	if text_entity.pairs then
		for pair_name, pair_with_array in text_entity.pairs do
			local pair = get_pair_by_name(parser_context, pair_name)

			if not pair then
				local warn = logger.inject_variables(logger.lib_warn, logger_variables)
				warn(`{SOURCE}pair[1] '{pair_name}' could not be found - has it been registered?`)
				did_you_mean(warn, parser_context, pair_name)
				continue
			end

			if typeof(pair_with_array) == "string" then
				pair_with_array = { pair_with_array }
			end

			if #pair_with_array == 0 then
				logger.lib_warn(`remove empty pair\n[pairs]...\n\n{pair_name} = \{}`)
			end

			for _, pair_with_name in pair_with_array do
				local pair_with = get_pair_by_name(parser_context, pair_with_name)

				if not pair_with then
					local warn = logger.inject_variables(logger.lib_warn, logger_variables)
					warn(`{SOURCE}pair[2] '{pair_with}' could not be found - has it been registered?`)
					did_you_mean(warn, parser_context, pair_name)
					continue
				end

				if typeof(pair_with_name) == "string" then
					parser_context.world:add(entity, jecs.pair(pair, pair_with))
					--print("insert pair", entity, pair_name, pair_with_name, pair, pair_with)
				end
			end
		end
	end

	if text_entity.children then
		for i, child in text_entity.children do
			logger_variables[text_entity_util.LOG_TEXT_ENTITY_NAME] =
				`{logger_variables[text_entity_util.LOG_TEXT_ENTITY_NAME]}.children[{i}]`
			local child_entity = parser_context.world:entity()
			parser_context.world:add(child_entity, jecs.pair(jecs.ChildOf, entity))
			text_entity_util.parse(parser_context, child_entity, child, context, logger_variables, entity_tree)
		end
	end
end

function text_entity_util.new_parser_context(world: jecs.World, custom_pairs): ParserContext
	local name_component_map: NameComponentMap = {}

	world:added(jecs.Name, function(_, component, name) -- (entity, id, data)
		name_component_map[name] = component
	end)

	for name, component in world:query(jecs.Name) do
		name_component_map[component] = name
	end

	local component_parser_map: ComponentParserMap = {}

	world:added(global_parser_tag :: any, function(_, component, parser) -- (entity, id, data)
		component_parser_map[component] = parser
	end)

	for component, name in world:query(global_parser_tag) do
		component_parser_map[component] = name
	end

	return {
		world = world,
		name_component_map = name_component_map,
		component_parser_map = component_parser_map,
		pairs = custom_pairs,
	}
end

return function(parser_tag: jecs.Entity)
	assert(not global_parser_tag, "there can only be one!")
	global_parser_tag = parser_tag
	return text_entity_util
end
