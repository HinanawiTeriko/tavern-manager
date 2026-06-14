class_name TextureCollisionBounds
extends RefCounted


static func alpha_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var image := texture.get_image()
	if image == null:
		return Rect2(Vector2.ZERO, Vector2(texture.get_width(), texture.get_height()))
	var min_p := Vector2i(image.get_width(), image.get_height())
	var max_p := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			min_p.x = mini(min_p.x, x)
			min_p.y = mini(min_p.y, y)
			max_p.x = maxi(max_p.x, x)
			max_p.y = maxi(max_p.y, y)
	if max_p.x < min_p.x or max_p.y < min_p.y:
		return Rect2()
	return Rect2(Vector2(min_p), Vector2(max_p - min_p + Vector2i.ONE))


static func centered_sprite_alpha_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	var rect := alpha_rect(sprite.texture)
	if rect.size == Vector2.ZERO:
		return Rect2()
	var full_size := Vector2(sprite.texture.get_width(), sprite.texture.get_height())
	var scale_abs := Vector2(absf(sprite.scale.x), absf(sprite.scale.y))
	var origin := sprite.position
	if sprite.centered:
		origin += (rect.position - full_size * 0.5) * sprite.scale
	else:
		origin += rect.position * sprite.scale
	return Rect2(origin, rect.size * scale_abs)


static func centered_sprite_alpha_convex_polygon(sprite: Sprite2D) -> PackedVector2Array:
	if sprite == null or sprite.texture == null:
		return PackedVector2Array()
	var image := sprite.texture.get_image()
	if image == null:
		return _rect_points(centered_sprite_alpha_rect(sprite))
	var full_size := Vector2(sprite.texture.get_width(), sprite.texture.get_height())
	var points: Array[Vector2] = []
	for y in image.get_height():
		for x in image.get_width():
			if not _is_alpha_edge(image, x, y):
				continue
			_append_pixel_corners(points, x, y, full_size, sprite)
	return _convex_hull(points)


static func _is_alpha_edge(image: Image, x: int, y: int) -> bool:
	if image.get_pixel(x, y).a <= 0.0:
		return false
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var nx := x + offset_x
			var ny := y + offset_y
			if nx < 0 or ny < 0 or nx >= image.get_width() or ny >= image.get_height():
				return true
			if image.get_pixel(nx, ny).a <= 0.0:
				return true
	return false


static func _append_pixel_corners(points: Array[Vector2], x: int, y: int, full_size: Vector2, sprite: Sprite2D) -> void:
	var corners := [
		Vector2(x, y),
		Vector2(x + 1, y),
		Vector2(x + 1, y + 1),
		Vector2(x, y + 1),
	]
	for corner in corners:
		var point: Vector2 = corner
		if sprite.centered:
			point -= full_size * 0.5
		point = Vector2(point.x * sprite.scale.x, point.y * sprite.scale.y)
		point += sprite.position
		points.append(point)


static func _convex_hull(points: Array[Vector2]) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array(points)
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if not is_equal_approx(a.x, b.x):
			return a.x < b.x
		return a.y < b.y
	)
	var unique: Array[Vector2] = []
	for point in points:
		if unique.is_empty() or not unique[unique.size() - 1].is_equal_approx(point):
			unique.append(point)
	if unique.size() < 3:
		return PackedVector2Array(unique)
	var lower: Array[Vector2] = []
	for point in unique:
		while lower.size() >= 2 and _cross(lower[lower.size() - 1] - lower[lower.size() - 2], point - lower[lower.size() - 1]) <= 0.0:
			lower.pop_back()
		lower.append(point)
	var upper: Array[Vector2] = []
	for i in range(unique.size() - 1, -1, -1):
		var point := unique[i]
		while upper.size() >= 2 and _cross(upper[upper.size() - 1] - upper[upper.size() - 2], point - upper[upper.size() - 1]) <= 0.0:
			upper.pop_back()
		upper.append(point)
	lower.pop_back()
	upper.pop_back()
	return PackedVector2Array(lower + upper)


static func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


static func _rect_points(rect: Rect2) -> PackedVector2Array:
	if rect.size == Vector2.ZERO:
		return PackedVector2Array()
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
