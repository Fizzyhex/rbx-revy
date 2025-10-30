local revy = require("@revy")
local game_types = require("../game_types")
local game_components = require("../game_components")

-- TODO: Register prompt events here
return revy.plugin("game.prompt_rbx", function(app: revy.RevyApp)
	app:add_systems(
		"first",
		revy.system("game.prompt_rbx.first", function(world: revy.World)
			for entity, prompt_rbx in world:query(game_components.PromptRbx):without(game_components.PromptConnection) do
				local collect, connection = revy.collect(prompt_rbx.Triggered)
				world:set(entity, game_components.PromptConnection, { collect = collect, connection = connection })
			end

			for entity, prompt_connection in world:query(game_components.PromptConnection) do
				for _ in prompt_connection.collect do
					app:event(entity, game_components.PromptTriggeredEvent)
					break
				end
			end
		end)
	)

	app.world:removed(game_components.PromptConnection, function(entity, component: game_types.PromptConnection)
		local collect_connection = app.world:get(entity, component)
		assert(collect_connection)
		collect_connection.connection:Disconnect()
	end)

	return nil
end)
