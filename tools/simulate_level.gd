extends SceneTree

## Headless rule checks plus a scripted play of Mirror Meadow.
##   godot --headless --path . -s res://tools/simulate_level.gd

var _failed := 0


func _init() -> void:
	print("Capy Tower Wars — rule check")
	_failed = _rules()
	print("Capy Tower Wars — winnable?")
	_failed += _winnable()
	call_deferred("_late_checks")


func _late_checks() -> void:
	_failed += _check("settings save and load", _settings_roundtrip())
	_failed += _occlusion()
	_failed += await _audio_runtime()
	if _failed == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("FAILED CHECKS: %d" % _failed)
		quit(1)


func _rules() -> int:
	var failed := 0
	failed += _check("segments that cross count as a swipe hit", _geom_hit())
	failed += _check("parallel segments far apart are not a swipe hit", _geom_miss())
	failed += _check("level has 7 towers and is left-right symmetrical", _symmetry())
	failed += _check("sending does not reduce the source count", _send_free())
	failed += _check("a link emits one soldier per second after the first", _send_rate())
	failed += _check("idle towers grow; neutrals do not", _growth())
	failed += _check("growth pauses while a link is open and then resumes", _growth_pause())
	failed += _check("friendly arrivals add, enemy arrivals remove", _arrivals())
	failed += _check("a tower flips at zero and loses its outgoing links", _capture())
	failed += _check("link cap follows 1 / 2 / 3 and drops the newest link", _link_caps())
	failed += _check("a full tower forwards friendly soldiers along its links", _passthrough())
	failed += _check("a full tower with nowhere to send absorbs the soldier", _passthrough_stuck())
	failed += _check("opposing soldiers on one path cancel one for one", _cancel())
	failed += _check("a reverse drag between your towers flips the link and in-flight soldiers still reinforce", _own_reverse())
	failed += _check("same-owner soldiers passing each other do not cancel", _own_streams_pass())
	failed += _check("enemy towers also keep only one direction between themselves", _enemy_reverse())
	failed += _check("a reverse drag at the link cap does not delete the old link", _reverse_respects_cap())
	failed += _check("a tower at 60 is full and one at 59 is not", _max_state())
	failed += _check("tower height grows smoothly and adds a floor at each level", _tower_height())
	failed += _check("a seed lobber's extra damage does not garrison the flipped tower", _artillery_volley())
	failed += _check("a blockade circle rejects a crossing link", _blockade_circle())
	failed += _check("a bramble tower blocks the path across it", _blockade_tower())
	failed += _check("a tower body blocks a line that passes through it", _tower_blocks_line())
	failed += _check("a line that only passes beside a tower is allowed", _tower_misses_line())
	failed += _check("a hedge circle, a rect, and a polygon each block a crossing link", _obstacle_shapes())
	failed += _check("Mirror Meadow hedges block the cross lanes and leave the near lanes open", _meadow_lanes())
	failed += _check("hedge trees stay inside their blocking shape", _hedge_containment())
	failed += _check("every open link clears trees, hedges, and props by a soldier width", _link_clearance())
	failed += _check("a mud hazard removes soldiers that enter it", _hazard())
	failed += _check("burrow works grow faster than an outpost", _factory())
	failed += _check("a seed lobber fires and spends one crew", _artillery())
	failed += _check("no enemy towers is a win; no player towers is a loss", _endings())
	failed += _check("Mirror Meadow starts with a neutral tank factory", _has_tank_factory())
	failed += _check("a tank factory sends one power-5 tank about every 3 seconds", _tank_rate())
	failed += _check("tanks move at about 60 percent of soldier speed", _tank_speed())
	failed += _check("one tank cancels five enemy soldiers", _tank_cancels_five())
	failed += _check("a tank adds five on arrival and a bigger hit captures without a garrison", _tank_arrival())
	return failed


func _winnable() -> int:
	var failed := 0
	var settings = load("res://scripts/autoload/game_settings.gd")
	var names := {
		"easy": settings.DIFFICULTIES["easy"],
		"normal": settings.DIFFICULTIES["normal"],
		"hard": settings.DIFFICULTIES["hard"],
	}
	for index in BattleRules.LEVEL_COUNT:
		var number := index + 1
		var path := BattleRules.level_path(number)
		var level_name := _level_name(path)
		for diff_name in ["easy", "normal", "hard"]:
			var result := _play_path(path, names[diff_name], 11)
			var won := str(result.state) == "victory" and bool(result.held)
			var label := "level %02d %s %s %s in %.1fs" % [number, level_name, diff_name, str(result.state), float(result.time)]
			failed += _check(label, won)
			if not won:
				print("    " + str(result.desc))
		if number == 1:
			for seed in [2, 7, 21]:
				var extra := _play_path(path, names["normal"], seed)
				print("    note  normal seed %d -> %s in %.1fs" % [seed, str(extra.state), float(extra.time)])
	return failed


