local ReplicatedStorage = game:GetService("ReplicatedStorage")

local revy = require("@revy")
local game_components = require("../game_components")

local MODEL_PREFAB = ReplicatedStorage:WaitForChild("Susan") :: Model
local SPAWN_POINT = CFrame.new(38, 6.532, -11.403)
local ROTATION_SPEED = 2

local component, tag = revy.bundles.component, revy.bundles.tag

return revy.bundles.bundle(function(ctx)
	local model = MODEL_PREFAB:Clone()
	assert(model.PrimaryPart, "susan is missing her PrimaryPart :(")

	tag(ctx, game_components.RainbowHighlight)
	component(ctx, game_components.Renderer, model)
	component(ctx, game_components.Transform, SPAWN_POINT)
	component(ctx, game_components.Rotator, Vector3.new(0, ROTATION_SPEED, 0))
	component(ctx, game_components.Dialog, { "yo", "hi", "💃" })
	component(ctx, game_components.DialogRandomiser, 1)
	component(
		ctx,
		game_components.DialogEmitterRbx,
		{ source = model.PrimaryPart, sound = model.PrimaryPart:WaitForChild("Snap") :: Sound? }
	)
end)
