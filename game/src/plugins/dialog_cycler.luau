-- cycles thru dialog in-order when prompted

local revy = require("@revy")
local dialog_resource_plugin = require("./dialog_resource_plugin")
local game_components = require("../game_components")

return revy.plugin("game.dialog_cycler", function(plugin)
	local app = plugin.app
	local event_consumer = app:event_consumer()
	local dialog_resource: dialog_resource_plugin.DialogResourceData

	plugin:acquire_resources(function(...)
		dialog_resource = ...
	end, dialog_resource_plugin.RESOURCE)

	plugin:add_system(
		"update",
		revy.system(function(world)
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
