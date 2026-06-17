extends RefCounted

const LAYER_NAME := "MotionTrail"
const TRAIL_META := "physics_motion_trail"
const LIFE_META := "physics_motion_trail_life"
const MAX_LIFE_META := "physics_motion_trail_max_life"
const BASE_ALPHA_META := "physics_motion_trail_base_alpha"
const SPEED_THRESHOLD := 180.0
const FULL_SPEED := 680.0
const SPAWN_INTERVAL_SLOW := 0.055
const SPAWN_INTERVAL_FAST := 0.025
const MAX_ACTIVE := 12

var _layer: Node2D = null
var _trails: Array[Node2D] = []
var _spawn_elapsed: float = 0.0
var _has_last_position: bool = false
var _last_position: Vector2 = Vector2.ZERO


func update(
	owner: RigidBody2D,
	delta: float,
	visual: Sprite2D,
	fallback_polygon: PackedVector2Array,
	tint: Color
) -> void:
	_update_effects(delta)
	if owner == null or not is_instance_valid(owner) or not owner.visible:
		_spawn_elapsed = 0.0
		_has_last_position = false
		return
	var position_velocity := Vector2.ZERO
	if _has_last_position and delta > 0.0:
		position_velocity = (owner.global_position - _last_position) / delta
	_last_position = owner.global_position
	_has_last_position = true
	var motion_velocity := owner.linear_velocity
	if position_velocity.length() > motion_velocity.length():
		motion_velocity = position_velocity
	var speed := motion_velocity.length()
	if speed < SPEED_THRESHOLD:
		_spawn_elapsed = minf(_spawn_elapsed + maxf(delta, 0.0), SPAWN_INTERVAL_SLOW)
		return
	var speed_ratio := _speed_ratio(speed)
	var spawn_interval := lerpf(SPAWN_INTERVAL_SLOW, SPAWN_INTERVAL_FAST, speed_ratio)
	_spawn_elapsed += maxf(delta, 0.0)
	if _spawn_elapsed < spawn_interval:
		return
	_spawn_elapsed = 0.0
	_spawn(owner, speed_ratio, motion_velocity, visual, fallback_polygon, tint)


func count() -> int:
	_prune_invalid()
	return _trails.size()


func _spawn(
	owner: RigidBody2D,
	speed_ratio: float,
	motion_velocity: Vector2,
	visual: Sprite2D,
	fallback_polygon: PackedVector2Array,
	tint: Color
) -> void:
	_prune_invalid()
	while _trails.size() >= MAX_ACTIVE:
		var old := _trails.pop_front() as Node2D
		if old != null and is_instance_valid(old) and not old.is_queued_for_deletion():
			old.queue_free()
	var layer := _ensure_layer(owner)
	var effect := Node2D.new()
	effect.name = "TrailGhost"
	effect.z_index = -1
	effect.set_meta(TRAIL_META, true)
	effect.set_meta(LIFE_META, 0.0)
	effect.set_meta(MAX_LIFE_META, lerpf(0.18, 0.34, speed_ratio))
	effect.set_meta(BASE_ALPHA_META, lerpf(0.22, 0.44, speed_ratio))
	layer.add_child(effect)
	var direction := motion_velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(0.0, -1.0)
	effect.global_position = owner.global_position - direction * lerpf(10.0, 26.0, speed_ratio)
	effect.global_rotation = owner.global_rotation
	_build_visual(effect, speed_ratio, visual, fallback_polygon, tint)
	_trails.append(effect)


func _ensure_layer(owner: RigidBody2D) -> Node2D:
	if _layer != null and is_instance_valid(_layer):
		_layer.z_index = owner.z_index - 1
		return _layer
	_layer = owner.get_node_or_null(LAYER_NAME) as Node2D
	if _layer == null:
		_layer = Node2D.new()
		_layer.name = LAYER_NAME
		owner.add_child(_layer)
	_layer.top_level = true
	_layer.global_position = Vector2.ZERO
	_layer.z_as_relative = false
	_layer.z_index = owner.z_index - 1
	return _layer


func _build_visual(
	effect: Node2D,
	speed_ratio: float,
	visual: Sprite2D,
	fallback_polygon: PackedVector2Array,
	tint: Color
) -> void:
	if visual != null and visual.texture != null and visual.visible:
		var sprite := Sprite2D.new()
		sprite.name = "GhostSprite"
		sprite.texture = visual.texture
		sprite.centered = visual.centered
		sprite.offset = visual.offset
		sprite.position = visual.position
		sprite.region_enabled = visual.region_enabled
		sprite.region_rect = visual.region_rect
		sprite.flip_h = visual.flip_h
		sprite.flip_v = visual.flip_v
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = visual.scale * lerpf(0.76, 0.94, speed_ratio)
		sprite.modulate = _trail_color(tint, speed_ratio)
		effect.add_child(sprite)
		return
	var polygon := Polygon2D.new()
	polygon.name = "GhostShape"
	polygon.polygon = fallback_polygon
	polygon.color = _trail_color(tint, speed_ratio)
	effect.add_child(polygon)


func _trail_color(tint: Color, speed_ratio: float) -> Color:
	var color := tint.lerp(Color(1.0, 0.78, 0.34), 0.22)
	color.a = lerpf(0.22, 0.44, speed_ratio)
	return color


func _update_effects(delta: float) -> void:
	if _trails.is_empty():
		return
	for i in range(_trails.size() - 1, -1, -1):
		var effect := _trails[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_trails.remove_at(i)
			continue
		var life := float(effect.get_meta(LIFE_META, 0.0)) + maxf(delta, 0.0)
		var max_life := float(effect.get_meta(MAX_LIFE_META, 0.2))
		effect.set_meta(LIFE_META, life)
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		effect.scale = Vector2.ONE * lerpf(1.0, 0.86, progress)
		var canvas_item := effect.get_child(0) as CanvasItem if effect.get_child_count() > 0 else null
		if canvas_item != null:
			var base_alpha := float(effect.get_meta(BASE_ALPHA_META, 0.3))
			canvas_item.modulate.a = base_alpha * (1.0 - progress)
		if life >= max_life:
			_trails.remove_at(i)
			effect.queue_free()


func _prune_invalid() -> void:
	for i in range(_trails.size() - 1, -1, -1):
		var effect := _trails[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_trails.remove_at(i)


func _speed_ratio(speed: float) -> float:
	return clampf(
		(speed - SPEED_THRESHOLD) / maxf(FULL_SPEED - SPEED_THRESHOLD, 0.01),
		0.0,
		1.0
	)