func _occlusion() -> int:
	var failed := 0
	var settings = root.get_node_or_null("GameSettings")
	if settings == null:
		print("  FAIL  max-height towers do not cover the row behind (no settings)")
		return 1
	for index in BattleRules.LEVEL_COUNT:
		var number := index + 1
		settings.set_level_index(number)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1080, 1920)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(viewport)
		var game = load("res://scripts/game/game_view.gd").new()
		viewport.add_child(game)
		game.set_process(false)
		if game.sim == null:
			print("  FAIL  level %02d max-height towers do not cover the row behind (no view)" % number)
			failed += 1
			viewport.queue_free()
			continue
		for entry in game.sim.towers:
			game.sim.force_count(str(entry.id), 60)
		game._fit_camera(true)
		var problems: PackedStringArray = game.occlusion_problems()
		var ok := problems.is_empty()
		failed += _check("level %02d max-height towers do not cover the row behind" % number, ok)
		for line in problems:
			print("    " + line)
		viewport.queue_free()
	return failed


func _level_name(path: String) -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return "Level"
	return str(data.get("name", "Level"))


func _play(params: Dictionary, seed_value: int) -> Dictionary:
	return _play_path(BattleRules.LEVEL_PATH, params, seed_value)


func _play_path(path: String, params: Dictionary, seed_value: int) -> Dictionary:
	var sim := MatchSim.new()
	sim.load_level(path)
	sim.configure(params, seed_value)
	sim.ai_enabled = true
	var bot := MirrorMarch.new()
	var t := 0.0
	var dt := 0.05
	var held := true
	var checked := false
	while t < 180.0 and sim.state == "playing":
		bot.consider(sim, dt)
		sim.step(dt)
		t += dt
		if not checked and t >= 12.0:
			checked = true
			if sim.state == "defeat" or sim.victory_count("player") < 1:
				held = false
	return {"state": sim.state, "time": t, "desc": sim.describe(), "held": held}


func _check(label: String, ok: bool) -> int:
	print("  %s  %s" % ["PASS" if ok else "FAIL", label])
	return 0 if ok else 1


