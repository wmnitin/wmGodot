extends RefCounted
class_name CapyModels

## Shared low-poly meshes. One mesh per kind, reused by every instance.
## Vertex colors carry the cute palette so each soldier is a single draw
## plus a separate sword that can swing.

const FUR := Color("C9843E")
const SNOUT := Color("F0C48A")
const NOSE := Color("5A3824")
const EYE := Color("241C18")
const EAR := Color("F4A6B8")
const METAL := Color("E7EDF5")
const HILT := Color("6B4428")
const TREAD := Color("2C3138")

var _cache := {}


func soldier_mesh(team: String) -> ArrayMesh:
	var key := "soldier_" + team
	if _cache.has(key):
		return _cache[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scarf := Palette.team(team)
	var fur_dark := FUR.darkened(0.12)
	_box(tool, Vector3(0, 0.2, 0), Vector3(0.46, 0.26, 0.52), FUR)
	_box(tool, Vector3(0, 0.38, 0.2), Vector3(0.3, 0.22, 0.26), FUR)
	_box(tool, Vector3(0, 0.33, 0.38), Vector3(0.18, 0.12, 0.16), SNOUT)
	_box(tool, Vector3(0, 0.34, 0.47), Vector3(0.07, 0.05, 0.04), NOSE)
	_box(tool, Vector3(-0.1, 0.52, 0.16), Vector3(0.08, 0.1, 0.07), FUR)
	_box(tool, Vector3(0.1, 0.52, 0.16), Vector3(0.08, 0.1, 0.07), FUR)
	_box(tool, Vector3(-0.1, 0.52, 0.19), Vector3(0.04, 0.05, 0.02), EAR)
	_box(tool, Vector3(0.1, 0.52, 0.19), Vector3(0.04, 0.05, 0.02), EAR)
	_box(tool, Vector3(-0.07, 0.4, 0.34), Vector3(0.055, 0.055, 0.03), EYE)
	_box(tool, Vector3(0.07, 0.4, 0.34), Vector3(0.055, 0.055, 0.03), EYE)
	_box(tool, Vector3(0, 0.3, 0.12), Vector3(0.34, 0.08, 0.1), scarf)
	_box(tool, Vector3(-0.13, 0.06, 0.14), Vector3(0.1, 0.12, 0.12), fur_dark)
	_box(tool, Vector3(0.13, 0.06, 0.14), Vector3(0.1, 0.12, 0.12), fur_dark)
	_box(tool, Vector3(-0.13, 0.06, -0.14), Vector3(0.1, 0.12, 0.12), fur_dark)
	_box(tool, Vector3(0.13, 0.06, -0.14), Vector3(0.1, 0.12, 0.12), fur_dark)
	var mesh := tool.commit()
	_cache[key] = mesh
	return mesh


func sword_mesh() -> ArrayMesh:
	if _cache.has("sword"):
		return _cache["sword"]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool, Vector3(0, 0.32, 0), Vector3(0.045, 0.58, 0.02), METAL)
	_box(tool, Vector3(0, 0.06, 0), Vector3(0.16, 0.045, 0.045), HILT)
	_box(tool, Vector3(0, -0.04, 0), Vector3(0.045, 0.14, 0.04), HILT)
	var mesh := tool.commit()
	_cache["sword"] = mesh
	return mesh


