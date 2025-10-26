local revy = require("@revy")

type Entity<T = any> = revy.Entity<T>

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

--- Index to read out
export type ReadDialog = Entity<number>

--- Renders the dialog in the world
export type DialogEmitterRbx = Entity<{
	sound: Sound,
	source: BasePart,
}>

export type PromptRbx = Entity<ProximityPrompt>

return nil