func _step(sim, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		sim.step(0.05)
		t += 0.05


func _fresh(entries: Array, circles: Dictionary = {}) -> MatchSim:
	var sim := MatchSim.new()
	var data := {"name": "test", "towers": entries}
	if circles.has("blockades"):
		data["blockades"] = circles["blockades"]
	if circles.has("hazards"):
		data["hazards"] = circles["hazards"]
	sim.setup_direct(data)
	sim.ai_enabled = false
	return sim


func _pair(owner_a: String, count_a: int, owner_b: String, count_b: int, type_a := "outpost", type_b := "outpost") -> MatchSim:
	return _fresh([
		{"id": "a", "type": type_a, "x": 0.2, "y": 0.5, "owner": owner_a, "count": count_a},
		{"id": "b", "type": type_b, "x": 0.8, "y": 0.5, "owner": owner_b, "count": count_b},
	])


func _geom_hit() -> bool:
	return Geom.segments_near(Vector2(0, 0), Vector2(10, 10), Vector2(0, 10), Vector2(10, 0), 1.0)


func _geom_miss() -> bool:
	return not Geom.segments_near(Vector2(0, 0), Vector2(10, 0), Vector2(0, 40), Vector2(10, 40), 4.0)


func _symmetry() -> bool:
	var sim := MatchSim.new()
	if not sim.load_level(BattleRules.LEVEL_PATH):
		return false
	if sim.towers.size() != 7:
		return false
	if sim.victory_count("player") < 1 or sim.victory_count("enemy") < 1:
		return false
	for tower in sim.towers:
		var mirror_x := 1.0 - float(tower.norm.x)
		var found = null
		for other in sim.towers:
			if absf(float(other.norm.x) - mirror_x) < 0.001 and absf(float(other.norm.y) - float(tower.norm.y)) < 0.001:
				found = other
				break
		if found == null:
			return false
		if str(found.owner) != str(tower.owner) or int(found.count) != int(tower.count) or str(found.type) != str(tower.type):
			return false
	return sim.state == "playing"


func _send_free() -> bool:
	var sim := _pair("player", 16, "enemy", 30)
	var before := int(sim.tower("a").count)
	sim.try_connect("a", "b")
	_step(sim, 3.0)
	return int(sim.tower("a").count) == before and int(sim.stats.sent) >= 3


func _send_rate() -> bool:
	var sim := _pair("player", 20, "enemy", 40)
	sim.try_connect("a", "b")
	if int(sim.stats.sent) != 1:
		return false
	_step(sim, 0.85)
	if int(sim.stats.sent) != 1:
		return false
	_step(sim, 0.30)
	return int(sim.stats.sent) == 2


func _growth() -> bool:
	var sim := _fresh([
		{"id": "p", "type": "outpost", "x": 0.2, "y": 0.8, "owner": "player", "count": 12},
		{"id": "n", "type": "outpost", "x": 0.5, "y": 0.5, "owner": "neutral", "count": 6},
		{"id": "e", "type": "outpost", "x": 0.8, "y": 0.2, "owner": "enemy", "count": 12},
	])
	_step(sim, 1.7)
	if int(sim.tower("p").count) != 12 or int(sim.tower("n").count) != 6:
		return false
	_step(sim, 0.6)
	return int(sim.tower("p").count) == 13 and int(sim.tower("n").count) == 6 and int(sim.tower("e").count) == 13


func _growth_pause() -> bool:
	var sim := _pair("player", 16, "enemy", 40)
	_step(sim, 1.6)
	var linked: Dictionary = sim.try_connect("a", "b")
	_step(sim, 2.0)
	if int(sim.tower("a").count) != 16:
		return false
	sim.try_cut(int(linked.id))
	_step(sim, 0.6)
	return int(sim.tower("a").count) == 17


func _arrivals() -> bool:
	var sim := _pair("player", 5, "enemy", 5)
	sim.spawn_soldier("b", "a", "player", 0.99)
	_step(sim, 0.1)
	if int(sim.tower("a").count) != 6:
		return false
	sim.spawn_soldier("b", "a", "enemy", 0.99)
	_step(sim, 0.1)
	return int(sim.tower("a").count) == 5


func _capture() -> bool:
	var sim := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.3, "owner": "player", "count": 12},
		{"id": "b", "type": "outpost", "x": 0.5, "y": 0.5, "owner": "enemy", "count": 1},
		{"id": "c", "type": "outpost", "x": 0.8, "y": 0.7, "owner": "neutral", "count": 4},
	])
	var linked: Dictionary = sim.try_connect("b", "c")
	if not bool(linked.ok):
		return false
	sim.spawn_soldier("a", "b", "player", 0.99)
	_step(sim, 0.1)
	if str(sim.tower("b").owner) != "player" or int(sim.tower("b").count) != 0:
		return false
	if not sim.outgoing("b").is_empty():
		return false
	var neutral := _fresh([
		{"id": "p", "type": "outpost", "x": 0.2, "y": 0.8, "owner": "player", "count": 8},
		{"id": "n", "type": "outpost", "x": 0.5, "y": 0.5, "owner": "neutral", "count": 1},
		{"id": "e", "type": "outpost", "x": 0.8, "y": 0.2, "owner": "enemy", "count": 8},
	])
	neutral.spawn_soldier("p", "n", "player", 0.99)
	_step(neutral, 0.1)
	return str(neutral.tower("n").owner) == "player" and int(neutral.tower("n").count) == 0


func _link_caps() -> bool:
	var sim := _fresh([
		{"id": "a", "type": "outpost", "x": 0.5, "y": 0.2, "owner": "player", "count": 9},
		{"id": "b", "type": "outpost", "x": 0.2, "y": 0.7, "owner": "neutral", "count": 3},
		{"id": "c", "type": "outpost", "x": 0.8, "y": 0.7, "owner": "neutral", "count": 3},
		{"id": "d", "type": "outpost", "x": 0.5, "y": 0.85, "owner": "enemy", "count": 3},
		{"id": "e", "type": "outpost", "x": 0.85, "y": 0.28, "owner": "enemy", "count": 20},
	])
	if sim.level_of(9) != 1 or sim.level_of(10) != 2 or sim.level_of(29) != 2 or sim.level_of(30) != 3:
		return false
	var first: Dictionary = sim.try_connect("a", "b")
	var second: Dictionary = sim.try_connect("a", "c")
	if not bool(first.ok) or bool(second.ok) or str(second.reason) != "link_cap":
		return false
	sim.force_count("a", 10)
	second = sim.try_connect("a", "c")
	if not bool(second.ok) or sim.outgoing("a").size() != 2:
		return false
	sim.force_count("a", 30)
	var third: Dictionary = sim.try_connect("a", "d")
	if not bool(third.ok) or sim.outgoing("a").size() != 3:
		return false
	var fourth: Dictionary = sim.try_connect("a", "e")
	if bool(fourth.ok):
		return false
	sim.force_count("a", 9)
	if sim.outgoing("a").size() != 1:
		return false
	return int(sim.outgoing("a")[0].id) == int(first.id)


