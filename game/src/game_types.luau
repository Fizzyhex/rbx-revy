local revy = require("@revy")

type Entity<T> = revy.Entity<T>

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

export type Renderer = Entity<{ model: Model }>

return nil
