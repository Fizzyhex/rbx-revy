--!nonstrict

type Implements<Name, Func> = { [Name]: Func }

export type Bin = { ___im_a_bin: true }

export type Task =
	Bin
	| Instance
	| RBXScriptConnection
	| () -> ()
	| (
		...any
	) -> any
		| { destroy: () -> () }
		| { Destroy: () -> () }
		| { doCleanup: () -> () } -- Fusion
		| thread

local BIN_METATABLE = {}

local function throw_unhandled(task: any, type: string)
	warn(
		debug.traceback(
			`[CRITICAL]: Couldn't figure out how to clean '{task}' of type {type}. This may cause memory leaks. It's printed out below.`
		)
	)
	print("task:", task)
end

local function is_bin(t)
	return getmetatable(t) == BIN_METATABLE
end

--- A collection of utilities for manual memory management.
local bin_utils = {}

function bin_utils.insert(bin: Bin, item: Task)
	table.insert(bin, item)
end

function bin_utils.bin(): Bin
	local t = {} :: Bin
	setmetatable(t, BIN_METATABLE)
	return setmetatable(t, BIN_METATABLE)
end

function bin_utils.empty(taskOrBin: Task)
	local any_task = taskOrBin :: any
	local taskType = typeof(taskOrBin)

	if taskType == "Instance" then
		any_task:Destroy()
	elseif taskType == "RBXScriptConnection" then
		any_task:Disconnect()
	elseif taskType == "function" then
		any_task()
	elseif taskType == "table" then
		if typeof(any_task.destroy) == "function" then
			any_task:destroy()
		elseif typeof(any_task.Destroy) == "function" then
			any_task:Destroy()
		elseif typeof(any_task.doCleanup) == "function" then
			-- Fusion
			any_task:doCleanup()
		elseif is_bin(any_task) then
			for _, subtask in any_task do
				bin_utils.empty(subtask)
			end

			table.clear(any_task)
		else
			throw_unhandled(any_task, taskType)
		end
	elseif taskType == "thread" then
		task.cancel(any_task)
	else
		throw_unhandled(any_task, taskType)
	end
end

--[=[
	Returns sugar for managing a table of cleanup tasks.

	```luau
	local bin_add, bin_empty = GarbageUtil.makeBin({})

	-- Add some tasks

	bin_add(function()
		print("Hello, world!")
	end)

	bin_add(Instance.new("Part"))

	bin_add(workspace.ChildAdded)

	-- Now destroy everything in the bin

	bin_empty()
	```
]=]
function bin_utils.make_handlers(tabl: Bin?)
	if not tabl then
		tabl = bin_utils.bin()
	end

	assert(tabl)

	return function(item: unknown)
		table.insert(tabl, item)
		return item
	end, function()
		bin_utils.empty(tabl)
	end
end

do
	local warning_key = {}

	local function multi_clean_warning()
		warn(`Derived scopes should never be cleaned more than once\n{debug.traceback()}`)
	end

	function bin_utils.derive(parent: Bin, child: Bin?)
		if not child then
			child = bin_utils.bin()
		end

		assert(child)

		local key = {}
		parent[key] = child

		table.insert(child, function()
			parent[key] = nil
			child[warning_key] = function()
				child[warning_key] = multi_clean_warning
			end
		end)

		return child
	end
end

return bin_utils
