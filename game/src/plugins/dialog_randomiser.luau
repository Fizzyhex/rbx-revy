-- reads dialog in a random order when prompted

local revy = require("@revy")
local dialog_resource_plugin = require("./dialog_resource_plugin")
local game_components = require("../game_components")

return revy.plugin("game.dialog_randomiser", function(plugin)
	local app = plugin.app
	local event_consumer = app:event_consumer()
	local prompt_trigger_event = event_consumer:cache_event(game_components.PromptTriggeredEvent)
	local dialog_resource: dialog_resource_plugin.DialogResourceData

	plugin:add_system(
		"start",
		revy.system(function()
			dialog_resource = app:get_resource(dialog_resource_plugin.RESOURCE)
		end)
	)

	plugin:add_system(
		"update",
		revy.system(function(world: revy.World)
			for id in event_consumer:collect_cached(prompt_trigger_event) do
				local dialog, dialog_randomiser =
					world:get(id, game_components.Dialog), world:get(id, game_components.DialogRandomiser)

				if dialog == nil or dialog_randomiser == nil then
					continue
				end

				dialog_resource.say(id, dialog[math.random(1, #dialog)])
			end
		end)
	)

	return nil
end)
