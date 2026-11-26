extends RefCounted
class_name BunkerMesh

## Chunky rounded bunkers. One shared mesh per size, team colour comes from
## the material. Vertex colour is a soft AO, darker toward the ground.

const BAND := Color("F4F7FB")
const SLIT := Color("243044")
const FRAME := Color("F7F8FA")
const FLAG := Color("F5B72F")
const CHIMNEY := Color("8D939C")

var _cache := {}


func body(size: Vector3, radius: float) -> ArrayMesh:
	return _box("body_%s_%s" % [size, radius], size, radius, true)


func band(size: Vector3) -> ArrayMesh:
	return _box("band_%s" % size, size, minf(size.y * 0.45, 0.08), false)


func cap(size: Vector3) -> ArrayMesh:
	return _box("cap_%s" % size, size, minf(size.y * 0.65, 0.1), true)


func slit(size: Vector3) -> ArrayMesh:
	return _box("slit_%s" % size, size, minf(size.y, size.x) * 0.35, false)


func door(size: Vector3) -> ArrayMesh:
	return _box("door_%s" % size, size, size.x * 0.48, false)


func chimney(size: Vector3) -> ArrayMesh:
	return _box("chim_%s" % size, size, minf(size.x, size.z) * 0.45, false)


func team_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = true
	return mat


func flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = true
	return mat


func _box(key: String, size: Vector3, radius: float, shade: bool) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var used := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.92)
	var steps := 6
	_face(tool, half, used, steps, 0, 1.0, shade)
	_face(tool, half, used, steps, 0, -1.0, shade)
	_face(tool, half, used, steps, 1, 1.0, shade)
	_face(tool, half, used, steps, 1, -1.0, shade)
	_face(tool, half, used, steps, 2, 1.0, shade)
	_face(tool, half, used, steps, 2, -1.0, shade)
	var mesh := tool.commit()
	_cache[key] = mesh
	return mesh


func _face(tool: SurfaceTool, half: Vector3, radius: float, steps: int, axis: int, sign: float, shade: bool) -> void:
	var grid: Array = []
	var norms: Array = []
	var cols: Array = []
	for y in steps + 1:
		var row: Array = []
		var nrow: Array = []
		var crow: Array = []
		var v := float(y) / float(steps)
		for x in steps + 1:
			var u := float(x) / float(steps)
			var on_face := _on_face(half, u, v, axis, sign)
			var rounded := _round_point(on_face, half, radius)
			var nrm := _round_normal(on_face, half, radius)
			var ao := 1.0
			if shade:
				var height := (rounded.y + half.y) / maxf(size_y(half), 0.001)
				ao = lerpf(0.74, 1.0, clampf(height, 0.0, 1.0))
			row.append(rounded)
			nrow.append(nrm)
			crow.append(Color(ao, ao, ao))
		grid.append(row)
		norms.append(nrow)
		cols.append(crow)
	for y in steps:
		for x in steps:
			var a: Vector3 = grid[y][x]
			var b: Vector3 = grid[y][x + 1]
			var c: Vector3 = grid[y + 1][x + 1]
			var d: Vector3 = grid[y + 1][x]
			var na: Vector3 = norms[y][x]
			var nb: Vector3 = norms[y][x + 1]
			var nc: Vector3 = norms[y + 1][x + 1]
			var nd: Vector3 = norms[y + 1][x]
			var ca: Color = cols[y][x]
			var cb: Color = cols[y][x + 1]
			var cc: Color = cols[y + 1][x + 1]
			var cd: Color = cols[y + 1][x]
			if sign > 0.0:
				_tri(tool, a, b, c, na, nb, nc, ca, cb, cc)
				_tri(tool, a, c, d, na, nc, nd, ca, cc, cd)
			else:
				_tri(tool, a, c, b, na, nc, nb, ca, cc, cb)
				_tri(tool, a, d, c, na, nd, nc, ca, cd, cc)


func _on_face(half: Vector3, u: float, v: float, axis: int, sign: float) -> Vector3:
	var a := lerpf(-1.0, 1.0, u)
	var b := lerpf(-1.0, 1.0, v)
	if axis == 0:
		return Vector3(sign * half.x, b * half.y, a * half.z)
	if axis == 1:
		return Vector3(a * half.x, sign * half.y, b * half.z)
	return Vector3(a * half.x, b * half.y, sign * half.z)


func _round_point(point: Vector3, half: Vector3, radius: float) -> Vector3:
	var inner := half - Vector3.ONE * radius
	var ax := absf(point.x)
	var ay := absf(point.y)
	var az := absf(point.z)
	var outside := Vector3(maxf(ax - inner.x, 0.0), maxf(ay - inner.y, 0.0), maxf(az - inner.z, 0.0))
	if outside.length() > 0.0001:
		outside = outside.normalized() * radius
	return Vector3(
		signf(point.x) * (minf(ax, inner.x) + outside.x),
		signf(point.y) * (minf(ay, inner.y) + outside.y),
		signf(point.z) * (minf(az, inner.z) + outside.z)
	)


func _round_normal(point: Vector3, half: Vector3, radius: float) -> Vector3:
	var inner := half - Vector3.ONE * radius
	var raw := Vector3(
		signf(point.x) * maxf(absf(point.x) - inner.x, 0.0),
		signf(point.y) * maxf(absf(point.y) - inner.y, 0.0),
		signf(point.z) * maxf(absf(point.z) - inner.z, 0.0)
	)
	if raw.length() < 0.0001:
		return Vector3.UP
	return raw.normalized()


func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	tool.set_normal(na)
	tool.set_color(ca)
	tool.add_vertex(a)
	tool.set_normal(nb)
	tool.set_color(cb)
	tool.add_vertex(b)
	tool.set_normal(nc)
	tool.set_color(cc)
	tool.add_vertex(c)


func size_y(half: Vector3) -> float:
	return half.y * 2.0
