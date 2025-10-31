local CollectionService = game:GetService("CollectionService")

local revy = require("@revy")
local game_components = require("../game_components")

local TAG = "streamable"

assert(script.Parent)
assert(script.Parent.Parent)
local container = script.Parent.Parent:WaitForChild("data")

local function insert_renderers(app: revy.RevyApp)
	-- TODO: Complete, and also swap to world:changed?

	local unsub_added = app.world:added(game_components.Renderer, function(id, component, data)
		if not data:IsDescendantOf(workspace) then
			data.Parent = workspace
		end
	end)

	local unsub_removed = app.world:removed(game_components.Renderer, function(id, component)
		if not data:IsDescendantOf(workspace) then
			data.Parent = workspace
		end
	end)

	return function()
		unsub_added()
		unsub_removed()
	end
end

return revy.plugin("game.insert_renderers", insert_renderers)
