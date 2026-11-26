extends RefCounted
class_name FieldDressing

## Meadow trees and props, in the same sim pixels the match uses.
## Hedge foliage is packed inside the obstacle that blocks the lane, and
## every other tree or prop is pushed off any link a soldier is allowed to walk.
## The widest part of a pine (the lowest cone in capy_models.pine_mesh) is 0.34 m.

const PINE_RADIUS_M := 0.34
const HEDGE_H := 0.34


static func segment_hits(a: Vector2, b: Vector2, mark: Dictionary, margin: float) -> bool:
	var shape := str(mark.get("shape", "circle"))
	if shape == "rect":
		return Geom.segment_aabb_distance(a, b, mark.pos, mark.half) <= margin
	if shape == "polygon":
		return Geom.segment_poly_distance(a, b, mark.points) <= margin
	return Geom.point_segment_distance(mark.pos, a, b) <= float(mark.get("radius", 0.0)) + margin


## World-space radius of a round hedge. This is the obstacle radius, exactly.
static func hedge_radius_m(obstacle: Dictionary) -> float:
	return float(obstacle.get("radius", 0.0)) * BattleRules.WORLD_SCALE


## Pines whose foliage stays inside the blocking shape. Circles only;
## a rect or polygon is drawn as that shape and needs no extra trees.
static func hedge_pines(obstacle: Dictionary) -> Array:
	if str(obstacle.get("shape", "circle")) != "circle":
		return []
	var radius_m := hedge_radius_m(obstacle)
	if radius_m <= 0.02:
		return []
	var fit := clampf(radius_m / 1.35, 0.26, 0.52)
	if PINE_RADIUS_M * fit > radius_m:
		fit = radius_m / PINE_RADIUS_M * 0.9
	var ring_m := maxf(radius_m - PINE_RADIUS_M * fit - 0.008, 0.0)
	var pines: Array = []
	if ring_m < 0.05:
		pines.append(_hedge_pine(obstacle, obstacle.pos, fit, 0))
		return pines
	var spacing := PINE_RADIUS_M * fit * 1.9
	var count := clampi(int(round(TAU * ring_m / spacing)), 4, 8)
	for i in count:
		var ang := TAU * float(i) / float(count) + 0.35
		var offset := Vector2(cos(ang), sin(ang)) * (ring_m / BattleRules.WORLD_SCALE)
		var scale := fit * (0.86 + 0.14 * float(i % 3) / 2.0)
		pines.append(_hedge_pine(obstacle, obstacle.pos + offset, scale, i))
	return pines


static func _hedge_pine(obstacle: Dictionary, pos: Vector2, scale: float, index: int) -> Dictionary:
	return {
		"id": "%s_pine_%d" % [str(obstacle.get("id", "hedge")), index],
		"kind": "pine",
		"shape": "circle",
		"pos": pos,
		"radius": PINE_RADIUS_M * scale / BattleRules.WORLD_SCALE,
		"scale": scale,
	}


## Border trees and sand-edge props, moved until they clear every open lane.
static func decor_props(sim: MatchSim) -> Array:
	var placed: Array = []
	for raw in _decor_candidates():
		var radius := float(raw.radius)
		var spot = _seat(sim, raw.pos, radius)
		if spot == null:
			continue
		var mark: Dictionary = raw.duplicate()
		mark.pos = spot
		placed.append(mark)
	return placed


## Obstacle shapes plus every tree and prop the view actually draws.
static func visual_footprints(sim: MatchSim) -> Array:
	var marks: Array = []
	for obstacle in sim.obstacles:
		marks.append(obstacle)
		for pine in hedge_pines(obstacle):
			marks.append(pine)
	for prop in decor_props(sim):
		marks.append(prop)
	return marks


static func hedge_problems(sim: MatchSim) -> PackedStringArray:
	var problems := PackedStringArray()
	for obstacle in sim.obstacles:
		for pine in hedge_pines(obstacle):
			if _pine_inside(obstacle, pine):
				continue
			problems.append("%s pine %s sticks out of %s" % [sim.level_id, str(pine.id), str(obstacle.get("id", "obstacle"))])
	return problems


static func clearance_problems(sim: MatchSim) -> PackedStringArray:
	var problems := PackedStringArray()
	var marks := visual_footprints(sim)
	var towers: Array = sim.towers
	for i in towers.size():
		for j in range(i + 1, towers.size()):
			var a := str(towers[i].id)
			var b := str(towers[j].id)
			if sim.path_blocked(a, b):
				continue
			var ends := sim.path_ends(a, b)
			for mark in marks:
				if not segment_hits(ends[0], ends[1], mark, BattleRules.SOLDIER_HALF_WIDTH):
					continue
				problems.append("%s %s->%s clips %s" % [sim.level_id, a, b, str(mark.get("id", "mark"))])
	return problems


static func _pine_inside(obstacle: Dictionary, pine: Dictionary) -> bool:
	var slack := 1.0
	var shape := str(obstacle.get("shape", "circle"))
	if shape == "rect":
		var half: Vector2 = obstacle.half
		var delta: Vector2 = (pine.pos - obstacle.pos).abs()
		return delta.x + float(pine.radius) <= half.x + slack and delta.y + float(pine.radius) <= half.y + slack
	if shape == "polygon":
		return true
	return pine.pos.distance_to(obstacle.pos) + float(pine.radius) <= float(obstacle.radius) + slack


