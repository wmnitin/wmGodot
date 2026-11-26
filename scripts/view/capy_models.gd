extends RefCounted
class_name CapyModels

## Bevelled boxes, not hard cubes and not cylinders. Shared meshes, one material
## per team, so the meadow stays cheap on a phone.

const FUR := Color("9C6B3F")
const SNOUT := Color("E8C49A")
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
var _kits: KitLibrary


func kits() -> KitLibrary:
	if _kits == null:
		_kits = KitLibrary.new()
	return _kits


func chamfer_mesh() -> ArrayMesh:
	if _cache.has("chamfer"):
		return _cache["chamfer"]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_emit_chamfer(tool, Vector3.ZERO, Vector3.ONE, 0.22, Color.WHITE)
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


func shade_material(team: String, darken: float) -> StandardMaterial3D:
	var key := "shade_%s_%s" % [team, darken]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.team(team).darkened(darken)
	mat.roughness = 0.8
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
	var team_color := Palette.team(team)
	var leg := FUR.darkened(0.12)
	# Barrel body, big blunt head (about half the silhouette), flat snout, no tail.
	_emit_chamfer(tool, Vector3(0, 0.16, -0.02), Vector3(0.5, 0.26, 0.52), 0.07, FUR)
	_emit_chamfer(tool, Vector3(0, 0.4, 0.2), Vector3(0.44, 0.3, 0.36), 0.06, FUR)
	_emit_chamfer(tool, Vector3(0, 0.34, 0.4), Vector3(0.32, 0.12, 0.16), 0.03, SNOUT)
	_emit_chamfer(tool, Vector3(0, 0.35, 0.49), Vector3(0.1, 0.06, 0.04), 0.01, NOSE)
	_emit_chamfer(tool, Vector3(-0.12, 0.58, 0.16), Vector3(0.08, 0.07, 0.06), 0.015, FUR)
	_emit_chamfer(tool, Vector3(0.12, 0.58, 0.16), Vector3(0.08, 0.07, 0.06), 0.015, FUR)
	_emit_chamfer(tool, Vector3(-0.1, 0.46, 0.36), Vector3(0.045, 0.04, 0.03), 0.008, EYE)
	_emit_chamfer(tool, Vector3(0.1, 0.46, 0.36), Vector3(0.045, 0.04, 0.03), 0.008, EYE)
	_emit_chamfer(tool, Vector3(0, 0.56, 0.18), Vector3(0.36, 0.08, 0.28), 0.02, team_color)
	_emit_chamfer(tool, Vector3(0, 0.24, 0.08), Vector3(0.52, 0.1, 0.28), 0.02, team_color)
	_emit_chamfer(tool, Vector3(-0.14, 0.04, 0.1), Vector3(0.1, 0.08, 0.1), 0.02, leg)
	_emit_chamfer(tool, Vector3(0.14, 0.04, 0.1), Vector3(0.1, 0.08, 0.1), 0.02, leg)
	_emit_chamfer(tool, Vector3(-0.14, 0.04, -0.14), Vector3(0.1, 0.08, 0.1), 0.02, leg)
	_emit_chamfer(tool, Vector3(0.14, 0.04, -0.14), Vector3(0.1, 0.08, 0.1), 0.02, leg)
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
	var body := kits().grounded(KitLibrary.CC0 + "capybara.glb")
	var size: Vector3 = body.get_meta("size")
	var fit := 0.92 / maxf(maxf(size.x, size.z), 0.001)
	body.scale = Vector3.ONE * fit
	root.add_child(body)
	var worn := Palette.team(team)
	var helmet := kits().grounded(KitLibrary.QUATERNIUS + "Helmet1.glb")
	var helm_size: Vector3 = helmet.get_meta("size")
	helmet.scale = Vector3.ONE * (0.18 / maxf(helm_size.y, 0.001))
	helmet.position = Vector3(0, size.y * fit * 0.62, size.z * fit * 0.36)
	kits().tint(helmet, worn, 0.88)
	root.add_child(helmet)
	var vest := kits().grounded(KitLibrary.QUATERNIUS + "ShoulderPads.glb")
	var vest_size: Vector3 = vest.get_meta("size")
	vest.scale = Vector3(0.46 / maxf(vest_size.x, 0.001), 0.12 / maxf(vest_size.y, 0.001), 0.22 / maxf(vest_size.z, 0.001))
	vest.position = Vector3(0, size.y * fit * 0.55, size.z * fit * 0.08)
	kits().tint(vest, worn, 0.92)
	root.add_child(vest)
	var sword := Node3D.new()
	sword.name = "Sword"
	sword.position = Vector3(size.x * fit * 0.55, size.y * fit * 0.38, size.z * fit * 0.22)
	var blade := kits().grounded(KitLibrary.QUATERNIUS + "Sword.glb")
	var blade_size: Vector3 = blade.get_meta("size")
	var long_axis := blade_size.y
	if blade_size.x >= blade_size.y and blade_size.x >= blade_size.z:
		blade.rotation_degrees = Vector3(0, 0, 90)
		long_axis = blade_size.x
	elif blade_size.z >= blade_size.y:
		blade.rotation_degrees = Vector3(-90, 0, 0)
		long_axis = blade_size.z
	blade.scale = Vector3.ONE * (0.5 / maxf(long_axis, 0.001))
	sword.add_child(blade)
	root.add_child(sword)
	return root


