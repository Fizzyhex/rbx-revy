local types = require("./types")
local function collect(signal: any)
	local enqueued = {}

	local i = 0

	local connection = signal:Connect(function(...)
		table.insert(enqueued, { ... })
		i += 1
	end)

	return function(): any
		if i == 0 then
			return
		end

		i -= 1

		local args: any = table.remove(enqueued, 1)

		return unpack(args)
	end,
		connection
end

type Signal<T... = ...any> = types.Signal<T...>

return collect :: <T...>(Signal<T...>) -> (() -> T..., RBXScriptConnection)