func _passthrough() -> bool:
	var sim := _fresh([
		{"id": "a", "type": "outpost", "x": 0.15, "y": 0.5, "owner": "player", "count": 20},
		{"id": "b", "type": "outpost", "x": 0.5, "y": 0.5, "owner": "player", "count": 60},
		{"id": "c", "type": "outpost", "x": 0.85, "y": 0.5, "owner": "enemy", "count": 30},
	])
	sim.try_connect("b", "c")
	var before := 0
	for soldier in sim.soldiers:
		if str(soldier.target_id) == "c":
			before += 1
	sim.spawn_soldier("a", "b", "player", 0.99)
	_step(sim, 0.1)
	if int(sim.tower("b").count) != 60:
		return false
	var after := 0
	for soldier in sim.soldiers:
		if str(soldier.target_id) == "c" and not bool(soldier.dead):
			after += 1
	return after == before + 1


func _passthrough_stuck() -> bool:
	var sim := _pair("player", 60, "enemy", 10)
	sim.spawn_soldier("b", "a", "player", 0.99)
	_step(sim, 0.1)
	return int(sim.tower("a").count) == 60


func _cancel() -> bool:
	var sim := _pair("player", 18, "enemy", 18)
	sim.try_connect("a", "b")
	sim.try_connect("b", "a")
	_step(sim, 1.6)
	return int(sim.stats.cancelled) >= 1 and int(sim.tower("a").count) == 18 and int(sim.tower("b").count) == 18


func _blockade_circle() -> bool:
	var sim := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.5, "owner": "player", "count": 15},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.5, "owner": "enemy", "count": 15},
	], {"blockades": [{"id": "bush", "x": 0.5, "y": 0.5, "radius": 70}]})
	var blocked: Dictionary = sim.try_connect("a", "b")
	return not bool(blocked.ok) and str(blocked.reason) == "blocked"


func _blockade_tower() -> bool:
	var sim := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.5, "owner": "player", "count": 15},
		{"id": "br", "type": "blockade", "x": 0.5, "y": 0.5, "owner": "world", "count": 1},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.5, "owner": "enemy", "count": 15},
	])
	var blocked: Dictionary = sim.try_connect("a", "b")
	return not bool(blocked.ok) and str(blocked.reason) == "blocked"


func _tower_blocks_line() -> bool:
	var sim := _fresh([
		{"id": "a", "type": "outpost", "x": 0.15, "y": 0.5, "owner": "player", "count": 12},
		{"id": "mid", "type": "outpost", "x": 0.5, "y": 0.5, "owner": "neutral", "count": 4},
		{"id": "b", "type": "outpost", "x": 0.85, "y": 0.5, "owner": "enemy", "count": 12},
	])
	var blocked: Dictionary = sim.try_connect("a", "b")
	var near: Dictionary = sim.try_connect("a", "mid")
	return not bool(blocked.ok) and str(blocked.reason) == "blocked" and bool(near.ok)


func _tower_misses_line() -> bool:
	var sim := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.35, "owner": "player", "count": 12},
		{"id": "side", "type": "outpost", "x": 0.55, "y": 0.78, "owner": "neutral", "count": 4},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.35, "owner": "enemy", "count": 12},
	])
	return bool(sim.try_connect("a", "b").ok)


func _obstacle_shapes() -> bool:
	var circle := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.5, "owner": "player", "count": 12},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.5, "owner": "enemy", "count": 12},
	])
	circle.obstacles.append(circle._make_obstacle({"shape": "circle", "x": 0.5, "y": 0.5, "radius": 50}))
	if bool(circle.try_connect("a", "b").ok):
		return false
	var rect := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.5, "owner": "player", "count": 12},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.5, "owner": "enemy", "count": 12},
	])
	rect.obstacles.append(rect._make_obstacle({"shape": "rect", "x": 0.5, "y": 0.5, "hw": 40, "hh": 30}))
	if bool(rect.try_connect("a", "b").ok):
		return false
	var poly := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.5, "owner": "player", "count": 12},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.5, "owner": "enemy", "count": 12},
	])
	poly.obstacles.append(poly._make_obstacle({
		"shape": "polygon",
		"points": [[0.46, 0.42], [0.54, 0.42], [0.54, 0.58], [0.46, 0.58]],
	}))
	var off := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.5, "owner": "player", "count": 12},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.5, "owner": "enemy", "count": 12},
	])
	off.obstacles.append(off._make_obstacle({"shape": "circle", "x": 0.5, "y": 0.8, "radius": 40}))
	return not bool(poly.try_connect("a", "b").ok) and bool(off.try_connect("a", "b").ok)


