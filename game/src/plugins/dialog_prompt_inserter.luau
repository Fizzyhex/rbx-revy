-- cycles thru dialog in-order when prompted

local revy = require("@revy")
local game_components = require("../game_components")

return revy.plugin("game.dialog_prompt_inserter", function(plugin)
	plugin:add_system(
		"update",
		revy.system(function(world)
			for id, _dialog, renderer in
				world:query(game_components.Dialog, game_components.Renderer):without(game_components.PromptRbx)
			do
				world:add(id, game_components.Prompt)

				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "DialogPrompt"
				prompt.ActionText = "Talk"
				prompt.Parent = renderer

				world:set(id, game_components.PromptRbx, prompt)
			end
		end)
	)

	return nil
end)
