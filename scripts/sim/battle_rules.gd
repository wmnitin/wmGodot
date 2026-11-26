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
## Sim pixels per world metre. The meadow view and the dressing footprints share this.
const WORLD_SCALE := 0.012
## Half the soldier's body width, in sim pixels (~0.24 m). A marching line has to
## stay this far off every hedge, tree, and prop, or the body walks through it.
const SOLDIER_HALF_WIDTH := 20.0

const LEVEL_PATH := "res://data/levels/level_01.json"
const LEVEL_COUNT := 10


static func level_path(index: int) -> String:
	return "res://data/levels/level_%02d.json" % clampi(index, 1, LEVEL_COUNT)
