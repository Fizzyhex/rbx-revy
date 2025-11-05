local revy = require("@revy")
local game_types = require("../game_types")
local game_components = require("../game_components")

local function insert_renderers(app: revy.RevyApp)
	local unsub_added = app.world:added(game_components.Renderer, function(id, _component, modle: unknown)
		assert(typeof(modle) == "Instance")
		assert(modle:IsA("Model"))

		if not modle:IsDescendantOf(game) then
			local transform = app.world:get(id, game_components.Transform)

			if transform then
				modle:PivotTo(transform)
			end

			modle.Parent = workspace
		end
	end)

	local unsub_removed = app.world:removed(game_components.Renderer, function(id, component)
		local data = app.world:get(id, component :: game_types.Renderer)
		assert(typeof(data) == "Instance")

		if data.Parent == workspace then
			data:Destroy()
		end
	end)

	return function()
		unsub_added()
		unsub_removed()
	end
end

return revy.plugin("game.insert_renderers", insert_renderers)
