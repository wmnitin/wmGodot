extends RefCounted
class_name Abilities

## Extension point for special structures.
## Outposts have an empty ability. Factory growth is the type's growth_scale.
## Add a match arm here when a new structure needs behaviour the flags cannot express.


static func tick(sim: MatchSim, delta: float) -> void:
	for tower in sim.towers:
		var spec: Dictionary = sim.spec_of(tower)
		var ability := str(spec.get("ability", ""))
		if ability == "artillery":
			_artillery(sim, tower, spec, delta)


static func _artillery(sim: MatchSim, tower: Dictionary, spec: Dictionary, delta: float) -> void:
	var owner := str(tower.owner)
	if owner != "player" and owner != "enemy":
		return
	var params: Dictionary = spec.get("params", {})
	var interval := float(params.get("interval", 3.5))
	var reach := float(params.get("range", 420.0))
	var damage := int(params.get("damage", 2))
	tower.ability_accum = float(tower.ability_accum) + delta
	if float(tower.ability_accum) < interval:
		return
	if int(tower.count) <= 0:
		return
	var target: String = sim.nearest_opponent_id(str(tower.id), reach)
	if target == "":
		# Hold the shot ready so it fires on the first valid target, then waits a full interval.
		tower.ability_accum = interval
		return
	tower.ability_accum = float(tower.ability_accum) - interval
	if not sim.spend_count(str(tower.id), 1):
		return
	for _i in damage:
		sim.apply_hit(target, owner)
	sim.stats["shots"] = int(sim.stats["shots"]) + 1
