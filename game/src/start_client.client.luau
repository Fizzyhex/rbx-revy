local revy = require("@revy")
local dialog_prompt_inserter = require("./plugins/dialog_prompt_inserter")
local rainbow_highlight_rbx = require("./plugins/rainbow_highlight_rbx")
local Susan = require("./bundles/Susan")
local insert_renderers = require("./plugins/insert_renderers")
local prompt_rbx = require("./plugins/prompt_rbx")
local insert_streamables = require("./plugins/insert_streamables")
local game_components = require("./game_components")
local rotator_plugin = require("./plugins/rotator_plugin")
local dialog_cycler = require("./plugins/dialog_cycler")
local dialog_resource_plugin = require("./plugins/dialog_resource_plugin")
local dialog_randomiser = require("./plugins/dialog_randomiser")

assert(script.Parent)

local app = revy.app()
	:add_plugins(
		rotator_plugin,
		insert_streamables,
		prompt_rbx,
		dialog_resource_plugin.plugin,
		dialog_cycler,
		dialog_randomiser,
		dialog_prompt_inserter,
		insert_renderers,
		rainbow_highlight_rbx
	)
	:network_components(game_components)
	:bind_debugger(Enum.KeyCode.Q)
	:enable_hot_reloading(script.Parent:WaitForChild("plugins"))
	:run()

-- spawn susan
Susan(app.world)