func _meadow_lanes() -> bool:
	var sim := MatchSim.new()
	if not sim.load_level(BattleRules.LEVEL_PATH):
		return false
	if sim.obstacles.size() < 2:
		return false
	var open_near := bool(sim.try_connect("p_w", "n_w").ok) and bool(sim.try_connect("p_e", "n_c").ok)
	var cross_blocked := sim.path_blocked("n_w", "p_e") and sim.path_blocked("n_e", "p_w")
	var diagonal_blocked := sim.path_blocked("p_w", "e_e") and sim.path_blocked("e_w", "n_e")
	return open_near and cross_blocked and diagonal_blocked


func _hedge_containment() -> bool:
	var problems := 0
	for index in BattleRules.LEVEL_COUNT:
		var sim := MatchSim.new()
		if not sim.load_level(BattleRules.level_path(index + 1)):
			return false
		var hits := FieldDressing.hedge_problems(sim)
		for line in hits:
			print("    " + line)
			problems += 1
	return problems == 0


func _link_clearance() -> bool:
	var problems := 0
	for index in BattleRules.LEVEL_COUNT:
		var sim := MatchSim.new()
		if not sim.load_level(BattleRules.level_path(index + 1)):
			return false
		var hits := FieldDressing.clearance_problems(sim)
		for line in hits:
			print("    " + line)
			problems += 1
	return problems == 0


func _hazard() -> bool:
	var sim := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.5, "owner": "player", "count": 15},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.5, "owner": "enemy", "count": 15},
	], {"hazards": [{"id": "mud", "x": 0.5, "y": 0.5, "radius": 80}]})
	sim.try_connect("a", "b")
	# Stop before the 2s growth tick so a removed soldier is the only thing that could change the count.
	_step(sim, 1.5)
	return int(sim.stats.hazarded) >= 1 and int(sim.tower("b").count) == 15


func _factory() -> bool:
	var sim := _fresh([
		{"id": "out", "type": "outpost", "x": 0.2, "y": 0.7, "owner": "player", "count": 10},
		{"id": "fac", "type": "factory", "x": 0.4, "y": 0.7, "owner": "player", "count": 10},
		{"id": "e", "type": "outpost", "x": 0.8, "y": 0.2, "owner": "enemy", "count": 10},
	])
	_step(sim, 4.3)
	var outpost_gain := int(sim.tower("out").count) - 10
	var factory_gain := int(sim.tower("fac").count) - 10
	return outpost_gain == 2 and factory_gain == 4


func _artillery() -> bool:
	var sim := _fresh([
		{"id": "gun", "type": "artillery", "x": 0.30, "y": 0.5, "owner": "enemy", "count": 8},
		{"id": "p", "type": "outpost", "x": 0.55, "y": 0.5, "owner": "player", "count": 20},
	])
	if sim.can_send_tower(sim.tower("gun")):
		return false
	_step(sim, 3.2)
	if int(sim.stats.shots) != 0:
		return false
	_step(sim, 0.6)
	return int(sim.stats.shots) >= 1 and int(sim.tower("p").count) < 20


func _endings() -> bool:
	var win := _fresh([
		{"id": "p", "type": "outpost", "x": 0.3, "y": 0.7, "owner": "player", "count": 6},
		{"id": "n", "type": "outpost", "x": 0.5, "y": 0.4, "owner": "neutral", "count": 4},
		{"id": "e", "type": "outpost", "x": 0.7, "y": 0.2, "owner": "enemy", "count": 1},
	])
	win.spawn_soldier("p", "e", "player", 0.99)
	_step(win, 0.1)
	if win.state != "victory" or win.victory_count("player") < 1:
		return false
	if str(win.tower("n").owner) != "neutral":
		return false
	var loss := _pair("player", 1, "enemy", 8)
	loss.spawn_soldier("b", "a", "enemy", 0.99)
	_step(loss, 0.1)
	return loss.state == "defeat"


