local TextChatService = game:GetService("TextChatService")

local game_types = require("../game_types")

local dialog_util = {}

function dialog_util.play(dialog_emitter_rbx: game_types.DialogEmitterRbxData, dialog: string)
	if dialog_emitter_rbx.sound then
		dialog_emitter_rbx.sound:Play()
	end

	TextChatService:DisplayBubble(dialog_emitter_rbx.source, dialog)
end

return dialog_util
