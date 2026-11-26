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
