local revy = require("@revy")
local game_components = require("../game_components")

return revy.plugin("game.rotator", function(plugin)
	local app = plugin.app

	plugin:add_system(
		"update",
		revy.system(function(world)
			local time = app:get_resource(revy.resources.time)

			for _, rotator, renderer in world:query(game_components.Rotator, game_components.Renderer) do
				renderer:PivotTo(
					renderer:GetPivot()
						* CFrame.Angles(rotator.X * time.delta, rotator.Y * time.delta, rotator.Z * time.delta)
				)
			end
		end)
	)

	plugin:add_system(
		"update",
		revy.system(function(world)
			for _, rotator, renderer in world:query(game_components.Rotator, game_components.Renderer) do
				if not renderer.PrimaryPart then
					continue
				end

				renderer.PrimaryPart.AssemblyAngularVelocity = Vector3.new(rotator.X, rotator.Y, rotator.Z)
			end
		end)
	)

	return nil
end)
