extends RefCounted
class_name EnemyAI

## A small greedy bot. Every reaction it either mistakes, cuts a bad link,
## or opens the best legal link. It uses the same try_connect / try_cut
## rules as the player, including the link cap.


func act(sim: MatchSim) -> void:
	if sim.rng.randf() < float(sim.ai_params.get("mistake_chance", 0.0)):
		_mistake(sim)
		return
	var best_score := 0.2
	var best: Dictionary = {}
	for tower in sim.towers_with_owner("enemy"):
		if not sim.can_send_tower(tower):
			continue
		var outs: Array = sim.outgoing(str(tower.id))
		var cap: int = sim.link_cap(tower)
		for link in outs:
			var cut_score := _cut_score(sim, tower, link)
			if cut_score > best_score:
				best_score = cut_score
				best = {"op": "cut", "id": int(link.id)}
		if outs.size() < cap:
			for target in sim.towers:
				if str(target.id) == str(tower.id):
					continue
				if sim.has_link(str(tower.id), str(target.id)):
					continue
				if not bool(sim.spec_of(target).can_be_targeted):
					continue
				var score := _connect_score(sim, tower, target)
				if not _worth_reversing(sim, tower, target, score):
					continue
				if score > best_score:
					best_score = score
					best = {"op": "connect", "source": str(tower.id), "target": str(target.id)}
		elif cap > 0 and not outs.is_empty():
			var worst = null
			var worst_score := 999.0
			for link in outs:
				var current = sim.tower(str(link.target_id))
				var value := _connect_score(sim, tower, current)
				if value < worst_score:
					worst_score = value
					worst = link
			if worst != null:
				for target in sim.towers:
					if sim.has_link(str(tower.id), str(target.id)):
						continue
					if not bool(sim.spec_of(target).can_be_targeted):
						continue
					var score := _connect_score(sim, tower, target)
					if not _worth_reversing(sim, tower, target, score):
						continue
					if score > worst_score + 0.35 and score > best_score:
						best_score = score
						best = {
							"op": "replace",
							"cut": int(worst.id),
							"source": str(tower.id),
							"target": str(target.id),
						}
	if best.is_empty():
		return
	if str(best.op) == "cut":
		sim.try_cut(int(best.id))
	elif str(best.op) == "connect":
		sim.try_connect(str(best.source), str(best.target))
	elif str(best.op) == "replace":
		sim.try_cut(int(best.cut))
		sim.try_connect(str(best.source), str(best.target))


## Don't flip a support link back and forth every reaction. A reverse still
## goes through try_connect, which keeps one direction and lets in-flight
## soldiers finish as support.
func _worth_reversing(sim: MatchSim, source: Dictionary, target: Dictionary, new_score: float) -> bool:
	if str(target.owner) != str(source.owner):
		return true
	if not sim.has_link(str(target.id), str(source.id)):
		return true
	var current_flow := _connect_score(sim, target, source)
	return new_score >= current_flow + 0.3


func _connect_score(sim: MatchSim, source: Dictionary, target: Dictionary) -> float:
	if target.is_empty():
		return -1.0
	var dist: float = sim.world_pos(str(source.id)).distance_to(sim.world_pos(str(target.id)))
	var near := 1.0 - clampf(dist / 1200.0, 0.0, 1.0)
	var weak := 1.0 - clampf(float(target.count) / 40.0, 0.0, 1.0)
	var owner := str(target.owner)
	if owner == "player":
		return 0.35 + weak * 0.9 + near * 0.55
	if owner == "neutral":
		return 0.30 + weak * 1.0 + near * 0.7
	if owner == "enemy":
		if int(target.count) >= 18:
			return -1.0
		return 0.05 + weak * 0.35 + near * 0.15
	return -1.0


func _cut_score(sim: MatchSim, source: Dictionary, link: Dictionary) -> float:
	var target = sim.tower(str(link.target_id))
	if str(target.owner) == "enemy" and int(target.count) >= 20:
		return 0.85
	var value := _connect_score(sim, source, target)
	if value < 0.25 and int(source.count) < 36:
		return 0.55
	return -1.0


func _mistake(sim: MatchSim) -> void:
	var owned: Array = sim.towers_with_owner("enemy")
	if owned.is_empty():
		return
	var source: Dictionary = owned[sim.rng.randi() % owned.size()]
	var outs: Array = sim.outgoing(str(source.id))
	if not outs.is_empty() and sim.rng.randf() < 0.5:
		var link: Dictionary = outs[sim.rng.randi() % outs.size()]
		sim.try_cut(int(link.id))
		return
	if outs.size() >= sim.link_cap(source):
		return
	if not sim.can_send_tower(source):
		return
	var options: Array = []
	for tower in sim.towers:
		if str(tower.id) == str(source.id):
			continue
		if sim.has_link(str(source.id), str(tower.id)):
			continue
		if not bool(sim.spec_of(tower).can_be_targeted):
			continue
		options.append(tower)
	if options.is_empty():
		return
	var target: Dictionary = options[sim.rng.randi() % options.size()]
	sim.try_connect(str(source.id), str(target.id))