func _anchor_pair(owner_a: String, count_a: int, owner_b: String, count_b: int) -> MatchSim:
	var keeper := "enemy" if owner_a == "player" else "player"
	return _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.55, "owner": owner_a, "count": count_a},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.55, "owner": owner_b, "count": count_b},
		{"id": "keep", "type": "outpost", "x": 0.5, "y": 0.12, "owner": keeper, "count": 30},
	])


func _flying_to(sim: MatchSim, target_id: String, team: String) -> int:
	var total := 0
	for soldier in sim.soldiers:
		if bool(soldier.dead):
			continue
		if str(soldier.target_id) == target_id and str(soldier.team) == team:
			total += 1
	return total


func _own_reverse() -> bool:
	var sim := _anchor_pair("player", 20, "player", 12)
	if not bool(sim.try_connect("a", "b").ok):
		return false
	_step(sim, 0.45)
	var flying := _flying_to(sim, "b", "player")
	if flying < 1:
		return false
	var before := int(sim.tower("b").count)
	var flipped: Dictionary = sim.try_connect("b", "a")
	if not bool(flipped.ok):
		return false
	if sim.has_link("a", "b") or not sim.has_link("b", "a"):
		return false
	if _flying_to(sim, "b", "player") < 1:
		return false
	var cancelled := int(sim.stats.cancelled)
	_step(sim, 3.0)
	if int(sim.stats.cancelled) != cancelled:
		return false
	# B is sending, so it does not grow. Only the soldiers already on A->B arrive.
	return int(sim.tower("b").count) == before + flying


func _own_streams_pass() -> bool:
	var sim := _anchor_pair("player", 15, "player", 15)
	sim.spawn_soldier("a", "b", "player", 0.42)
	sim.spawn_soldier("b", "a", "player", 0.42)
	var before_a := int(sim.tower("a").count)
	var before_b := int(sim.tower("b").count)
	_step(sim, 0.35)
	var alive := 0
	for soldier in sim.soldiers:
		if not bool(soldier.dead):
			alive += 1
	if alive < 2 or int(sim.stats.cancelled) != 0:
		return false
	_step(sim, 2.4)
	# One growth tick plus one reinforcing arrival on each tower. A cancel would skip the arrival.
	return int(sim.stats.cancelled) == 0 and int(sim.tower("a").count) == before_a + 2 and int(sim.tower("b").count) == before_b + 2


func _enemy_reverse() -> bool:
	var sim := _anchor_pair("enemy", 18, "enemy", 11)
	if not bool(sim.try_connect("a", "b").ok):
		return false
	_step(sim, 0.4)
	var flying := _flying_to(sim, "b", "enemy")
	var before := int(sim.tower("b").count)
	if not bool(sim.try_connect("b", "a").ok):
		return false
	if sim.has_link("a", "b") or not sim.has_link("b", "a"):
		return false
	var cancelled := int(sim.stats.cancelled)
	_step(sim, 3.0)
	return int(sim.stats.cancelled) == cancelled and int(sim.tower("b").count) == before + flying


func _reverse_respects_cap() -> bool:
	var sim := _fresh([
		{"id": "a", "type": "outpost", "x": 0.2, "y": 0.4, "owner": "player", "count": 20},
		{"id": "b", "type": "outpost", "x": 0.5, "y": 0.7, "owner": "player", "count": 8},
		{"id": "c", "type": "outpost", "x": 0.85, "y": 0.45, "owner": "neutral", "count": 4},
		{"id": "e", "type": "outpost", "x": 0.5, "y": 0.12, "owner": "enemy", "count": 20},
	])
	if not bool(sim.try_connect("a", "b").ok):
		return false
	if not bool(sim.try_connect("b", "c").ok):
		return false
	var flipped: Dictionary = sim.try_connect("b", "a")
	return not bool(flipped.ok) and str(flipped.reason) == "link_cap" and sim.has_link("a", "b") and not sim.has_link("b", "a")


func _max_state() -> bool:
	var sim := MatchSim.new()
	if not sim.load_level(BattleRules.LEVEL_PATH):
		return false
	sim.ai_enabled = false
	if sim.is_full(sim.tower("p_w")):
		return false
	sim.force_count("p_w", 59)
	if sim.is_full(sim.tower("p_w")):
		return false
	sim.force_count("p_w", 60)
	if not sim.is_full(sim.tower("p_w")):
		return false
	# A friendly arrival at 60 passes through and the tower stays full.
	sim.try_connect("p_e", "e_w")
	sim.spawn_soldier("p_e", "p_w", "player", 0.99)
	_step(sim, 0.1)
	return int(sim.tower("p_w").count) == 60 and sim.is_full(sim.tower("p_w"))


