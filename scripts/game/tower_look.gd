extends RefCounted
class_name TowerLook

## How tall a tower is drawn. Height changes only when the level changes:
## one full floor below 10, two from 10, three from 30. The count inside a
## level does not stretch the building. MAX is a badge, not a fourth floor.

const RISE := 52.0


static func floor_amounts(count: int) -> PackedFloat32Array:
	var floors := PackedFloat32Array([0.0, 0.0, 0.0])
	var level := 1
	if count >= BattleRules.LEVEL_3_AT:
		level = 3
	elif count >= BattleRules.LEVEL_2_AT:
		level = 2
	for i in level:
		floors[i] = 1.0
	return floors


static func stack_height(count: int) -> float:
	return RISE * float(floor_count(count))


static func floor_count(count: int) -> int:
	if count >= BattleRules.LEVEL_3_AT:
		return 3
	if count >= BattleRules.LEVEL_2_AT:
		return 2
	return 1
