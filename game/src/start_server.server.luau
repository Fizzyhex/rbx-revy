local revy = require("@revy")
local observe_tag = require("./observe_tag")
local game_components = require("./game_components")
local insert_streamables = require("./plugins/insert_streamables")

local app = revy.app():network_components(game_components):add_plugins(insert_streamables):run()

observe_tag("rotator", function(scope, model)
	assert(model:IsA("Model"), `{model:GetFullName()}:IsA("Model") = false - rotators must be models!`)

	local entity = app.world:entity()
	app.world:add(entity, revy.networked)
	app.world:set(entity, game_components.Rotator, Vector3.new(0, 2, 0))
	app.world:set(entity, game_components.Renderer, model)
	app.world:add(entity, revy.ecs.pair(revy.reliable, game_components.Rotator))
	app.world:add(entity, revy.ecs.pair(revy.reliable, game_components.Renderer))

	table.insert(scope, function()
		app.world:delete(entity)
	end)
end)
