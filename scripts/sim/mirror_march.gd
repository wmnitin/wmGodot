extends RefCounted
class_name MirrorMarch

## Deterministic player policy used only by the headless winnability check.
## It is not the opponent. It grabs nearby neutral outposts, then attacks.

var _accum := 0.0
const INTERVAL := 0.45


func consider(sim: MatchSim, delta: float) -> void:
	_accum += delta
	if _accum < INTERVAL:
		return
	_accum = 0.0
	if str(sim.state) != "playing":
		return
	_cut(sim)
	_link(sim)


func _cut(sim: MatchSim) -> void:
	for link in sim.links.duplicate():
		if str(link.owner) != "player":
			continue
		var source = sim.tower(str(link.source_id))
		var target = sim.tower(str(link.target_id))
		if source.is_empty() or target.is_empty():
			continue
		if str(target.owner) == "player" and int(target.count) >= 8 and not _under_attack(sim, str(target.id)):
			sim.try_cut(int(link.id))
			continue
		if str(target.owner) == "enemy" and int(source.count) < 8 and int(target.count) > int(source.count) + 6:
			sim.try_cut(int(link.id))


func _link(sim: MatchSim) -> void:
	var owned: Array = sim.towers_with_owner("player")
	owned.sort_custom(func(a, b): return int(a.count) > int(b.count))
	for source in owned:
		if not sim.can_send_tower(source):
			continue
		if sim.outgoing(str(source.id)).size() >= sim.link_cap(source):
			continue
		if int(source.count) < 8:
			continue
		var target = _pick(sim, source)
		if target != null:
			sim.try_connect(str(source.id), str(target.id))


func _pick(sim: MatchSim, source: Dictionary):
	var neutrals_left := false
	for tower in sim.towers:
		if str(tower.owner) == "neutral" and bool(sim.spec_of(tower).can_be_targeted):
			neutrals_left = true
			break
	var best = null
	var best_score := -1.0e9
	for tower in sim.towers:
		if str(tower.id) == str(source.id):
			continue
		if sim.has_link(str(source.id), str(tower.id)):
			continue
		if not bool(sim.spec_of(tower).can_be_targeted):
			continue
		if sim.path_blocked(str(source.id), str(tower.id)):
			continue
		var dist: float = sim.world_pos(str(source.id)).distance_to(sim.world_pos(str(tower.id)))
		var score := -1.0e9
		if str(tower.owner) == "neutral":
			score = 2000.0 - float(tower.count) * 25.0 - dist * 0.35
		elif str(tower.owner) == "enemy" and not neutrals_left and int(source.count) >= 8:
			var focus := 0.0
			for link in sim.links:
				if str(link.owner) == "player" and str(link.target_id) == str(tower.id):
					focus = 280.0
			score = 900.0 - float(tower.count) * 18.0 - dist * 0.2 + focus
		elif str(tower.owner) == "player" and int(tower.count) < 8 and int(source.count) >= 22:
			score = 380.0 - dist * 0.2
		if score > best_score:
			best_score = score
			best = tower
	if best == null or best_score < 0.0:
		return null
	return best


func _under_attack(sim: MatchSim, tower_id: String) -> bool:
	for link in sim.links:
		if str(link.target_id) == tower_id and str(link.owner) == "enemy":
			return true
	for soldier in sim.soldiers:
		if bool(soldier.dead):
			continue
		if str(soldier.target_id) == tower_id and str(soldier.team) == "enemy":
			return true
	return false
