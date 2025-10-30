local revy = require("@revy")
local dialog_resource_plugin = require("./dialog_resource_plugin")
local game_components = require("../game_components")

return revy.plugin("game.dialog_prompt", function(app: revy.RevyApp)
	local event_consumer = app:event_consumer()
	local dialog_resource = app:get_resource(dialog_resource_plugin.RESOURCE)

	app:add_systems(
		"start",
		revy.system("game.dialog_prompt.start", function()
			dialog_resource = app:get_resource(dialog_resource_plugin.RESOURCE)
		end)
	)

	app:add_systems(
		"update",
		revy.system("game.dialog_prompt.update", function(world)
			for id in event_consumer:collect(game_components.PromptTriggeredEvent) do
				local dialog_cycler, dialog =
					world:get(id, game_components.DialogCycler), world:get(id, game_components.Dialog)

				if dialog_cycler == nil or dialog == nil then
					continue
				end

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
