local revy = require("@revy")
local game_components = require("../game_components")

local function insert_renderers(app: revy.RevyApp)
	-- TODO: Complete, and also swap to world:changed?

	local unsub_added = app.world:added(game_components.Renderer, function(_id, _component, data: unknown)
		assert(typeof(data) == "Instance")

		if not data:IsDescendantOf(game) then
			data.Parent = workspace
		end
	end)

	local unsub_removed = app.world:removed(game_components.Renderer, function(id, component)
		local data = app.world:get(id, component)
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