func _settings_roundtrip() -> bool:
	var settings = root.get_node_or_null("GameSettings")
	if settings == null:
		return false
	var previous := {
		"difficulty": settings.difficulty,
		"music_enabled": settings.music_enabled,
		"sound_enabled": settings.sound_enabled,
		"music_volume": settings.music_volume,
		"sound_volume": settings.sound_volume,
	}
	settings.set_difficulty("hard")
	settings.set_music_enabled(false)
	settings.set_sound_enabled(true)
	settings.set_music_volume(0.25)
	settings.set_sound_volume(0.4)
	settings.difficulty = "easy"
	settings.music_enabled = true
	settings.music_volume = 1.0
	settings.load_settings()
	var ok: bool = settings.difficulty == "hard" \
		and not settings.music_enabled \
		and settings.sound_enabled \
		and is_equal_approx(settings.music_volume, 0.25) \
		and is_equal_approx(settings.sound_volume, 0.4)
	settings.set_difficulty(str(previous.difficulty))
	settings.set_music_enabled(bool(previous.music_enabled))
	settings.set_sound_enabled(bool(previous.sound_enabled))
	settings.set_music_volume(float(previous.music_volume))
	settings.set_sound_volume(float(previous.sound_volume))
	return ok


func _audio_runtime() -> int:
	var names := [
		"music.wav", "spawn.wav", "clash.wav", "capture.wav", "level_up.wav",
		"win.wav", "lose.wav", "ui.wav", "cut.wav", "connect.wav",
		"tank_shot.wav", "tank_rumble.wav",
	]
	for file_name in names:
		if not FileAccess.file_exists("res://assets/audio/%s" % file_name):
			print("  FAIL  soundtrack files exist and music is set to loop (missing %s)" % file_name)
			return 1
	var hooks = root.get_node_or_null("AudioHooks")
	if hooks == null or not hooks.music_is_looping():
		print("  FAIL  soundtrack files exist and music is set to loop (stream is not a forward loop)")
		return 1
	var settings = root.get_node_or_null("GameSettings")
	if settings == null:
		print("  FAIL  soundtrack files exist and music is set to loop (no settings)")
		return 1
	var was_enabled: bool = settings.music_enabled
	var was_volume: float = settings.music_volume
	settings.music_enabled = true
	if settings.music_volume <= 0.001:
		settings.music_volume = 0.7
	hooks.play_sfx("ui")
	hooks.play_sfx("spawn")
	hooks.start_music()
	for _i in 3:
		await process_frame
	var playing: bool = hooks._music.playing
	var driver := str(AudioServer.get_driver_name())
	var assigned: bool = hooks._music.stream != null
	# Dummy (headless, especially macOS) often never flips `playing`. The loop
	# points on the stream are what the real driver uses, so that still fails
	# the check above when the march is not actually set to loop.
	var ok: bool = assigned and (playing or driver == "Dummy")
	if ok and not playing:
		print("    note  %s audio driver did not report playback; the march stream is assigned and set to loop" % driver)
	if not ok:
		print("  FAIL  soundtrack files exist and music is set to loop (driver=%s playing=%s stream=%s)" % [driver, playing, assigned])
	else:
		print("  PASS  soundtrack files exist and music is set to loop")
	settings.music_enabled = was_enabled
	settings.music_volume = was_volume
	if not was_enabled:
		hooks.stop_music()
	return 0 if ok else 1


func _tower_height() -> bool:
	if TowerLook.floor_count(0) != 1 or TowerLook.floor_count(9) != 1:
		return false
	if TowerLook.floor_count(10) != 2 or TowerLook.floor_count(29) != 2:
		return false
	if TowerLook.floor_count(30) != 3 or TowerLook.floor_count(60) != 3:
		return false
	# Height is constant inside a level and steps up only when a floor is added.
	if not is_equal_approx(TowerLook.stack_height(0), TowerLook.stack_height(9)):
		return false
	if not is_equal_approx(TowerLook.stack_height(10), TowerLook.stack_height(29)):
		return false
	if not is_equal_approx(TowerLook.stack_height(30), TowerLook.stack_height(60)):
		return false
	if TowerLook.stack_height(10) <= TowerLook.stack_height(9):
		return false
	if TowerLook.stack_height(30) <= TowerLook.stack_height(29):
		return false
	var low := TowerLook.floor_amounts(4)
	var mid := TowerLook.floor_amounts(20)
	var high := TowerLook.floor_amounts(45)
	return is_equal_approx(float(low[0]), 1.0) and float(low[1]) == 0.0 \
		and is_equal_approx(float(mid[1]), 1.0) and float(mid[2]) == 0.0 \
		and is_equal_approx(float(high[2]), 1.0)


