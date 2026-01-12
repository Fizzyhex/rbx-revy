--[=[
	Returns true every `s` seconds passed based on `os.clock`.

	```luau
	local net_rate = interval(1 / 20)

	on_update(function()
		if net_rate() then
			send_network_info()
		end
	end)
	```
=]=]
local function interval(s: number)
	local pin: number = nil :: any

	local function throttle()
		if not pin then
			pin = os.clock()
		end

		local elapsed = os.clock() - pin > s
		if elapsed then
			pin = os.clock()
		end

		return elapsed
	end
	return throttle
end

return interval
