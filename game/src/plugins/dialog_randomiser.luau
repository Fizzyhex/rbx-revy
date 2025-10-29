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
			for id in app:query_event(game_components.PromptTriggeredEvent) do
				local dialog, dialog_randomiser =
					world:get(id, game_components.Dialog), world:get(id, game_components.DialogRandomiser)

				if dialog == nil or dialog_randomiser == nil then
					continue
				end

				print("dialog=", id, dialog[math.random(1, #dialog)])
				dialog_resource.say(id, dialog[math.random(1, #dialog)])
			end
		end)
	)

	return nil
end)