func _artillery_volley() -> bool:
	var sim := _fresh([
		{"id": "gun", "type": "artillery", "x": 0.30, "y": 0.5, "owner": "enemy", "count": 6},
		{"id": "p", "type": "outpost", "x": 0.55, "y": 0.5, "owner": "player", "count": 1},
		{"id": "keep", "type": "outpost", "x": 0.15, "y": 0.85, "owner": "player", "count": 12},
	])
	# An outgoing link stops growth, so the tower is still at 1 when the 2-damage shot lands.
	if not bool(sim.try_connect("p", "keep").ok):
		return false
	_step(sim, 3.8)
	if int(sim.stats.shots) < 1:
		return false
	return str(sim.tower("p").owner) == "enemy" and int(sim.tower("p").count) == 0


func _has_tank_factory() -> bool:
	var sim := MatchSim.new()
	if not sim.load_level(BattleRules.LEVEL_PATH):
		return false
	var found := false
	for tower in sim.towers:
		if str(tower.type) == "tank_factory" and str(tower.owner) == "neutral":
			found = true
	return found


func _tank_pair() -> MatchSim:
	return _fresh([
		{"id": "a", "type": "tank_factory", "x": 0.2, "y": 0.5, "owner": "player", "count": 20},
		{"id": "b", "type": "outpost", "x": 0.8, "y": 0.5, "owner": "enemy", "count": 40},
	])


func _tank_rate() -> bool:
	var sim := _tank_pair()
	if not bool(sim.try_connect("a", "b").ok):
		return false
	if int(sim.stats.sent) != 1:
		return false
	var unit = sim.soldiers[0]
	if str(unit.kind) != "tank" or int(unit.power) != 5:
		return false
	if absf(float(unit.speed) - 0.6) > 0.02:
		return false
	_step(sim, 2.7)
	if int(sim.stats.sent) != 1:
		return false
	_step(sim, 0.5)
	return int(sim.stats.sent) == 2


func _tank_speed() -> bool:
	var sim := _tank_pair()
	sim.try_connect("a", "b")
	var ends := sim.path_ends("a", "b")
	var length := ends[0].distance_to(ends[1])
	_step(sim, 1.0)
	var tank = null
	for soldier in sim.soldiers:
		if str(soldier.kind) == "tank" and not bool(soldier.dead):
			tank = soldier
			break
	if tank == null:
		return false
	var expected := BattleRules.SOLDIER_SPEED * 0.6 / length
	return absf(float(tank.progress) - expected) < 0.08


func _tank_cancels_five() -> bool:
	var sim := _tank_pair()
	sim.spawn_soldier("a", "b", "player", 0.5, 5, 0.6, "tank")
	for _i in 5:
		sim.spawn_soldier("b", "a", "enemy", 0.5, 1, 1.0, "soldier")
	sim.step(0.05)
	var tank_alive := false
	var enemy_alive := 0
	for soldier in sim.soldiers:
		if bool(soldier.dead):
			continue
		if str(soldier.kind) == "tank":
			tank_alive = true
		elif str(soldier.team) == "enemy":
			enemy_alive += 1
	return (not tank_alive) and enemy_alive == 0 and int(sim.stats.cancelled) == 5


func _land_tank(target_owner: String, target_count: int) -> MatchSim:
	var sim := _fresh([
		{"id": "f", "type": "tank_factory", "x": 0.2, "y": 0.5, "owner": "player", "count": 10},
		{"id": "t", "type": "outpost", "x": 0.8, "y": 0.5, "owner": target_owner, "count": target_count},
		{"id": "keep", "type": "outpost", "x": 0.5, "y": 0.9, "owner": "enemy" if target_owner == "player" else "player", "count": 30},
	])
	sim.spawn_soldier("f", "t", "player", 0.7, 5, 0.6, "tank")
	_step(sim, 1.3)
	return sim


func _tank_arrival() -> bool:
	var ally := _land_tank("player", 10)
	if int(ally.tower("t").count) != 15 or int(ally.stats.tank_arrivals) != 1:
		return false
	var foe := _land_tank("enemy", 7)
	if int(foe.tower("t").count) != 2 or str(foe.tower("t").owner) != "enemy":
		return false
	var thin := _land_tank("enemy", 3)
	return str(thin.tower("t").owner) == "player" and int(thin.tower("t").count) == 0
