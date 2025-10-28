local revy = require("@revy")
local dialog_resource_plugin = require("./dialog_resource_plugin")
local game_components = require("../game_components")

return revy.plugin("game.dialog_prompt", function(app: revy.RevyApp)
	app:add_systems(
		"update",
		revy.system("game.dialog_prompt.update", function(world)
			local dialog_resource = app:get_resource(dialog_resource_plugin.RESOURCE)

			for id, _prompt_triggered_event, dialog_cycler, dialog in
				world:query(game_components.PromptTriggeredEvent, game_components.DialogCycler, game_components.Dialog)
			do
				dialog_resource.say(id, dialog[dialog_cycler.index])

				dialog_cycler.index += 1

				if dialog_cycler.index > #dialog then
					dialog_cycler.index = 1
				end
			end
		end)
	)

	return nil
end)
