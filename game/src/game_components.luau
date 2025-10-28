local revy = require("@revy")
local ecs = revy.ecs

local game_types = require("./game_types")

local Rotator = ecs.component() :: game_types.Rotator
ecs.meta(Rotator, ecs.Name, "Rotator")
ecs.meta(Rotator, revy.Export, revy.exporters.Vector3)

local Unpower = ecs.component() :: game_types.Unpower
ecs.meta(Unpower, ecs.Name, "Unpower")

local Dialog = ecs.component() :: game_types.Dialog
ecs.meta(Dialog, ecs.Name, "Dialog")

local DialogCycler = ecs.component() :: game_types.DialogCycler
ecs.meta(DialogCycler, ecs.Name, "DialogCycler")

local DialogEmitterRbx = ecs.component() :: game_types.DialogEmitterRbx
ecs.meta(DialogEmitterRbx, ecs.Name, "DialogEmitterRbx")
ecs.meta(DialogEmitterRbx, revy.Export, revy.exporters.path_map)

local Prompt = ecs.tag() :: game_types.Prompt
ecs.meta(Prompt, ecs.Name, "Prompt")

local PromptRbx = ecs.component() :: game_types.PromptRbx
ecs.meta(PromptRbx, ecs.Name, "PromptRbx")
ecs.meta(PromptRbx, revy.Export, revy.exporters.path)

local PromptTriggeredEvent = ecs.component()
ecs.meta(PromptTriggeredEvent, ecs.Name, "PromptTriggeredEvent")
ecs.meta(PromptTriggeredEvent, revy.FrameEvent)

local PromptConnection = ecs.component() :: game_types.PromptConnection
ecs.meta(PromptConnection, ecs.Name, "PromptConnection")

local DialogRandomiser = ecs.component() :: game_types.DialogRandomiser
ecs.meta(DialogRandomiser, ecs.Name, "DialogRandomiser")

return {
	Renderer = revy.renderer,
	Transform = revy.transform,

	Rotator = Rotator,

	Dialog = Dialog,
	DialogEmitterRbx = DialogEmitterRbx,
	DialogCycler = DialogCycler,
	DialogRandomiser = DialogRandomiser,

	Prompt = Prompt,
	PromptRbx = PromptRbx,
	PromptTriggeredEvent = PromptTriggeredEvent,
	PromptConnection = PromptConnection,

	Unpower = Unpower,
}
