extends RefCounted
class_name KitLibrary

## Loads CC0 glTF scenes, sits them on the ground, and tints team pieces
## without throwing away the atlas.

const CASTLE := "res://assets/models/kenney/castle/"
const SURVIVAL := "res://assets/models/kenney/survival/"
const NATURE := "res://assets/models/kenney/nature/"
const BLASTER := "res://assets/models/kenney/blaster/"
const CAR := "res://assets/models/kenney/car/"
const SPACE := "res://assets/models/kenney/space/"
const DEFENSE := "res://assets/models/kenney/tower-defense/"
const QUATERNIUS := "res://assets/models/quaternius/"
const CC0 := "res://assets/models/cc0/"

var _packed := {}


func grounded(path: String) -> Node3D:
	var wrap := Node3D.new()
	var model := spawn(path)
	wrap.add_child(model)
	var box := _bounds(model, Transform3D.IDENTITY)
	var center := box.get_center()
	model.position = Vector3(-center.x, -box.position.y, -center.z)
	var fitted := _bounds(model, Transform3D.IDENTITY)
	wrap.set_meta("size", fitted.size)
	wrap.set_meta("height", fitted.size.y)
	return wrap


func spawn(path: String) -> Node3D:
	var packed := _load_scene(path)
	var node := packed.instantiate() as Node3D
	if node == null:
		node = Node3D.new()
	_shadows(node, true)
	return node


func tint(node: Node, color: Color, strength: float = 0.8) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var source: Material = mesh.surface_get_material(surface)
				var mat := StandardMaterial3D.new()
				mat.roughness = 0.78
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				if source is StandardMaterial3D:
					var painted := source as StandardMaterial3D
					mat.albedo_texture = painted.albedo_texture
					mat.vertex_color_use_as_albedo = painted.vertex_color_use_as_albedo
					mat.albedo_color = painted.albedo_color.lerp(color, strength)
					mat.roughness = painted.roughness
					mat.texture_filter = painted.texture_filter
				else:
					mat.albedo_color = color
				mesh_node.set_surface_override_material(surface, mat)
	for child in node.get_children():
		tint(child, color, strength)


func _load_scene(path: String) -> PackedScene:
	if _packed.has(path):
		return _packed[path]
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Missing model %s" % path)
		packed = PackedScene.new()
	_packed[path] = packed
	return packed


func _bounds(node: Node, parent: Transform3D) -> AABB:
	var box := AABB()
	var started := false
	if node is Node3D:
		var here := parent * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			box = here * (node as MeshInstance3D).mesh.get_aabb()
			started = true
		for child in node.get_children():
			var next := _bounds(child, here)
			if next.size.length_squared() <= 0.0 and next.position == Vector3.ZERO:
				continue
			if not started:
				box = next
				started = true
			else:
				box = box.merge(next)
	return box


func _shadows(node: Node, on: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_shadows(child, on)
