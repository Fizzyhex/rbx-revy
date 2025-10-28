local revy = require("@revy")

type Entity<T = any> = revy.Entity<T>

type CollectConnection<T...> = revy.Entity<{ collect: () -> T..., connection: RBXScriptConnection }>

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

export type Rotator = Entity<Vector3>

export type Unpower = Entity

export type Renderer = Entity<{ model: Model }>

--- An array of dialog messages
export type Dialog = Entity<{ string }>

--- Cycles thru dialog messages
export type DialogCycler = Entity<{ index: number }>

--- Plays random dialog messages
export type DialogRandomiser = Entity

--- Renders the dialog in the world
export type DialogEmitterRbx = Entity<{
	sound: Sound?,
	source: BasePart,
}>

export type Prompt = Entity

export type PromptRbx = Entity<ProximityPrompt>

export type PromptConnection = CollectConnection<Player>

return nil