func make_tank(team: String) -> Node3D:
	var root := Node3D.new()
	var model := kits().spawn(KitLibrary.QUATERNIUS + "Tank.glb")
	var aim := Vector3.FORWARD
	var gun := model.find_child("Tank_Gun", true, false) as Node3D
	var hull := model.find_child("Tank_body", true, false) as Node3D
	if gun != null and hull != null:
		aim = _point_in(model, gun) - _point_in(model, hull)
	_rig_tank_turret(model)
	aim.y = 0.0
	if aim.length_squared() > 0.0001:
		model.rotation.y = -atan2(aim.x, aim.z)
	var paint := Palette.team(team)
	for part_name in ["Tank_body", "Tank_Turret", "Tank_Gun"]:
		var part := model.find_child(part_name, true, false)
		if part != null:
			kits().tint(part, paint, 0.72)
	root.add_child(model)
	var box := _tree_bounds(model)
	var length := maxf(box.size.x, box.size.z)
	var fit := 1.45 / maxf(length, 0.001)
	model.scale = Vector3.ONE * fit
	model.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z) * fit
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		var clip := ""
		for anim_name in player.get_animation_list():
			if "Forward" in str(anim_name):
				clip = str(anim_name)
				break
		if clip != "":
			player.play(clip)
	for i in 2:
		var puff := MeshInstance3D.new()
		puff.name = "Exhaust%d" % i
		var ball := SphereMesh.new()
		ball.radius = 0.08
		ball.height = 0.16
		ball.radial_segments = 8
		ball.rings = 3
		puff.mesh = ball
		var smoke := StandardMaterial3D.new()
		smoke.albedo_color = Color(0.75, 0.78, 0.8, 0.55)
		smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material_override = smoke
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.visible = false
		root.add_child(puff)
	return root


func _rig_tank_turret(model: Node3D) -> void:
	var turret_mesh := model.find_child("Tank_Turret", true, false) as Node3D
	var pivot := Node3D.new()
	pivot.name = "Turret"
	if turret_mesh == null:
		model.add_child(pivot)
		return
	var parent := turret_mesh.get_parent()
	parent.add_child(pivot)
	var pivot_xf := Transform3D(Basis.IDENTITY, turret_mesh.position)
	pivot.transform = pivot_xf
	_keep_under(turret_mesh, pivot, pivot_xf)
	var gun := model.find_child("Tank_Gun", true, false) as Node3D
	if gun != null and gun.get_parent() == parent:
		_keep_under(gun, pivot, pivot_xf)


func _keep_under(node: Node3D, pivot: Node3D, pivot_xf: Transform3D) -> void:
	var old := node.transform
	node.owner = null
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	# The imported tank scene owns these meshes. Clearing owner avoids the
	# "owner Root Scene inconsistent" warning when they move under Turret.
	node.owner = null
	pivot.add_child(node)
	node.transform = pivot_xf.affine_inverse() * old


func _tree_bounds(node: Node3D) -> AABB:
	return kits()._bounds(node, Transform3D.IDENTITY)


func _point_in(root: Node3D, node: Node3D) -> Vector3:
	var xf := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor is Node3D and cursor != root:
		xf = (cursor as Node3D).transform * xf
		cursor = cursor.get_parent()
	return xf.origin


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
