local revy = require("@revy")
local game_components = require("./game_components")
local rotator_plugin = require("./rotator_plugin")

revy.app():add_plugin(rotator_plugin):network_components(game_components):bind_debugger(Enum.KeyCode.Q):run()
