local revy = require("@revy")
local dialog_resource_plugin = require("./dialog_resource_plugin")
local game_components = require("../game_components")

return revy.plugin("game.dialog_randomiser", function(app: revy.RevyApp)
	local dialog_resource: dialog_resource_plugin.DialogResourceData

	app:add_systems(
		"start",
		revy.system("game.dialog_randomiser.load_resources", function()
			dialog_resource = app:get_resource(dialog_resource_plugin.RESOURCE)
		end)
	)

	app:add_systems(
		"update",
		revy.system("game.dialog_randomiser.update", function(world)
			for id, _dialog_randomiser, dialog, _prompt_triggered_event in
				world:query(
					game_components.DialogRandomiser,
					game_components.Dialog,
					game_components.PromptTriggeredEvent
				)
			do
				print("dialog=", id, _dialog_randomiser, dialog, _prompt_triggered_event)

				if #dialog == 0 then
					continue
				end

				dialog_resource.say(id, dialog[math.random(1, #dialog)])
			end
		end)
	)

	return nil
end)
