extends RefCounted
class_name Geom

## Small geometry helpers shared by the match (blockades) and the swipe gesture.


static func segments_near(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2, slack: float) -> bool:
	if _proper_intersect(a1, a2, b1, b2):
		return true
	return point_segment_distance(a1, b1, b2) <= slack \
		or point_segment_distance(a2, b1, b2) <= slack \
		or point_segment_distance(b1, a1, a2) <= slack \
		or point_segment_distance(b2, a1, a2) <= slack


static func point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / len2, 0.0, 1.0)
	return point.distance_to(a + ab * t)


static func _proper_intersect(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var o1 := _orient(a1, a2, b1)
	var o2 := _orient(a1, a2, b2)
	var o3 := _orient(b1, b2, a1)
	var o4 := _orient(b1, b2, a2)
	return o1 * o2 < 0.0 and o3 * o4 < 0.0


static func _orient(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


static func segment_segment_distance(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> float:
	if _proper_intersect(a1, a2, b1, b2):
		return 0.0
	return minf(
		minf(point_segment_distance(a1, b1, b2), point_segment_distance(a2, b1, b2)),
		minf(point_segment_distance(b1, a1, a2), point_segment_distance(b2, a1, a2))
	)


## Distance from a segment to an axis-aligned box. Zero when the segment touches it.
static func segment_aabb_distance(a: Vector2, b: Vector2, center: Vector2, half: Vector2) -> float:
	var mn := center - half
	var mx := center + half
	if _segment_hits_aabb(a, b, mn, mx):
		return 0.0
	var corners: Array[Vector2] = [
		mn,
		Vector2(mx.x, mn.y),
		mx,
		Vector2(mn.x, mx.y),
	]
	var best := INF
	for i in 4:
		best = minf(best, segment_segment_distance(a, b, corners[i], corners[(i + 1) % 4]))
	return best


## Distance from a segment to a polygon. Zero when the segment enters it.
static func segment_poly_distance(a: Vector2, b: Vector2, points: PackedVector2Array) -> float:
	var count := points.size()
	if count < 3:
		return INF
	if _point_in_poly(a, points) or _point_in_poly(b, points):
		return 0.0
	var best := INF
	for i in count:
		best = minf(best, segment_segment_distance(a, b, points[i], points[(i + 1) % count]))
	return best


static func _segment_hits_aabb(a: Vector2, b: Vector2, mn: Vector2, mx: Vector2) -> bool:
	var dx := b.x - a.x
	var dy := b.y - a.y
	var t0 := 0.0
	var t1 := 1.0
	if absf(dx) < 0.00001:
		if a.x < mn.x or a.x > mx.x:
			return false
	else:
		var inv_x := 1.0 / dx
		var tax := (mn.x - a.x) * inv_x
		var tbx := (mx.x - a.x) * inv_x
		if tax > tbx:
			var swap_x := tax
			tax = tbx
			tbx = swap_x
		t0 = maxf(t0, tax)
		t1 = minf(t1, tbx)
		if t0 > t1:
			return false
	if absf(dy) < 0.00001:
		if a.y < mn.y or a.y > mx.y:
			return false
	else:
		var inv_y := 1.0 / dy
		var tay := (mn.y - a.y) * inv_y
		var tby := (mx.y - a.y) * inv_y
		if tay > tby:
			var swap_y := tay
			tay = tby
			tby = swap_y
		t0 = maxf(t0, tay)
		t1 = minf(t1, tby)
		if t0 > t1:
			return false
	return true


static func _point_in_poly(point: Vector2, points: PackedVector2Array) -> bool:
	var inside := false
	var j := points.size() - 1
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[j]
		if ((a.y > point.y) != (b.y > point.y)) and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside
