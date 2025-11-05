local revy = require("@revy")
local game_components = require("../game_components")

local CYCLE_SPEED = 0.25

local function rainbow_highlight_plugin(app: revy.RevyApp)
	app:add_systems(
		"update",
		revy.system("game.rainbow_highlight_rbx.update", function(world)
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
end

return revy.plugin("game.rainbow_highlight_rbx", rainbow_highlight_plugin)
