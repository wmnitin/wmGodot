extends RefCounted
class_name MatchSim

## Authoritative match. The view only draws this state.
##
## Rule notes live next to the code that implements them:
## - Sending never spends the source count.
## - Growth pauses (the accumulator is kept) while a sending tower has any outgoing link.
## - Neutrals do not grow and do not start links.
## - A lethal hit sets the count to 0 and flips the owner. That soldier is spent.
## - At exactly max count, a friendly arrival is forwarded round-robin instead of added.
## - Opposing owners' soldiers on the same path cancel one for one.
## - Two towers of the same owner can be linked in only one direction. A new
##   link the other way removes the old link. Soldiers already on the old
##   link keep walking and reinforce the destination.
## - Dropping a level removes the newest outgoing links first.

const _Catalog = preload("res://scripts/sim/tower_catalog.gd")
const _Enemy = preload("res://scripts/sim/enemy_ai.gd")
const _Abilities = preload("res://scripts/sim/abilities.gd")

var towers: Array = []
var links: Array = []
var soldiers: Array = []
var blockades: Array = []
var obstacles: Array = []
var hazards: Array = []

var state := "playing"
var elapsed := 0.0
var level_name := "Level"
var level_id := "level"
var level_blurb := ""
var ai_enabled := false
var ai_params := {
	"reaction_interval": 2.0,
	"mistake_chance": 0.15,
	"growth_multiplier": 1.0,
}
var stats := {
	"sent": 0,
	"arrived": 0,
	"captured": 0,
	"cancelled": 0,
	"shots": 0,
	"hazarded": 0,
	"tank_arrivals": 0,
}

var rng := RandomNumberGenerator.new()
var catalog: TowerCatalog

var _by_id := {}
var _next_id := 1
var _next_born := 1
var _ai = null
var _ai_timer := 0.0


func _init() -> void:
	catalog = _Catalog.new()
	rng.seed = 1


func configure(params: Dictionary, seed_value: int) -> void:
	ai_params = params.duplicate()
	rng.seed = seed_value
	_ai = _Enemy.new()
	_ai_timer = 0.0


