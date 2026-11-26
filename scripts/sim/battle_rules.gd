extends RefCounted
class_name BattleRules

## Tunable match constants. Level scripts and the view read these
## instead of scattering magic numbers.

const MAX_COUNT := 60
const SEND_INTERVAL := 1.0
const GROWTH_INTERVAL := 2.0
const SOLDIER_SPEED := 200.0
const LEVEL_2_AT := 10
const LEVEL_3_AT := 30
const MAX_IN_FLIGHT := 8
const TOWER_RADIUS := 82.0
## A link is blocked when it passes through another tower's body.
## Smaller than the touch radius, so a lane that only grazes a neighbour still connects.
const FOOTPRINT := 70.0
const FIELD_SIZE := Vector2(1000, 1480)

const LEVEL_PATH := "res://data/levels/level_01.json"
