local ReplicatedStorage = game:GetService("ReplicatedStorage")

local revy = require("@revy")
local game_components = require("../game_components")

local MODEL_PREFAB = ReplicatedStorage:WaitForChild("Susan") :: Model
local SPANW_CFRAME = CFrame.new(38, 6.532, -11.403)
local ROTATION_SPEED = 2

return revy.bundle(function(bundler)
	local add, set = bundler.add, bundler.set

	local model = MODEL_PREFAB:Clone()
	assert(model.PrimaryPart, "susan is missing her PrimaryPart :(")

	add(game_components.RainbowHighlight)
	set(game_components.Renderer, model)
	set(game_components.Transform, SPANW_CFRAME)
	set(game_components.Rotator, Vector3.new(0, ROTATION_SPEED, 0))
	set(game_components.Dialog, { "yo", "hi", "💃" })
	set(game_components.DialogRandomiser, 1)
	set(
		game_components.DialogEmitterRbx,
		{ source = model.PrimaryPart, sound = model.PrimaryPart:WaitForChild("Snap") :: Sound? }
	)
end)
