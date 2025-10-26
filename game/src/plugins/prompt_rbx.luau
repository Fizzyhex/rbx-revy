local revy = require("@revy")
local game_components = require("../game_components")

return revy.plugin("game.prompt_rbx", function(app: revy.RevyApp)
	app:add_systems(
		"update",
		revy.system("game.prompt_rbx.update", function(world)
			for _, prompt_rbx in world:query(game_components.PromptRbx) do
			end
		end)
	)
end)
