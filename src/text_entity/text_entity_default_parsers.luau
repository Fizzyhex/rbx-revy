local text_entity_default_parsers = {}

function text_entity_default_parsers.new_parser(func: (data: any, context: any) -> any)
	return func
end

function text_entity_default_parsers.CFrame(data: any, _context, _entity_tree): CFrame
	if typeof(data) ~= "table" then
		return CFrame.identity
	end

	if next(data) == nil then
		return CFrame.identity
	end

	if data.orientation == nil then
		return CFrame.new(Vector3.new(unpack(data.position)))
	end

	assert(
		typeof(data.orientation == "table"),
		"orientation must be an array of numbers. examples below:"
			.. "- cframe = { position = [0, 0, 0], orientation = [0, 0, 0] }"
	)

	if (data.orientation :: { any })[1] == "number" then
		local rx, ry, rz = unpack(data.orientation :: { number })
		return CFrame.new(Vector3.new(unpack(data.position))) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
	end

	error("Unrecognised format for CFrame")
end

function text_entity_default_parsers.Vector3(data: any & { [any]: any }, _context, _entity_tree): Vector3
	assert(
		typeof(data) == "table",
		"Vector3s must be arrays of numbers. Examples below.\nfield = [0, 5, 0]\nfield = [] # defaults to 0, 0, 0"
	)

	if data.x then
		return Vector3.new(data.x, data.y, data.z)
	end

	return Vector3.new(data[1], data[2], data[3])
end

function text_entity_default_parsers.path(path: string, context: any): Instance
	assert(typeof(path) == "string", "expected a string")
	local current_instance: Instance? = context

	if path:sub(1, 1) == "/" then
		path = path:sub(2, -1)
		current_instance = game
	end

	for next_segment in string.gmatch(path, "([^/]+)") do
		current_instance = (current_instance :: Instance):FindFirstChild(next_segment)

		assert(
			current_instance,
			`path '{path}' is invalid @ {next_segment}!\n- make sure the instance exists and no typos are present.\n- if this issue may be caused by streaming, try making the model atomic. see this devforum post: https://devforum.roblox.com/t/new-improvements-to-streaming-enabled/2185535#:~:text=Fewer%20WaitForChild%20Calls`
		)
	end

	return current_instance :: Instance
end

function text_entity_default_parsers.path_map(data: any, context: any, _entity_tree): { [string]: Instance }
	assert(typeof(data) == "table", "invalid data - if you want to leave this field blank, type {} instead")

	local result = {}

	for key, path in data do
		result[key] = text_entity_default_parsers.path(path, context)
	end

	return result
end

return text_entity_default_parsers
