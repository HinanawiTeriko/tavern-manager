class_name IngredientIntakeVfx
extends RefCounted

const LAYER_NAME := "IngredientIntakeVfx"
const ELEMENT_META := "ingredient_intake_vfx_element"
const GHOST_DURATION := 0.22
const GLOW_DURATION := 0.24
const MOTE_DURATION := 0.2
const SUBMERGED_LAYER_Z_OFFSET := -16
const GHOST_Z_INDEX := 4
const MOUTH_GLOW_Z_INDEX := 18
const MOTE_Z_INDEX := 5


static func spawn(container: Node2D, item: Node2D, item_key: String, target_global: Vector2, color: Color) -> void:
	if container == null or item == null:
		return
	var layer := _ensure_layer(container)
	_spawn_ghost(layer, item.global_position, target_global, item_key, color)
	_spawn_mouth_glow(layer, target_global, color)
	for i in range(5):
		_spawn_mote(layer, target_global, color, i)


static func _ensure_layer(container: Node2D) -> Node2D:
	var layer := container.get_node_or_null(LAYER_NAME) as Node2D
	if layer != null:
		layer.z_index = _container_art_absolute_z(container) + SUBMERGED_LAYER_Z_OFFSET
		return layer
	layer = Node2D.new()
	layer.name = LAYER_NAME
	layer.top_level = true
	layer.global_position = Vector2.ZERO
	layer.z_as_relative = false
	layer.z_index = _container_art_absolute_z(container) + SUBMERGED_LAYER_Z_OFFSET
	container.add_child(layer)
	return layer


static func _spawn_ghost(layer: Node2D, start_global: Vector2, target_global: Vector2, item_key: String, color: Color) -> void:
	var effect := Node2D.new()
	effect.name = "IntakeGhost"
	effect.z_index = GHOST_Z_INDEX
	effect.set_meta(ELEMENT_META, "ghost")
	layer.add_child(effect)
	effect.global_position = start_global
	effect.scale = Vector2.ONE
	effect.modulate = Color(1.0, 1.0, 1.0, 0.92)

	var texture := GameManager.try_load_material_icon(item_key)
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = texture
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = color.lightened(0.08)
		effect.add_child(sprite)
	else:
		var shape := _new_pixel_diamond("Fallback", color.lightened(0.1), 9.0)
		effect.add_child(shape)

	var tween := layer.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "global_position", target_global, GHOST_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(effect, "scale", Vector2.ONE * 0.18, GHOST_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(effect, "modulate", Color(1.0, 1.0, 1.0, 0.0), GHOST_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)


static func _spawn_mouth_glow(layer: Node2D, target_global: Vector2, color: Color) -> void:
	var effect := Node2D.new()
	effect.name = "IntakeMouthGlow"
	effect.z_index = MOUTH_GLOW_Z_INDEX
	effect.set_meta(ELEMENT_META, "mouth_glow")
	layer.add_child(effect)
	effect.global_position = target_global
	effect.scale = Vector2(0.72, 0.38)
	effect.modulate = Color(1.0, 1.0, 1.0, 0.86)

	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.polygon = PackedVector2Array([
		Vector2(-18.0, 0.0),
		Vector2(-9.0, -5.0),
		Vector2(9.0, -5.0),
		Vector2(18.0, 0.0),
		Vector2(9.0, 5.0),
		Vector2(-9.0, 5.0),
	])
	glow.color = Color(color.r, color.g, color.b, 0.44)
	effect.add_child(glow)

	var tween := layer.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(1.22, 0.54), GLOW_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(effect, "modulate", Color(1.0, 1.0, 1.0, 0.0), GLOW_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)


static func _spawn_mote(layer: Node2D, target_global: Vector2, color: Color, index: int) -> void:
	var effect := Node2D.new()
	effect.name = "IntakeMote"
	effect.z_index = MOTE_Z_INDEX
	effect.set_meta(ELEMENT_META, "mote")
	layer.add_child(effect)
	var angle := TAU * (float(index) + 0.18) / 5.0
	var radius := 18.0 + float(index % 2) * 6.0
	var start := target_global + Vector2(cos(angle), sin(angle) * 0.62) * radius
	effect.global_position = start
	effect.scale = Vector2.ONE * (0.8 + float(index % 3) * 0.12)
	effect.modulate = Color(1.0, 1.0, 1.0, 0.92)
	effect.add_child(_new_pixel_diamond("Pixel", color.lightened(0.18), 2.4 + float(index % 2)))

	var tween := layer.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "global_position", target_global + Vector2(0.0, -2.0), MOTE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(effect, "scale", Vector2.ONE * 0.24, MOTE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(effect, "modulate", Color(1.0, 1.0, 1.0, 0.0), MOTE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)


static func _new_pixel_diamond(node_name: String, color: Color, size: float) -> Polygon2D:
	var diamond := Polygon2D.new()
	diamond.name = node_name
	diamond.polygon = PackedVector2Array([
		Vector2(0.0, -size),
		Vector2(size, 0.0),
		Vector2(0.0, size),
		Vector2(-size, 0.0),
	])
	diamond.color = color
	return diamond


static func _container_art_absolute_z(container: Node2D) -> int:
	var art := container.get_node_or_null("Art") as CanvasItem
	if art != null:
		return _canvas_absolute_z(art)
	return _canvas_absolute_z(container)


static func _canvas_absolute_z(item: CanvasItem) -> int:
	var total := item.z_index
	var cursor := item
	while cursor.z_as_relative:
		var parent := cursor.get_parent()
		if not parent is CanvasItem:
			break
		cursor = parent as CanvasItem
		total += cursor.z_index
	return total
