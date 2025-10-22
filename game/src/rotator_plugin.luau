local revy = require("@revy")
local game_components = require("./game_components")

local function rotator_plugin(app: revy.RevyApp)
	app:add_systems(
		"update",
		revy.system("game.rotator.update", function(world)
			local time = app:get_resource(revy.time)

			for _, rotator, renderer in world:query(game_components.Rotator, game_components.Renderer) do
				renderer:PivotTo(
					renderer:GetPivot()
						* CFrame.Angles(rotator.X * time.delta, rotator.Y * time.delta, rotator.Z * time.delta)
				)
			end
		end)
	)
end

return revy.plugin("game.rotator", rotator_plugin)
