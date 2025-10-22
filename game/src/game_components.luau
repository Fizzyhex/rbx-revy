local revy = require("@revy")
local ecs = revy.ecs

local game_types = require("./game_types")

local Rotator = ecs.component() :: game_types.Rotator
ecs.meta(Rotator, ecs.Name, "Rotator")

return {
	Rotator = Rotator :: game_types.Rotator,
	Renderer = revy.renderer,
	Transform = revy.transform,
}
