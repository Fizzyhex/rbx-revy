export type LoggerFn<T = () -> ()> = T & () -> ()

export type LoggerTable = {
	warn: typeof(warn),
	print: typeof(print),
	error: typeof(error),
	assert: typeof(assert),
}

local function search_strip(target: string)
	return target:lower():gsub(" ", "")
end

local LIBRARY_PREFIX = "[revy] "

local function stamp(...: string)
	local output = {}

	for _, s in { ... } do
		if typeof(s) ~= "string" then
			table.insert(output, s)
			continue
		end

		local new = s:gsub("\n(.-)", function(rest)
			if rest:sub(1, #LIBRARY_PREFIX) ~= LIBRARY_PREFIX then
				return `\n{LIBRARY_PREFIX}` .. rest
			else
				return "\n" .. rest
			end
		end)

		table.insert(output, new)
	end

	if #output >= 1 and output[1]:sub(1, #LIBRARY_PREFIX) ~= LIBRARY_PREFIX then
		output[1] = `\n{LIBRARY_PREFIX}{output[1]}`
	end

	return unpack(output)
end

local lib_warn = function(...)
	warn(stamp(...))
end

local lib_print = function(...)
	print(stamp(...))
end

local lib_error = function(message, level)
	error(stamp(message), level)
end

local lib_assert = function(condition: any, ...: string)
	assert(condition, stamp(...))
end

local logger = {
	lib_warn = lib_warn :: typeof(warn),
	lib_print = lib_print :: typeof(print),
	lib_error = lib_error :: typeof(error),
	lib_assert = lib_assert :: typeof(assert),
}

local function to_variable(variable: string)
	return `¥LOG_VAR({variable})`
end

local function to_escaped_variable(variable: string)
	return `¥LOG_VAR%({variable}%)`
end

logger.TAB = "\t"
logger.TINY_TAB = "|- "
logger.BULLET = "•"

function logger.use_var(variable: string)
	return to_variable(variable)
end

function logger.inject_variables<T>(logger_fn: LoggerFn<T>, variable_map: { [any]: any })
	local pattern_map = {}

	for key, value in variable_map do
		pattern_map[to_escaped_variable(key)] = value
	end

	return (
		function(...)
			local modified = { ... }

			for index, value in modified do
				if typeof(value) == "string" then
					local new_string = value

					for var_name, var_value in pattern_map do
						new_string = string.gsub(new_string, var_name, var_value)
					end

					modified[index] = new_string
				end
			end

			return (logger_fn :: LoggerFn)(unpack(modified))
		end :: any
	) :: T
end

function logger.indent<T>(logger_fn: LoggerFn<T>, indent: string?)
	indent = indent or logger.TINY_TAB
	return (
		function(...)
			local indented = {}

			for _, value in { ... } do
				table.insert(indented, `{indent}{string.gsub(value, "\n", `\n{indent}`)}`)
			end

			return (logger_fn :: LoggerFn)(unpack(indented))
		end :: any
	) :: T
end

function logger.find_maybes(search: { string }, term: string)
	local query = search_strip(term)
	local maybes = {}

	for _, value in search do
		local against = search_strip(value)

		if against:find(query) then
			table.insert(maybes, against)
		end
	end

	return maybes :: { string }
end

function logger.maybe_keys(...: {})
	local maybes = {}

	for _, search in { ... } do
		for key in search do
			table.insert(maybes, key)
		end
	end

	return maybes :: { string }
end

function logger.maybe_values(...: {})
	local maybes = {}

	for _, search in { ... } do
		for _, value in search do
			table.insert(maybes, value)
		end
	end

	return maybes :: { string }
end

function logger.format_maybes(maybes: { string })
	local log = { "🙂 maybe you meant:" }

	for key, value in maybes do
		table.insert(log, `{logger.TINY_TAB}{key}. {value}`)
	end

	return table.concat(log, "\n")
end

function logger.add_traceback<T>(logger_fn: LoggerFn<T>)
	return (
		function(...)
			local items = { ... }
			local last = items[#items]

			if typeof(last) == "string" then
				items[#items] = `{last}\n🧵trace: {debug.traceback()}`
			else
				table.insert(items, `\n🧵trace: {debug.traceback()}`)
			end

			return (logger_fn :: LoggerFn)(unpack(items))
		end :: any
	) :: T
end

function logger.new_prefixer<PrefixerT, LoggerT>(prefixer: PrefixerT)
	return (
		function(logger_fn: LoggerFn<LoggerT>)
			return (
				function(...)
					local items = { ... }
					local first = items[1]

					if typeof(first) == "string" then
						items[1] = `{(prefixer :: any)()}{first}`
					else
						table.insert(items, 1, (prefixer :: any)())
					end

					return (logger_fn :: LoggerFn)(unpack(items))
				end :: any
			) :: PrefixerT
		end :: any
	) :: LoggerT
end

function logger.logger_table(config: {
	warn: typeof(warn),
	print: typeof(print),
	error: typeof(error),
	assert: typeof(assert),
}): LoggerTable
	return {
		warn = config.warn or logger.lib_warn,
		print = config.print or logger.lib_print,
		error = config.error or logger.lib_error,
		assert = config.assert or logger.lib_assert,
	}
end

return logger
