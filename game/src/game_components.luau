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

local ReadDialog = ecs.component() :: game_types.ReadDialog
ecs.meta(ReadDialog, ecs.Name, "ReadDialog")

local DialogEmitterRbx = ecs.component() :: game_types.DialogEmitterRbx
ecs.meta(DialogEmitterRbx, ecs.Name, "DialogEmitterRbx")
ecs.meta(DialogEmitterRbx, revy.Export, revy.exporters.path_map)

local PromptRbx = ecs.component() :: game_types.PromptRbx
ecs.meta(PromptRbx, ecs.Name, "PromptRbx")
ecs.meta(PromptRbx, revy.Export, revy.exporters.path)

local PromptTriggered = ecs.tag()
ecs.meta(PromptTriggered, ecs.Name, "PromptTriggered")

return {
	Renderer = revy.renderer,
	Transform = revy.transform,

	Rotator = Rotator,

	Dialog = Dialog,
	DialogEmitterRbx = DialogEmitterRbx,
	ReadDialog = ReadDialog,
	DialogCycler = DialogCycler,

	PromptRbx = PromptRbx,
	PromptTriggered = PromptTriggered,

	Unpower = Unpower,
}
