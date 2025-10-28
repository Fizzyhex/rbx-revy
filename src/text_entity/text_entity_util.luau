local replecs = require("@packages/.pesde/pepeeltoro41_replecs@0.0.2/replecs/src")
local jecs = require("@packages/jecs")
local logger = require("@revy/log/logger")

type Context = any
type NameComponentMap = { [string]: any }
type Parser = (data: any, context: Context) -> any
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
	raw_data: unknown,
	context: Context
)
	if parser_context.component_parser_map[component] then
		return parser_context.component_parser_map[component](raw_data, context)
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
	logger_variables
)
	if text_entity.components then
		for component_name, raw_data in text_entity.components do
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
				return parse_component_data(parser_context, component, raw_data, context)
			end)

			if not ok then
				local warn = logger.inject_variables(logger.lib_warn, logger_variables)
				warn(
					`{SOURCE}{text_entity_path("components", component_name)} contains invalid data and cannot be loaded!`
				)
				logger.indent(warn)(data)
				continue
			end

			parser_context.world:set(entity, component, data)
		end
	end

	if text_entity.tags then
		for _, tag_name in text_entity.tags do
			local tag = parser_context.name_component_map[tag_name]

			if not tag then
				local warn = logger.inject_variables(logger.lib_warn, logger_variables)
				warn(`{SOURCE}tag {tag_name} could not be found - has it been assigned a jecs.Name?`)
				did_you_mean(warn, parser_context, tag_name)
				continue
			end

			parser_context.world:add(entity, tag)
			--print("insert tag", entity, tag_name, tag)
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
				local pair_with = get_pair_by_name(parser_context, pair_name)

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
