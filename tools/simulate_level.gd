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
	_failed += _audio_runtime()
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
	failed += _check("a mud hazard removes soldiers that enter it", _hazard())
	failed += _check("burrow works grow faster than an outpost", _factory())
	failed += _check("a seed lobber fires and spends one crew", _artillery())
	failed += _check("no enemy towers is a win; no player towers is a loss", _endings())
	return failed


func _winnable() -> int:
	var failed := 0
	var settings = load("res://scripts/autoload/game_settings.gd")
	var normal: Dictionary = settings.DIFFICULTIES["normal"]
	var easy: Dictionary = settings.DIFFICULTIES["easy"]
	var hard: Dictionary = settings.DIFFICULTIES["hard"]
	var primary := _play(normal, 11)
	failed += _check(
		"scripted herd beats Normal (seed 11) in %.1fs" % float(primary.time),
		str(primary.state) == "victory"
	)
	if str(primary.state) != "victory":
		print("    " + str(primary.desc))
	for seed in [2, 7, 21]:
		var extra := _play(normal, seed)
		var ok := str(extra.state) == "victory"
		print("    note  normal seed %d -> %s in %.1fs" % [seed, str(extra.state), float(extra.time)])
		if not ok:
			print("    " + str(extra.desc))
	var easy_result := _play(easy, 11)
	print("    note  easy seed 11 -> %s in %.1fs" % [str(easy_result.state), float(easy_result.time)])
	var hard_result := _play(hard, 11)
	print("    note  hard seed 11 -> %s in %.1fs" % [str(hard_result.state), float(hard_result.time)])
	return failed


func _play(params: Dictionary, seed_value: int) -> Dictionary:
	var sim := MatchSim.new()
	sim.load_level(BattleRules.LEVEL_PATH)
	sim.configure(params, seed_value)
	sim.ai_enabled = true
	var bot := MirrorMarch.new()
	var t := 0.0
	var dt := 0.05
	while t < 180.0 and sim.state == "playing":
		bot.consider(sim, dt)
		sim.step(dt)
		t += dt
	return {"state": sim.state, "time": t, "desc": sim.describe()}


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
		{"id": "e", "type": "outpost", "x": 0.5, "y": 0.5, "owner": "enemy", "count": 20},
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
	]
	for file_name in names:
		if not FileAccess.file_exists("res://assets/audio/%s" % file_name):
			print("  FAIL  soundtrack files exist and music is set to loop")
			return 1
	var hooks = root.get_node_or_null("AudioHooks")
	if hooks == null or not hooks.music_is_looping():
		print("  FAIL  soundtrack files exist and music is set to loop")
		return 1
	hooks.play_sfx("ui")
	hooks.play_sfx("spawn")
	hooks.start_music()
	var playing: bool = hooks._music.playing
	print("  %s  soundtrack files exist and music is set to loop" % ("PASS" if playing else "FAIL"))
	return 0 if playing else 1


func _tower_height() -> bool:
	if TowerLook.floor_count(0) != 1 or TowerLook.floor_count(9) != 1:
		return false
	if TowerLook.floor_count(10) != 2 or TowerLook.floor_count(29) != 2:
		return false
	if TowerLook.floor_count(30) != 3 or TowerLook.floor_count(60) != 3:
		return false
	var amounts_10 := TowerLook.floor_amounts(10)
	var amounts_29 := TowerLook.floor_amounts(29)
	var amounts_30 := TowerLook.floor_amounts(30)
	var amounts_60 := TowerLook.floor_amounts(60)
	if float(amounts_10[1]) >= float(amounts_29[1]):
		return false
	if float(amounts_29[1]) < 0.99:
		return false
	if float(amounts_30[2]) >= float(amounts_60[2]):
		return false
	if float(amounts_60[2]) < 0.99:
		return false
	var previous := -1.0
	for count in [0, 4, 9, 10, 20, 29, 30, 45, 60]:
		var height := TowerLook.stack_height(count)
		if height <= previous:
			return false
		previous = height
	return true


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