static func _seat(sim: MatchSim, pos: Vector2, radius: float):
	if _sits_clear(sim, pos, radius):
		return pos
	var center := BattleRules.FIELD_SIZE * 0.5
	var dir := pos - center
	if dir.length_squared() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	for step in 28:
		var trial := pos + dir * (8.0 * float(step + 1))
		if _sits_clear(sim, trial, radius):
			return trial
	return null


static func _sits_clear(sim: MatchSim, pos: Vector2, radius: float) -> bool:
	var need := radius + BattleRules.SOLDIER_HALF_WIDTH
	var towers: Array = sim.towers
	for i in towers.size():
		var origin: Vector2 = towers[i].pos
		if pos.distance_to(origin) <= radius + BattleRules.TOWER_RADIUS:
			return false
		for j in range(i + 1, towers.size()):
			var a := str(towers[i].id)
			var b := str(towers[j].id)
			if sim.path_blocked(a, b):
				continue
			var ends := sim.path_ends(a, b)
			if Geom.point_segment_distance(pos, ends[0], ends[1]) <= need:
				return false
	for obstacle in sim.obstacles:
		if segment_hits(pos, pos, obstacle, radius):
			return false
	return true


static func _decor_candidates() -> Array:
	var field_m := BattleRules.FIELD_SIZE * BattleRules.WORLD_SCALE
	var edge := field_m.y * 0.5 + 0.2
	var specs := [
		{"id": "crate_n", "mesh": KitLibrary.BLASTER + "crate-small.glb", "at": Vector3(-2.2, 0, -edge), "height": 0.42, "yaw": 0.4, "radius_m": 0.24},
		{"id": "barrel_n", "mesh": KitLibrary.SURVIVAL + "barrel.glb", "at": Vector3(1.5, 0, -edge - 0.1), "height": 0.38, "yaw": 0.2, "radius_m": 0.18},
		{"id": "rock_n", "mesh": KitLibrary.NATURE + "rock_largeA.glb", "at": Vector3(2.7, 0, -edge + 0.05), "height": 0.42, "yaw": 0.6, "radius_m": 0.28},
		{"id": "log_n", "mesh": KitLibrary.NATURE + "log.glb", "at": Vector3(-0.15, 0, -edge + 0.15), "height": 0.28, "yaw": 0.5, "radius_m": 0.48},
		{"id": "tire_s", "mesh": KitLibrary.CAR + "debris-tire.glb", "at": Vector3(-3.1, 0, edge), "height": 0.36, "yaw": 0.3, "radius_m": 0.22},
		{"id": "rock_s", "mesh": KitLibrary.SURVIVAL + "rock-b.glb", "at": Vector3(-1.2, 0, edge + 0.05), "height": 0.34, "yaw": 1.1, "radius_m": 0.24},
		{"id": "crate_s", "mesh": KitLibrary.BLASTER + "crate-medium.glb", "at": Vector3(1.9, 0, edge), "height": 0.4, "yaw": -0.4, "radius_m": 0.28},
		{"id": "barrel_s", "mesh": KitLibrary.SURVIVAL + "barrel.glb", "at": Vector3(3.2, 0, edge - 0.08), "height": 0.36, "yaw": 0.8, "radius_m": 0.18},
		{"id": "log_s", "mesh": KitLibrary.SURVIVAL + "tree-log.glb", "at": Vector3(0.35, 0, edge + 0.12), "height": 0.26, "yaw": 1.4, "radius_m": 0.42},
	]
	var marks: Array = []
	for spec in specs:
		var at: Vector3 = spec.at
		marks.append({
			"id": spec.id,
			"kind": "prop",
			"shape": "circle",
			"pos": _to_sim(at),
			"radius": float(spec.radius_m) / BattleRules.WORLD_SCALE,
			"mesh": spec.mesh,
			"height": spec.height,
			"yaw": spec.yaw,
		})
	for i in 7:
		var z := lerpf(-field_m.y * 0.42, field_m.y * 0.42, float(i) / 6.0)
		var left_scale := 0.62 + float(i % 3) * 0.06
		var right_scale := 0.58 + float((i + 1) % 3) * 0.07
		marks.append(_border_pine("pine_w_%d" % i, Vector3(-field_m.x * 0.5, 0, z), left_scale))
		marks.append(_border_pine("pine_e_%d" % i, Vector3(field_m.x * 0.5, 0, z + 0.35), right_scale))
	return marks


static func _border_pine(id: String, at: Vector3, scale: float) -> Dictionary:
	return {
		"id": id,
		"kind": "pine",
		"shape": "circle",
		"pos": _to_sim(at),
		"radius": PINE_RADIUS_M * scale / BattleRules.WORLD_SCALE,
		"scale": scale,
	}


static func _to_sim(world: Vector3) -> Vector2:
	var field := BattleRules.FIELD_SIZE
	var scale := BattleRules.WORLD_SCALE
	return Vector2(world.x / scale + field.x * 0.5, world.z / scale + field.y * 0.5)
