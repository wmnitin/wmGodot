extends RefCounted
class_name CapyModels

## Bevelled boxes, not hard cubes and not cylinders. Shared meshes, one material
## per team, so the meadow stays cheap on a phone.

const FUR := Color("E39A4A")
const SNOUT := Color("F6D7A8")
const NOSE := Color("3A2A22")
const EYE := Color("241C18")
const EAR := Color("F4A6B8")
const METAL := Color("F4F7FB")
const HILT := Color("6B4428")
const TREAD := Color("2A3038")
const BAND := Color("F3F6FA")
const SLIT := Color("243044")
const PINE_DARK := Color("1F8A45")
const PINE := Color("2EAA55")
const PINE_TIP := Color("7ED96A")

var _cache := {}


func chamfer_mesh() -> ArrayMesh:
	if _cache.has("chamfer"):
		return _cache["chamfer"]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_emit_chamfer(tool, Vector3.ZERO, Vector3.ONE, 0.16, Color.WHITE)
	var mesh := tool.commit()
	_cache["chamfer"] = mesh
	return mesh


func team_material(team: String) -> StandardMaterial3D:
	var key := "team_" + team
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.team(team)
	mat.roughness = 0.72
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = mat
	return mat


func flat_material(color: Color, rough: float = 0.7) -> StandardMaterial3D:
	var key := "flat_%s_%s" % [color, rough]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = mat
	return mat


func vertex_material() -> StandardMaterial3D:
	if _cache.has("vertex_mat"):
		return _cache["vertex_mat"]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["vertex_mat"] = mat
	return mat


