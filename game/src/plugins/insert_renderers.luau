local revy = require("@revy")
local game_types = require("../game_types")
local game_components = require("../game_components")

return revy.plugin("game.insert_renderers", function(plugin)
	local app = plugin.app

	local unsub_added = app.world:added(game_components.Renderer, function(id, _component, model: unknown)
		assert(typeof(model) == "Instance")
		assert(model:IsA("Model"))

		if not model:IsDescendantOf(game) then
			local transform = app.world:get(id, game_components.Transform)

			if transform then
				model:PivotTo(transform)
			end

			model.Parent = workspace
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
end)
