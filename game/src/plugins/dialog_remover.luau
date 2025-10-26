local revy = require("@revy")
local game_components = require("../game_components")

return revy.plugin("game.dialog_remover", function(app: revy.RevyApp)
	app:add_systems(
		"first",
		revy.system("game.dialog_remover.first", function(world)
			for id, dialog, read_dialog in world:query(game_components.Dialog, game_components.ReadDialog) do
				local text = dialog[read_dialog]
				print(`dialog: {text}`)
				world:remove(id, game_components.ReadDialog)
			end
		end)
	)
end)