func soldier_mesh(team: String) -> ArrayMesh:
	var key := "soldier_" + team
	if _cache.has(key):
		return _cache[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scarf := Palette.team(team)
	var dark := FUR.darkened(0.08)
	# Big head, short legs, bevelled body. The sword is a separate small node.
	_emit_chamfer(tool, Vector3(0, 0.16, 0), Vector3(0.42, 0.22, 0.34), 0.05, FUR)
	_emit_chamfer(tool, Vector3(0, 0.34, 0.1), Vector3(0.34, 0.26, 0.3), 0.05, FUR)
	_emit_chamfer(tool, Vector3(0, 0.3, 0.26), Vector3(0.16, 0.1, 0.12), 0.025, SNOUT)
	_emit_chamfer(tool, Vector3(0, 0.31, 0.33), Vector3(0.06, 0.045, 0.04), 0.01, NOSE)
	_emit_chamfer(tool, Vector3(-0.1, 0.5, 0.08), Vector3(0.07, 0.08, 0.06), 0.015, FUR)
	_emit_chamfer(tool, Vector3(0.1, 0.5, 0.08), Vector3(0.07, 0.08, 0.06), 0.015, FUR)
	_emit_chamfer(tool, Vector3(-0.1, 0.5, 0.1), Vector3(0.035, 0.04, 0.02), 0.006, EAR)
	_emit_chamfer(tool, Vector3(0.1, 0.5, 0.1), Vector3(0.035, 0.04, 0.02), 0.006, EAR)
	_emit_chamfer(tool, Vector3(-0.07, 0.36, 0.24), Vector3(0.045, 0.045, 0.03), 0.008, EYE)
	_emit_chamfer(tool, Vector3(0.07, 0.36, 0.24), Vector3(0.045, 0.045, 0.03), 0.008, EYE)
	_emit_chamfer(tool, Vector3(0, 0.28, 0.08), Vector3(0.3, 0.07, 0.16), 0.015, scarf)
	_emit_chamfer(tool, Vector3(-0.1, 0.045, 0.08), Vector3(0.08, 0.09, 0.08), 0.015, dark)
	_emit_chamfer(tool, Vector3(0.1, 0.045, 0.08), Vector3(0.08, 0.09, 0.08), 0.015, dark)
	_emit_chamfer(tool, Vector3(-0.1, 0.04, -0.08), Vector3(0.08, 0.08, 0.08), 0.015, dark)
	_emit_chamfer(tool, Vector3(0.1, 0.04, -0.08), Vector3(0.08, 0.08, 0.08), 0.015, dark)
	var mesh := tool.commit()
	_cache[key] = mesh
	return mesh


func sword_mesh() -> ArrayMesh:
	if _cache.has("sword"):
		return _cache["sword"]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_emit_chamfer(tool, Vector3(0, 0.16, 0), Vector3(0.03, 0.28, 0.012), 0.004, METAL)
	_emit_chamfer(tool, Vector3(0, 0.035, 0), Vector3(0.09, 0.025, 0.02), 0.004, HILT)
	_emit_chamfer(tool, Vector3(0, -0.01, 0), Vector3(0.028, 0.07, 0.02), 0.004, HILT)
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
	_emit_chamfer(tool, Vector3(-0.28, 0.1, 0), Vector3(0.14, 0.16, 0.62), 0.03, TREAD)
	_emit_chamfer(tool, Vector3(0.28, 0.1, 0), Vector3(0.14, 0.16, 0.62), 0.03, TREAD)
	_emit_chamfer(tool, Vector3(0, 0.2, 0), Vector3(0.42, 0.16, 0.5), 0.04, paint.darkened(0.12))
	_emit_chamfer(tool, Vector3(0, 0.3, -0.02), Vector3(0.32, 0.08, 0.34), 0.025, paint)
	_emit_chamfer(tool, Vector3(0, 0.4, 0.02), Vector3(0.16, 0.12, 0.14), 0.02, FUR)
	_emit_chamfer(tool, Vector3(0, 0.38, 0.12), Vector3(0.1, 0.07, 0.08), 0.015, SNOUT)
	_emit_chamfer(tool, Vector3(-0.035, 0.44, 0.08), Vector3(0.03, 0.03, 0.02), 0.005, EYE)
	_emit_chamfer(tool, Vector3(0.035, 0.44, 0.08), Vector3(0.03, 0.03, 0.02), 0.005, EYE)
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
	_emit_chamfer(tool, Vector3(0, 0.08, 0), Vector3(0.26, 0.14, 0.26), 0.03, paint)
	_emit_chamfer(tool, Vector3(0, 0.08, 0.26), Vector3(0.06, 0.06, 0.32), 0.012, METAL)
	var mesh := tool.commit()
	_cache[key] = mesh
	return mesh


func pine_mesh() -> ArrayMesh:
	if _cache.has("pine"):
		return _cache["pine"]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_emit_cone(tool, Vector3(0, 0.55, 0), 0.34, 0.55, PINE_DARK)
	_emit_cone(tool, Vector3(0, 0.95, 0), 0.26, 0.48, PINE)
	_emit_cone(tool, Vector3(0, 1.28, 0), 0.16, 0.38, PINE_TIP)
	_emit_chamfer(tool, Vector3(0, 0.16, 0), Vector3(0.08, 0.32, 0.08), 0.015, Color("6B4428"))
	var mesh := tool.commit()
	_cache["pine"] = mesh
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
	sword.position = Vector3(0.2, 0.22, 0.08)
	sword.rotation = Vector3(-0.4, 0.2, -0.9)
	sword.scale = Vector3(0.55, 0.55, 0.55)
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
	turret.position = Vector3(0, 0.32, 0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = tank_turret_mesh(team)
	mesh.material_override = vertex_material()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	turret.add_child(mesh)
	root.add_child(turret)
	return root


func _emit_chamfer(tool: SurfaceTool, center: Vector3, size: Vector3, bevel: float, color: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var c := minf(bevel, minf(hx, minf(hy, hz)) * 0.45)
	var ix := hx - c
	var iy := hy - c
	var iz := hz - c
	# Six faces. Winding matches the outward side used by the old box helper.
	_quad(tool, _at(center, -ix, hy, -iz), _at(center, ix, hy, -iz), _at(center, ix, hy, iz), _at(center, -ix, hy, iz), color, Vector3.UP)
	_quad(tool, _at(center, -ix, -hy, iz), _at(center, ix, -hy, iz), _at(center, ix, -hy, -iz), _at(center, -ix, -hy, -iz), color, Vector3.DOWN)
	_quad(tool, _at(center, -ix, -iy, hz), _at(center, -ix, iy, hz), _at(center, ix, iy, hz), _at(center, ix, -iy, hz), color, Vector3(0, 0, 1))
	_quad(tool, _at(center, ix, -iy, -hz), _at(center, ix, iy, -hz), _at(center, -ix, iy, -hz), _at(center, -ix, -iy, -hz), color, Vector3(0, 0, -1))
	_quad(tool, _at(center, hx, -iy, iz), _at(center, hx, iy, iz), _at(center, hx, iy, -iz), _at(center, hx, -iy, -iz), color, Vector3(1, 0, 0))
	_quad(tool, _at(center, -hx, -iy, -iz), _at(center, -hx, iy, -iz), _at(center, -hx, iy, iz), _at(center, -hx, -iy, iz), color, Vector3(-1, 0, 0))
	# Twelve edge bevels. Each joins one extreme edge to the inset face.
	_bevel(tool, _at(center, -ix, hy, iz), _at(center, ix, hy, iz), _at(center, ix, iy, hz), _at(center, -ix, iy, hz), color)
	_bevel(tool, _at(center, ix, hy, -iz), _at(center, -ix, hy, -iz), _at(center, -ix, iy, -hz), _at(center, ix, iy, -hz), color)
	_bevel(tool, _at(center, -ix, -hy, -iz), _at(center, ix, -hy, -iz), _at(center, ix, -iy, -hz), _at(center, -ix, -iy, -hz), color)
	_bevel(tool, _at(center, ix, -hy, iz), _at(center, -ix, -hy, iz), _at(center, -ix, -iy, hz), _at(center, ix, -iy, hz), color)
	_bevel(tool, _at(center, ix, hy, iz), _at(center, ix, hy, -iz), _at(center, hx, iy, -iz), _at(center, hx, iy, iz), color)
	_bevel(tool, _at(center, -ix, hy, -iz), _at(center, -ix, hy, iz), _at(center, -hx, iy, iz), _at(center, -hx, iy, -iz), color)
	_bevel(tool, _at(center, ix, -hy, -iz), _at(center, ix, -hy, iz), _at(center, hx, -iy, iz), _at(center, hx, -iy, -iz), color)
	_bevel(tool, _at(center, -ix, -hy, iz), _at(center, -ix, -hy, -iz), _at(center, -hx, -iy, -iz), _at(center, -hx, -iy, iz), color)
	_bevel(tool, _at(center, ix, iy, hz), _at(center, -ix, iy, hz), _at(center, -ix, -iy, hz), _at(center, ix, -iy, hz), color)
	_bevel(tool, _at(center, -ix, iy, -hz), _at(center, ix, iy, -hz), _at(center, ix, -iy, -hz), _at(center, -ix, -iy, -hz), color)
	_bevel(tool, _at(center, hx, iy, -iz), _at(center, hx, iy, iz), _at(center, hx, -iy, iz), _at(center, hx, -iy, -iz), color)
	_bevel(tool, _at(center, -hx, iy, iz), _at(center, -hx, iy, -iz), _at(center, -hx, -iy, -iz), _at(center, -hx, -iy, iz), color)
	# Eight corner triangles, where the three bevels meet.
	for sx_i in [-1, 1]:
		for sy_i in [-1, 1]:
			for sz_i in [-1, 1]:
				var sx := float(sx_i)
				var sy := float(sy_i)
				var sz := float(sz_i)
				var corner_a := _at(center, sx * ix, sy * hy, sz * iz)
				var corner_b := _at(center, sx * ix, sy * iy, sz * hz)
				var corner_c := _at(center, sx * hx, sy * iy, sz * iz)
				var outward := Vector3(sx, sy, sz)
				var facing := (corner_b - corner_a).cross(corner_c - corner_a)
				if facing.dot(outward) < 0.0:
					_tri(tool, corner_a, corner_c, corner_b, -facing.normalized(), color)
				else:
					_tri(tool, corner_a, corner_b, corner_c, facing.normalized(), color)
	_emit_solid_box(tool, center, size * 0.82, color)


func _emit_solid_box(tool: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	_quad(tool, _at(center, -hx, hy, -hz), _at(center, hx, hy, -hz), _at(center, hx, hy, hz), _at(center, -hx, hy, hz), color, Vector3.UP)
	_quad(tool, _at(center, -hx, -hy, hz), _at(center, hx, -hy, hz), _at(center, hx, -hy, -hz), _at(center, -hx, -hy, -hz), color, Vector3.DOWN)
	_quad(tool, _at(center, -hx, -hy, hz), _at(center, -hx, hy, hz), _at(center, hx, hy, hz), _at(center, hx, -hy, hz), color, Vector3(0, 0, 1))
	_quad(tool, _at(center, hx, -hy, -hz), _at(center, hx, hy, -hz), _at(center, -hx, hy, -hz), _at(center, -hx, -hy, -hz), color, Vector3(0, 0, -1))
	_quad(tool, _at(center, hx, -hy, hz), _at(center, hx, hy, hz), _at(center, hx, hy, -hz), _at(center, hx, -hy, -hz), color, Vector3(1, 0, 0))
	_quad(tool, _at(center, -hx, -hy, -hz), _at(center, -hx, hy, -hz), _at(center, -hx, hy, hz), _at(center, -hx, -hy, hz), color, Vector3(-1, 0, 0))


func _emit_cone(tool: SurfaceTool, center: Vector3, radius: float, height: float, color: Color) -> void:
	var sides := 12
	var tip := center + Vector3(0, height * 0.5, 0)
	var base_y := center.y - height * 0.5
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := Vector3(cos(a0) * radius, base_y, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, base_y, sin(a1) * radius)
		var normal := ((p0 + p1) * 0.5 - Vector3(center.x, base_y, center.z) + Vector3(0, radius, 0)).normalized()
		_tri(tool, tip, p1, p0, normal, color)
		_tri(tool, Vector3(center.x, base_y, center.z), p0, p1, Vector3.DOWN, color)


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, normal: Vector3) -> void:
	_tri(tool, a, b, c, normal, color)
	_tri(tool, a, c, d, normal, color)


func _bevel(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var normal := (b - a).cross(d - a).normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	_tri(tool, a, b, c, normal, color)
	_tri(tool, a, c, d, normal, color)


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


func _at(center: Vector3, x: float, y: float, z: float) -> Vector3:
	return center + Vector3(x, y, z)
