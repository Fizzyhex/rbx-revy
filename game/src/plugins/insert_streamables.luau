local CollectionService = game:GetService("CollectionService")

local revy = require("@revy")
local game_components = require("../game_components")

local TAG = "streamable"

assert(script.Parent)
assert(script.Parent.Parent)
local container = script.Parent.Parent:WaitForChild("data")

return revy.plugin("game.streamable", function(plugin)
	local app = plugin.app
	local to_collect = CollectionService:GetTagged(TAG)
	local on_added = revy.collect(CollectionService:GetInstanceAddedSignal(TAG))
	local on_removed = revy.collect(CollectionService:GetInstanceRemovedSignal(TAG))

	plugin:add_system(
		"update",
		revy.system(function(world)
			for tagged in on_added do
				table.insert(to_collect, tagged)
			end

			for _, tagged in to_collect do
				print(`inserting streamable {tagged:GetFullName()}`)

				if not tagged:IsA("Model") then
					warn(`|- failed - not a Model`)
					continue
				end

				local entity = world:entity()
				local text_entity_name = tagged:GetAttribute("text_entity")

				if text_entity_name == nil then
					warn(`|- streamable {tagged:GetFullName()} is missing text_entity attribute`)
					continue
				elseif typeof(text_entity_name) ~= "string" then
					warn(`|- streamable {tagged:GetFullName()}.text_entity is of the wrong type`)
					continue
				end

				local module = container:FindFirstChild(text_entity_name)

				if not module then
					print("|- module not found")
					continue
				end

				local text_entity = require(module) :: any
				app:load_text_entity(entity, revy.text_entity(text_entity, text_entity_name), tagged)
				world:set(entity, game_components.Transform, tagged:GetPivot())
				world:set(entity, game_components.Renderer, tagged)
			end

			table.clear(to_collect)

			for tagged in on_removed do
				print(`removing streamable {tagged:GetFullName()}`)

				for entity, renderer in world:query(game_components.Renderer) do
					if renderer == tagged then
						world:delete(entity)
						print("|- done")
						return
					end
				end

				warn("|- streamable not found in world - nothing will be removed")
			end
		end)
	)

	return nil
end)
