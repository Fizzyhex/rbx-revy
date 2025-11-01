local revy = require("@revy")

type Id<T = any> = revy.Id<T>

type CollectConnection<T...> = revy.Id<{ collect: () -> T..., connection: RBXScriptConnection }>

------------
-- STATE
------------
export type WorldState = {}

------------
-- ENTITY DATA
------------

export type HumanoidCharacterData = {
	humanoid: Humanoid,
}

export type DialogEmitterRbxData = {
	sound: Sound?,
	source: BasePart,
}

------------
-- ENTITIES
------------

export type Rotator = Id<Vector3>

export type Unpower = Id

export type Renderer = Id<{ model: Model }>

--- An array of dialog messages
export type Dialog = Id<{ string }>

--- Cycles thru dialog messages
export type DialogCycler = Id<{ index: number }>

--- Plays random dialog messages
export type DialogRandomiser = Id

--- Renders the dialog in the world
export type DialogEmitterRbx = Id<{
	sound: Sound?,
	source: BasePart,
}>

export type Prompt = Id

export type PromptRbx = Id<ProximityPrompt>

export type PromptConnection = CollectConnection<Player>

return nil
