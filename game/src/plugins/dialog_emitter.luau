local revy = require("@revy")
local game_components = require("../game_components")

return revy.plugin("game.dialog_emitter", function(app: revy.RevyApp)
	app:add_systems(
		"update",
		revy.system("game.dialog_emitter.update", function(world)
			for _, dialog, read_dialog, rbx in
				world:query(game_components.Dialog, game_components.ReadDialog, game_components.DialogEmitterRbx)
			do
				rbx.sound:Play()
				local text = dialog[read_dialog]
				game:GetService("Chat"):Chat(rbx.source, text)
			end
		end)
	)
end)
