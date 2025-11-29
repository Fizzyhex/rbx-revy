local revy = require("@revy")
local game_components = require("../game_components")

local CYCLE_SPEED = 0.25

return revy.plugin("game.rainbow_highlight_rbx", function(plugin)
	plugin:add_system(
		"update",
		revy.system(function(world)
			for id, _rainbow_highlight, renderer in
				world
					:query(game_components.RainbowHighlight, game_components.Renderer)
					:without(game_components.RainbowHighlightRbx)
			do
				local highlight = Instance.new("Highlight")
				highlight.Name = "Rainbow Highlight"
				highlight.Adornee = renderer
				highlight.FillTransparency = 1
				highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				highlight.Parent = renderer
				world:set(id, game_components.RainbowHighlightRbx, highlight)
			end

			local now = workspace:GetServerTimeNow()

			for _, highlight in world:query(game_components.RainbowHighlightRbx) do
				highlight.OutlineColor = Color3.fromHSV((now * CYCLE_SPEED) % 1, 1, 1)
			end
		end)
	)

	return nil
end)
