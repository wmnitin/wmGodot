extends RefCounted
class_name TowerLook

## How tall a tower is drawn. Gameplay counts stay in the sim.
## Level 1 is one floor, level 2 adds a second, level 3 a third.
## Inside a level the top floor's height eases from a stub to full
## so the stack grows with every soldier instead of popping.

const RISE := 52.0
const MIN_NEW_FLOOR := 0.2


static func floor_amounts(count: int) -> PackedFloat32Array:
	var floors := PackedFloat32Array([0.0, 0.0, 0.0])
	var c := clampi(count, 0, BattleRules.MAX_COUNT)
	if c < BattleRules.LEVEL_2_AT:
		floors[0] = lerpf(0.46, 1.0, float(c) / float(BattleRules.LEVEL_2_AT - 1))
	elif c < BattleRules.LEVEL_3_AT:
		floors[0] = 1.0
		var span := float(BattleRules.LEVEL_3_AT - 1 - BattleRules.LEVEL_2_AT)
		floors[1] = lerpf(MIN_NEW_FLOOR, 1.0, float(c - BattleRules.LEVEL_2_AT) / span)
	else:
		floors[0] = 1.0
		floors[1] = 1.0
		var span := float(BattleRules.MAX_COUNT - BattleRules.LEVEL_3_AT)
		floors[2] = lerpf(MIN_NEW_FLOOR, 1.0, float(c - BattleRules.LEVEL_3_AT) / span)
	return floors


static func stack_height(count: int) -> float:
	var total := 0.0
	for amount in floor_amounts(count):
		total += RISE * amount
	return total


static func floor_count(count: int) -> int:
	var n := 0
	for amount in floor_amounts(count):
		if amount > 0.001:
			n += 1
	return n
