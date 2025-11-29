local TextChatService = game:GetService("TextChatService")

local revy = require("@revy")
local game_components = require("../game_components")

export type DialogResourceData = {
	say: (entity: revy.Entity, text: string) -> (),
}

type DialogResource = revy.Resource<DialogResourceData>

local RESOURCE = revy.resource("game.dialog_resource") :: DialogResource

return {
	plugin = revy.plugin("game.dialog_resource", function(plugin)
		local app = plugin.app
		local data = {} :: DialogResourceData

		function data.say(entity, text)
			local dialog_emitter_rbx = app.world:get(entity, game_components.DialogEmitterRbx)

			if not dialog_emitter_rbx then
				return
			end

			if dialog_emitter_rbx.sound then
				dialog_emitter_rbx.sound:Play()
			end

			TextChatService:DisplayBubble(dialog_emitter_rbx.source, text)
		end

		app:insert_resource(RESOURCE, data)

		return nil
	end),

	RESOURCE = RESOURCE,
}