func load_level(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Level missing: %s" % path)
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Level JSON invalid: %s" % path)
		return false
	setup_direct(data)
	return true


func setup_direct(data: Dictionary) -> void:
	towers.clear()
	links.clear()
	soldiers.clear()
	blockades.clear()
	obstacles.clear()
	hazards.clear()
	_by_id.clear()
	state = "playing"
	elapsed = 0.0
	_ai_timer = 0.0
	stats = {
		"sent": 0,
		"arrived": 0,
		"captured": 0,
		"cancelled": 0,
		"shots": 0,
		"hazarded": 0,
		"tank_arrivals": 0,
	}
	level_name = str(data.get("name", "Level"))
	level_id = str(data.get("id", "level"))
	level_blurb = str(data.get("blurb", ""))
	for raw in data.get("towers", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		towers.append(_make_tower(raw))
	for raw in data.get("blockades", []):
		if typeof(raw) == TYPE_DICTIONARY:
			blockades.append(_make_circle(raw, 80.0))
	for raw in data.get("obstacles", []):
		if typeof(raw) == TYPE_DICTIONARY:
			obstacles.append(_make_obstacle(raw))
	for raw in data.get("hazards", []):
		if typeof(raw) == TYPE_DICTIONARY:
			hazards.append(_make_circle(raw, 70.0))
	_reindex()
	_check_end()


func step(delta: float) -> void:
	if state != "playing":
		return
	var dt := maxf(delta, 0.0)
	elapsed += dt
	_grow(dt)
	_send(dt)
	_move(dt)
	_apply_hazards()
	_cancel_meets()
	_resolve_arrivals()
	_Abilities.tick(self, dt)
	_sweep()
	_check_end()
	if state != "playing" or not ai_enabled or _ai == null:
		return
	_ai_timer += dt
	var interval := float(ai_params.get("reaction_interval", 2.0))
	if _ai_timer >= interval:
		_ai_timer -= interval
		_ai.act(self)
		_sweep()
		_check_end()


func try_connect(source_id: String, target_id: String) -> Dictionary:
	var source := tower(source_id)
	var target := tower(target_id)
	if source.is_empty() or target.is_empty():
		return _fail("missing")
	if source_id == target_id:
		return _fail("same_tower")
	if str(source.owner) == "neutral" or str(source.owner) == "world":
		return _fail("neutral")
	if not can_send_tower(source):
		return _fail("no_send")
	if not bool(spec_of(target).can_be_targeted):
		return _fail("no_target")
	if has_link(source_id, target_id):
		return _fail("exists")
	if path_blocked(source_id, target_id):
		return _fail("blocked")
	if outgoing(source_id).size() >= link_cap(source):
		return _fail("link_cap")
	# One direction only between two towers of the same owner. Flipping the
	# link does not spend the source's cap (the old link belonged to the other tower).
	# Soldiers already walking the old way are released, not deleted.
	if str(source.owner) == str(target.owner):
		var reverse := link_between(target_id, source_id)
		if not reverse.is_empty():
			_release_link(int(reverse.id))
	var link := {
		"id": _alloc_id(),
		"source_id": source_id,
		"target_id": target_id,
		"owner": str(source.owner),
		"born": _next_born,
		"accum": 0.0,
	}
	_next_born += 1
	links.append(link)
	# The first soldier steps off immediately so the stream is visible at once.
	# After that, one soldier leaves each SEND_INTERVAL. The source count is unchanged.
	_spawn_on_link(link, str(source.owner))
	return {"ok": true, "reason": "ok", "id": int(link.id)}


func try_cut(link_id: int) -> bool:
	for link in links:
		if int(link.id) == link_id:
			_remove_link(link_id)
			return true
	return false


func tower(id: String) -> Dictionary:
	if _by_id.has(id):
		return _by_id[id]
	return {}


func spec_of(tower_data: Dictionary) -> Dictionary:
	return catalog.get_type(str(tower_data.get("type", "outpost")))


func can_send_tower(tower_data: Dictionary) -> bool:
	var spec := spec_of(tower_data)
	return bool(spec.can_send) and float(spec.send_scale) > 0.0 and link_cap(tower_data) > 0


func towers_with_owner(owner: String) -> Array:
	var found: Array = []
	for entry in towers:
		if str(entry.owner) == owner:
			found.append(entry)
	return found


func victory_count(owner: String) -> int:
	var total := 0
	for entry in towers:
		if str(entry.owner) == owner and bool(spec_of(entry).counts_for_victory):
			total += 1
	return total


func outgoing(source_id: String) -> Array:
	var found: Array = []
	for link in links:
		if str(link.source_id) == source_id:
			found.append(link)
	return found


func has_link(source_id: String, target_id: String) -> bool:
	return not link_between(source_id, target_id).is_empty()


func link_between(source_id: String, target_id: String) -> Dictionary:
	for link in links:
		if str(link.source_id) == source_id and str(link.target_id) == target_id:
			return link
	return {}


func is_full(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	return int(entry.count) >= int(spec_of(entry).max_count)


func level_of(count: int) -> int:
	if count >= BattleRules.LEVEL_3_AT:
		return 3
	if count >= BattleRules.LEVEL_2_AT:
		return 2
	return 1


func link_cap(tower_data: Dictionary) -> int:
	if not bool(spec_of(tower_data).can_send):
		return 0
	return level_of(int(tower_data.count))


func world_pos(id: String) -> Vector2:
	var entry := tower(id)
	if entry.is_empty():
		return Vector2.ZERO
	return entry.pos


func path_ends(source_id: String, target_id: String) -> PackedVector2Array:
	var a: Vector2 = world_pos(source_id)
	var b: Vector2 = world_pos(target_id)
	var delta := b - a
	var length := delta.length()
	if length < 1.0:
		return PackedVector2Array([a, b])
	var dir := delta / length
	var inset := minf(BattleRules.TOWER_RADIUS, length * 0.35)
	return PackedVector2Array([a + dir * inset, b - dir * inset])


func path_blocked(source_id: String, target_id: String) -> bool:
	var ends := path_ends(source_id, target_id)
	for circle in blockades:
		if Geom.point_segment_distance(circle.pos, ends[0], ends[1]) <= float(circle.radius):
			return true
	for obstacle in obstacles:
		if _segment_hits_obstacle(ends[0], ends[1], obstacle):
			return true
	for entry in towers:
		var id := str(entry.id)
		if id == source_id or id == target_id:
			continue
		var spec := spec_of(entry)
		var radius := 0.0
		if bool(spec.can_be_targeted):
			radius = BattleRules.FOOTPRINT
		if bool(spec.blocks_paths):
			var extra := float(spec.block_radius)
			if extra <= 0.0:
				extra = BattleRules.TOWER_RADIUS
			radius = maxf(radius, extra)
		if radius <= 0.0:
			continue
		if Geom.point_segment_distance(entry.pos, ends[0], ends[1]) <= radius:
			return true
	return false


func _segment_hits_obstacle(a: Vector2, b: Vector2, obstacle: Dictionary) -> bool:
	var shape := str(obstacle.get("shape", "circle"))
	if shape == "rect":
		return _segment_hits_rect(a, b, obstacle.pos, obstacle.half)
	if shape == "polygon":
		return _segment_hits_poly(a, b, obstacle.points)
	return Geom.point_segment_distance(obstacle.pos, a, b) <= float(obstacle.radius)


func _segment_hits_rect(a: Vector2, b: Vector2, center: Vector2, half: Vector2) -> bool:
	var mn := center - half
	var mx := center + half
	var dx := b.x - a.x
	var dy := b.y - a.y
	var t0 := 0.0
	var t1 := 1.0
	if absf(dx) < 0.00001:
		if a.x < mn.x or a.x > mx.x:
			return false
	else:
		var inv_x := 1.0 / dx
		var tax := (mn.x - a.x) * inv_x
		var tbx := (mx.x - a.x) * inv_x
		if tax > tbx:
			var swap_x := tax
			tax = tbx
			tbx = swap_x
		t0 = maxf(t0, tax)
		t1 = minf(t1, tbx)
		if t0 > t1:
			return false
	if absf(dy) < 0.00001:
		if a.y < mn.y or a.y > mx.y:
			return false
	else:
		var inv_y := 1.0 / dy
		var tay := (mn.y - a.y) * inv_y
		var tby := (mx.y - a.y) * inv_y
		if tay > tby:
			var swap_y := tay
			tay = tby
			tby = swap_y
		t0 = maxf(t0, tay)
		t1 = minf(t1, tby)
		if t0 > t1:
			return false
	return true


func _segment_hits_poly(a: Vector2, b: Vector2, points: PackedVector2Array) -> bool:
	var count := points.size()
	if count < 3:
		return false
	if _point_in_poly(a, points) or _point_in_poly(b, points):
		return true
	for i in count:
		var c: Vector2 = points[i]
		var d: Vector2 = points[(i + 1) % count]
		if Geom.segments_near(a, b, c, d, 1.0):
			return true
	return false


func _point_in_poly(point: Vector2, points: PackedVector2Array) -> bool:
	var inside := false
	var j := points.size() - 1
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[j]
		if ((a.y > point.y) != (b.y > point.y)) and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


func _make_obstacle(raw: Dictionary) -> Dictionary:
	var shape := str(raw.get("shape", "circle"))
	var pos := _world_from_norm(float(raw.get("x", 0.5)), float(raw.get("y", 0.5)))
	if shape == "rect":
		return {
			"id": str(raw.get("id", "obs")),
			"shape": "rect",
			"pos": pos,
			"half": Vector2(float(raw.get("hw", 40.0)), float(raw.get("hh", 40.0))),
		}
	if shape == "polygon":
		var pts := PackedVector2Array()
		for point in raw.get("points", []):
			if typeof(point) == TYPE_ARRAY and point.size() >= 2:
				pts.append(_world_from_norm(float(point[0]), float(point[1])))
		return {"id": str(raw.get("id", "obs")), "shape": "polygon", "points": pts, "pos": pos}
	return {
		"id": str(raw.get("id", "obs")),
		"shape": "circle",
		"pos": pos,
		"radius": float(raw.get("radius", 60.0)),
	}


func soldier_position(soldier: Dictionary) -> Vector2:
	var ends := path_ends(str(soldier.source_id), str(soldier.target_id))
	var t := clampf(float(soldier.progress), 0.0, 1.0)
	return ends[0].lerp(ends[1], t)


func spawn_soldier(source_id: String, target_id: String, team: String, progress: float, power: int = 1, speed: float = 1.0, kind: String = "soldier") -> void:
	soldiers.append({
		"id": _alloc_id(),
		"link_id": -1,
		"source_id": source_id,
		"target_id": target_id,
		"team": team,
		"progress": progress,
		"prev_progress": progress,
		"dead": false,
		"power": maxi(1, power),
		"speed": speed,
		"kind": kind,
		"swing": -1.0,
	})


func force_count(id: String, value: int) -> void:
	var entry := tower(id)
	if entry.is_empty():
		return
	var cap := int(spec_of(entry).max_count)
	entry.count = clampi(value, 0, cap)
	_on_count_changed(entry)


func apply_hit(target_id: String, attacker: String) -> void:
	var entry := tower(target_id)
	if entry.is_empty():
		return
	var spec := spec_of(entry)
	if not bool(spec.can_be_targeted):
		return
	if str(entry.owner) == attacker:
		var cap := int(spec.max_count)
		if int(entry.count) >= cap:
			_forward(entry, attacker)
		else:
			entry.count = int(entry.count) + 1
			_on_count_changed(entry)
		return
	if not bool(spec.can_be_captured):
		return
	entry.count = int(entry.count) - 1
	if int(entry.count) <= 0:
		_capture(entry, attacker)
	else:
		_on_count_changed(entry)


## Several points of damage from one shot. Leftover damage does not become
## a garrison after the tower flips.
func apply_volley(target_id: String, attacker: String, amount: int) -> void:
	var entry := tower(target_id)
	if entry.is_empty() or amount <= 0:
		return
	var spec := spec_of(entry)
	if not bool(spec.can_be_targeted) or not bool(spec.can_be_captured):
		return
	if str(entry.owner) == attacker:
		return
	entry.count = int(entry.count) - amount
	if int(entry.count) <= 0:
		_capture(entry, attacker)
	else:
		_on_count_changed(entry)


func spend_count(id: String, amount: int) -> bool:
	var entry := tower(id)
	if entry.is_empty() or int(entry.count) < amount:
		return false
	entry.count = int(entry.count) - amount
	_on_count_changed(entry)
	return true


func nearest_opponent_id(id: String, max_range: float) -> String:
	var source := tower(id)
	if source.is_empty():
		return ""
	var origin: Vector2 = source.pos
	var best := ""
	var best_dist := max_range
	var found := false
	for other in towers:
		if str(other.id) == id:
			continue
		if str(other.owner) == str(source.owner):
			continue
		if not bool(spec_of(other).can_be_captured):
			continue
		var dist := origin.distance_to(other.pos)
		if dist <= max_range and (not found or dist < best_dist):
			found = true
			best_dist = dist
			best = str(other.id)
	return best


func alive_soldiers() -> int:
	var total := 0
	for soldier in soldiers:
		if not bool(soldier.dead):
			total += 1
	return total


func describe() -> String:
	var parts: PackedStringArray = []
	parts.append("state=%s t=%.1f" % [state, elapsed])
	for entry in towers:
		parts.append("%s/%s c=%d lv=%d out=%d" % [
			str(entry.id), str(entry.owner), int(entry.count), level_of(int(entry.count)), outgoing(str(entry.id)).size()
		])
	parts.append("links=%d soldiers=%d" % [links.size(), alive_soldiers()])
	return " | ".join(parts)


func _make_tower(raw: Dictionary) -> Dictionary:
	var type_id := str(raw.get("type", "outpost"))
	if not catalog.has_type(type_id):
		push_warning("Unknown tower type '%s'; using outpost." % type_id)
		type_id = "outpost"
	var spec: Dictionary = catalog.get_type(type_id)
	var owner := str(raw.get("owner", "neutral"))
	if owner != "player" and owner != "enemy" and owner != "neutral" and owner != "world":
		owner = "neutral"
	var pos := _world_from_norm(float(raw.get("x", 0.5)), float(raw.get("y", 0.5)))
	return {
		"id": str(raw.get("id", "t%d" % _alloc_id())),
		"type": type_id,
		"owner": owner,
		"count": clampi(int(raw.get("count", 0)), 0, int(spec.max_count)),
		"pos": pos,
		"norm": Vector2(clampf(float(raw.get("x", 0.5)), 0.0, 1.0), clampf(float(raw.get("y", 0.5)), 0.0, 1.0)),
		"growth_accum": 0.0,
		"ability_accum": 0.0,
		"forward_cursor": 0,
	}


func _make_circle(raw: Dictionary, default_radius: float) -> Dictionary:
	return {
		"id": str(raw.get("id", "c%d" % _alloc_id())),
		"pos": _world_from_norm(float(raw.get("x", 0.5)), float(raw.get("y", 0.5))),
		"radius": float(raw.get("radius", default_radius)),
	}


func _world_from_norm(x: float, y: float) -> Vector2:
	return Vector2(
		clampf(x, 0.0, 1.0) * BattleRules.FIELD_SIZE.x,
		clampf(y, 0.0, 1.0) * BattleRules.FIELD_SIZE.y
	)


func _reindex() -> void:
	_by_id.clear()
	for entry in towers:
		_by_id[str(entry.id)] = entry


func _grow(dt: float) -> void:
	for entry in towers:
		var spec := spec_of(entry)
		if not bool(spec.can_grow):
			continue
		var owner := str(entry.owner)
		# Unclaimed outposts hold a static garrison. They do not recruit.
		if owner != "player" and owner != "enemy":
			continue
		if not bool(spec.grows_while_sending) and not outgoing(str(entry.id)).is_empty():
			continue
		var cap := int(spec.max_count)
		if int(entry.count) >= cap:
			continue
		var scale := float(spec.growth_scale)
		var mult := 1.0
		if owner == "enemy":
			mult = float(ai_params.get("growth_multiplier", 1.0))
		entry.growth_accum = float(entry.growth_accum) + dt * scale * mult
		var guard := 0
		while float(entry.growth_accum) >= BattleRules.GROWTH_INTERVAL and int(entry.count) < cap and guard < 8:
			entry.growth_accum = float(entry.growth_accum) - BattleRules.GROWTH_INTERVAL
			entry.count = int(entry.count) + 1
			_on_count_changed(entry)
			guard += 1


func _send(dt: float) -> void:
	for link in links:
		var source := tower(str(link.source_id))
		if source.is_empty():
			continue
		var spec := spec_of(source)
		if not bool(spec.can_send):
			continue
		var scale := float(spec.send_scale)
		if scale <= 0.0:
			continue
		var interval := BattleRules.SEND_INTERVAL / scale
		link.accum = float(link.accum) + dt
		var guard := 0
		while float(link.accum) >= interval and guard < 4:
			link.accum = float(link.accum) - interval
			# Production is free: the garrison count is not reduced.
			_spawn_on_link(link, str(source.owner))
			guard += 1


func _move(dt: float) -> void:
	for soldier in soldiers:
		if bool(soldier.dead):
			continue
		var ends := path_ends(str(soldier.source_id), str(soldier.target_id))
		var length := maxf(ends[0].distance_to(ends[1]), 40.0)
		var speed_scale := float(soldier.get("speed", 1.0))
		soldier.prev_progress = float(soldier.progress)
		soldier.progress = float(soldier.progress) + BattleRules.SOLDIER_SPEED * speed_scale * dt / length


func _apply_hazards() -> void:
	for soldier in soldiers:
		if bool(soldier.dead):
			continue
		var pos := soldier_position(soldier)
		var hit := false
		for circle in hazards:
			if pos.distance_to(circle.pos) <= float(circle.radius):
				hit = true
				break
		if not hit:
			for entry in towers:
				var radius := float(spec_of(entry).hazard_radius)
				if radius <= 0.0:
					continue
				var id := str(entry.id)
				if id == str(soldier.source_id) or id == str(soldier.target_id):
					continue
				if pos.distance_to(entry.pos) <= radius:
					hit = true
					break
		if hit:
			soldier.dead = true
			stats["hazarded"] = int(stats["hazarded"]) + 1


func _cancel_meets() -> void:
	var groups := {}
	for soldier in soldiers:
		if bool(soldier.dead):
			continue
		var a := str(soldier.source_id)
		var b := str(soldier.target_id)
		var lo := a if a < b else b
		var hi := b if a < b else a
		var key := "%s|%s" % [lo, hi]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(soldier)
	for key in groups.keys():
		var pack: Array = groups[key]
		var forward: Array = []
		var backward: Array = []
		var parts := str(key).split("|")
		var lo := parts[0]
		var hi := parts[1]
		for soldier in pack:
			if str(soldier.source_id) == lo and str(soldier.target_id) == hi:
				forward.append(soldier)
			else:
				backward.append(soldier)
		if forward.is_empty() or backward.is_empty():
			continue
		var pairs: Array = []
		for going in forward:
			for coming in backward:
				var tf := float(going.progress)
				var tb := 1.0 - float(coming.progress)
				var tf0 := float(going.prev_progress)
				var tb0 := 1.0 - float(coming.prev_progress)
				var crossed := (tf0 - tb0) * (tf - tb) <= 0.0
				if str(going.team) == str(coming.team):
					continue
				var gap := soldier_position(going).distance_to(soldier_position(coming))
				if crossed or gap <= 36.0:
					pairs.append({"d": gap, "a": going, "b": coming})
		pairs.sort_custom(func(left, right): return float(left.d) < float(right.d))
		var used := {}
		for pair in pairs:
			var left = pair.a
			var right = pair.b
			if bool(left.dead) or bool(right.dead):
				continue
			if used.has(int(left.id)) or used.has(int(right.id)):
				continue
			var blow := mini(maxi(int(left.get("power", 1)), 1), maxi(int(right.get("power", 1)), 1))
			left.power = int(left.get("power", 1)) - blow
			right.power = int(right.get("power", 1)) - blow
			left.swing = elapsed
			right.swing = elapsed
			if int(left.power) <= 0:
				left.dead = true
				used[int(left.id)] = true
			if int(right.power) <= 0:
				right.dead = true
				used[int(right.id)] = true
			stats["cancelled"] = int(stats["cancelled"]) + blow


func _resolve_arrivals() -> void:
	var snapshot := soldiers.duplicate()
	for soldier in snapshot:
		if bool(soldier.dead) or float(soldier.progress) < 1.0:
			continue
		soldier.dead = true
		var landed := int(soldier.get("power", 1))
		_apply_power(str(soldier.target_id), str(soldier.team), landed)
		if str(soldier.get("kind", "soldier")) == "tank":
			stats["tank_arrivals"] = int(stats.get("tank_arrivals", 0)) + 1
		stats["arrived"] = int(stats["arrived"]) + 1


func _forward(entry: Dictionary, team: String) -> void:
	var outs := outgoing(str(entry.id))
	if outs.is_empty():
		return
	var index := int(entry.forward_cursor) % outs.size()
	entry.forward_cursor = int(entry.forward_cursor) + 1
	_spawn_on_link(outs[index], team)


func _spawn_on_link(link: Dictionary, team: String) -> bool:
	if _in_flight(int(link.id)) >= BattleRules.MAX_IN_FLIGHT:
		return false
	var profile := _unit_profile(str(link.source_id))
	soldiers.append({
		"id": _alloc_id(),
		"link_id": int(link.id),
		"source_id": str(link.source_id),
		"target_id": str(link.target_id),
		"team": team,
		"progress": 0.0,
		"prev_progress": 0.0,
		"dead": false,
		"power": int(profile.power),
		"speed": float(profile.speed),
		"kind": str(profile.kind),
		"swing": -1.0,
	})
	stats["sent"] = int(stats["sent"]) + 1
	return true


func _unit_profile(source_id: String) -> Dictionary:
	var source := tower(source_id)
	if source.is_empty():
		return {"power": 1, "speed": 1.0, "kind": "soldier"}
	var spec := spec_of(source)
	return {
		"power": int(spec.get("unit_power", 1)),
		"speed": float(spec.get("unit_speed", 1.0)),
		"kind": str(spec.get("unit_kind", "soldier")),
	}


func _apply_power(target_id: String, attacker: String, amount: int) -> void:
	var entry := tower(target_id)
	if entry.is_empty() or amount <= 0:
		return
	var spec := spec_of(entry)
	if not bool(spec.can_be_targeted):
		return
	if str(entry.owner) == attacker:
		var cap := int(spec.max_count)
		var space := maxi(cap - int(entry.count), 0)
		var added := mini(amount, space)
		if added > 0:
			entry.count = int(entry.count) + added
			_on_count_changed(entry)
		var leftover := amount - added
		if int(entry.count) >= cap:
			for _i in leftover:
				_forward(entry, attacker)
		return
	if not bool(spec.can_be_captured):
		return
	entry.count = int(entry.count) - amount
	if int(entry.count) <= 0:
		_capture(entry, attacker)
	else:
		_on_count_changed(entry)


func _in_flight(link_id: int) -> int:
	var total := 0
	for soldier in soldiers:
		if not bool(soldier.dead) and int(soldier.link_id) == link_id:
			total += 1
	return total


func _capture(entry: Dictionary, new_owner: String) -> void:
	entry.owner = new_owner
	entry.count = 0
	entry.growth_accum = 0.0
	entry.ability_accum = 0.0
	entry.forward_cursor = 0
	var ids: Array = []
	for link in outgoing(str(entry.id)):
		ids.append(int(link.id))
	for link_id in ids:
		_remove_link(link_id)
	stats["captured"] = int(stats["captured"]) + 1


func _on_count_changed(entry: Dictionary) -> void:
	var cap := link_cap(entry)
	var guard := 0
	while guard < 8:
		var outs := outgoing(str(entry.id))
		if outs.size() <= cap:
			return
		outs.sort_custom(func(a, b): return int(a.born) > int(b.born))
		_remove_link(int(outs[0].id))
		guard += 1


func _remove_link(link_id: int) -> void:
	for soldier in soldiers:
		if int(soldier.link_id) == link_id:
			soldier.dead = true
	_drop_link(link_id)


## Drop the link but let soldiers already on it finish the walk.
func _release_link(link_id: int) -> void:
	for soldier in soldiers:
		if int(soldier.link_id) == link_id and not bool(soldier.dead):
			soldier.link_id = -1
	_drop_link(link_id)


func _drop_link(link_id: int) -> void:
	var kept: Array = []
	for link in links:
		if int(link.id) != link_id:
			kept.append(link)
	links = kept


func _sweep() -> void:
	var kept: Array = []
	for soldier in soldiers:
		if not bool(soldier.dead):
			kept.append(soldier)
			continue
		# Leave a cancelled fighter in place for a short swing so the view can show it.
		var swung := float(soldier.get("swing", -1.0))
		if swung >= 0.0 and elapsed - swung < 0.36:
			kept.append(soldier)
	soldiers = kept


func _check_end() -> void:
	if state != "playing":
		return
	var player_towers := victory_count("player")
	var enemy_towers := victory_count("enemy")
	if player_towers == 0:
		state = "defeat"
	elif enemy_towers == 0:
		state = "victory"


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _alloc_id() -> int:
	var id := _next_id
	_next_id += 1
	return id
