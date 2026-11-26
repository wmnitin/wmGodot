extends RefCounted
class_name TowerCatalog

## Loads res://data/tower_types.json. Unknown ids fall back to the outpost
## so a typo in a level cannot crash the match.

const PATH := "res://data/tower_types.json"

var _types := {}


func _init() -> void:
	var parsed = null
	if FileAccess.file_exists(PATH):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("types")) == TYPE_DICTIONARY:
		for key in parsed["types"].keys():
			var raw = parsed["types"][key]
			if typeof(raw) == TYPE_DICTIONARY:
				_types[str(key)] = _normalize(str(key), raw)
	if not _types.has("outpost"):
		_types["outpost"] = _normalize("outpost", {})


func has_type(id: String) -> bool:
	return _types.has(id)


func get_type(id: String) -> Dictionary:
	if _types.has(id):
		return _types[id]
	return _types["outpost"]


func _normalize(id: String, raw: Dictionary) -> Dictionary:
	var params = raw.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	return {
		"id": id,
		"display_name": str(raw.get("display_name", id)),
		"category": str(raw.get("category", "tower")),
		"can_grow": bool(raw.get("can_grow", true)),
		"can_send": bool(raw.get("can_send", true)),
		"can_be_captured": bool(raw.get("can_be_captured", true)),
		"can_be_targeted": bool(raw.get("can_be_targeted", true)),
		"counts_for_victory": bool(raw.get("counts_for_victory", true)),
		"grows_while_sending": bool(raw.get("grows_while_sending", false)),
		"growth_scale": float(raw.get("growth_scale", 1.0)),
		"send_scale": float(raw.get("send_scale", 1.0)),
		"max_count": int(raw.get("max_count", BattleRules.MAX_COUNT)),
		"blocks_paths": bool(raw.get("blocks_paths", false)),
		"block_radius": float(raw.get("block_radius", 0.0)),
		"hazard_radius": float(raw.get("hazard_radius", 0.0)),
		"ability": str(raw.get("ability", "")),
		"params": params,
		"unit_power": maxi(1, int(raw.get("unit_power", 1))),
		"unit_speed": maxf(0.2, float(raw.get("unit_speed", 1.0))),
		"unit_kind": str(raw.get("unit_kind", "soldier")),
	}