func tank_hull_mesh(team: String) -> ArrayMesh:
	var key := "hull_" + team
	if _cache.has(key):
		return _cache[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := Palette.team(team)
	_box(tool, Vector3(-0.32, 0.12, 0), Vector3(0.16, 0.2, 0.78), TREAD)
	_box(tool, Vector3(0.32, 0.12, 0), Vector3(0.16, 0.2, 0.78), TREAD)
	_box(tool, Vector3(0, 0.26, 0), Vector3(0.5, 0.18, 0.68), paint.darkened(0.18))
	_box(tool, Vector3(0, 0.38, -0.02), Vector3(0.38, 0.1, 0.42), paint)
	_box(tool, Vector3(0, 0.52, 0.02), Vector3(0.18, 0.14, 0.16), FUR)
	_box(tool, Vector3(0, 0.5, 0.14), Vector3(0.12, 0.08, 0.1), SNOUT)
	_box(tool, Vector3(-0.05, 0.56, 0.1), Vector3(0.04, 0.04, 0.03), EYE)
	_box(tool, Vector3(0.05, 0.56, 0.1), Vector3(0.04, 0.04, 0.03), EYE)
	var mesh := tool.commit()
	_cache[key] = mesh
	return mesh


func tank_turret_mesh(team: String) -> ArrayMesh:
	var key := "turret_" + team
	if _cache.has(key):
		return _cache[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := Palette.team(team)
	_box(tool, Vector3(0, 0.1, 0), Vector3(0.32, 0.16, 0.34), paint.darkened(0.05))
	_box(tool, Vector3(0, 0.1, 0.36), Vector3(0.08, 0.08, 0.46), METAL)
	var mesh := tool.commit()
	_cache[key] = mesh
	return mesh


func make_soldier(team: String) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = soldier_mesh(team)
	body.material_override = vertex_material()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var sword := Node3D.new()
	sword.name = "Sword"
	sword.position = Vector3(0.28, 0.34, 0.12)
	sword.rotation = Vector3(-0.5, 0.15, -0.85)
	var blade := MeshInstance3D.new()
	blade.mesh = sword_mesh()
	blade.material_override = vertex_material()
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sword.add_child(blade)
	root.add_child(sword)
	return root


func make_tank(team: String) -> Node3D:
	var root := Node3D.new()
	var hull := MeshInstance3D.new()
	hull.mesh = tank_hull_mesh(team)
	hull.material_override = vertex_material()
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hull)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 0.34, 0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = tank_turret_mesh(team)
	mesh.material_override = vertex_material()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	turret.add_child(mesh)
	root.add_child(turret)
	return root


func vertex_material() -> StandardMaterial3D:
	if _cache.has("vertex_mat"):
		return _cache["vertex_mat"]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.72
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["vertex_mat"] = mat
	return mat


func team_material(team: String) -> StandardMaterial3D:
	var key := "team_" + team
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.team(team)
	mat.roughness = 0.62
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = mat
	return mat


func floor_mesh() -> CylinderMesh:
	if _cache.has("floor"):
		return _cache["floor"]
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.78
	mesh.height = 1.0
	mesh.radial_segments = 8
	_cache["floor"] = mesh
	return mesh


func lip_mesh() -> CylinderMesh:
	if _cache.has("lip"):
		return _cache["lip"]
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.86
	mesh.bottom_radius = 0.86
	mesh.height = 0.1
	mesh.radial_segments = 8
	_cache["lip"] = mesh
	return mesh


func factory_mesh() -> BoxMesh:
	if _cache.has("factory"):
		return _cache["factory"]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.7, 1.0, 1.7)
	_cache["factory"] = mesh
	return mesh


func _box(tool: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var faces := [
		[Vector3(0, 1, 0), [Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz)]],
		[Vector3(0, -1, 0), [Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz)]],
		[Vector3(0, 0, 1), [Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, -hy, hz)]],
		[Vector3(0, 0, -1), [Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3(-hx, -hy, -hz)]],
		[Vector3(1, 0, 0), [Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(hx, -hy, -hz)]],
		[Vector3(-1, 0, 0), [Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(-hx, -hy, hz)]],
	]
	for face in faces:
		var normal: Vector3 = face[0]
		var corners: Array = face[1]
		_tri(tool, center + corners[0], center + corners[1], center + corners[2], normal, color)
		_tri(tool, center + corners[0], center + corners[2], center + corners[3], normal, color)


func _sphere(tool: SurfaceTool, center: Vector3, radius: float, color: Color, rings: int, segments: int) -> void:
	for lat in rings:
		for lon in segments:
			var p00 := _sphere_point(lat, lon, rings, segments, center, radius)
			var p10 := _sphere_point(lat + 1, lon, rings, segments, center, radius)
			var p11 := _sphere_point(lat + 1, lon + 1, rings, segments, center, radius)
			var p01 := _sphere_point(lat, lon + 1, rings, segments, center, radius)
			_tri(tool, p00, p10, p11, (p00 - center).normalized(), color)
			_tri(tool, p00, p11, p01, (p00 - center).normalized(), color)


func _sphere_point(lat: int, lon: int, rings: int, segments: int, center: Vector3, radius: float) -> Vector3:
	var v := float(lat) / float(rings)
	var u := float(lon) / float(segments)
	var phi := PI * v
	var theta := TAU * u
	return center + Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * radius


func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	tool.set_normal(normal)
	tool.set_color(color)
	tool.add_vertex(a)
	tool.set_normal(normal)
	tool.set_color(color)
	tool.add_vertex(b)
	tool.set_normal(normal)
	tool.set_color(color)
	tool.add_vertex(c)
