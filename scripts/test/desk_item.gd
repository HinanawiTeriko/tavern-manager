class_name DeskItem
extends RigidBody2D

const KILL_Y: float = 800.0
const IMPACT_DEBUG_SPEED: float = 260.0
const ART_TEXTURE_SCALE := 0.82
const MOTION_TRAIL_LAYER_NAME := "MotionTrail"
const MOTION_TRAIL_META := "desk_item_motion_trail"
const MOTION_TRAIL_LIFE_META := "desk_item_motion_trail_life"
const MOTION_TRAIL_MAX_LIFE_META := "desk_item_motion_trail_max_life"
const MOTION_TRAIL_BASE_ALPHA_META := "desk_item_motion_trail_base_alpha"
const MOTION_TRAIL_SPEED_THRESHOLD := 180.0
const MOTION_TRAIL_FULL_SPEED := 680.0
const MOTION_TRAIL_SPAWN_INTERVAL_SLOW := 0.055
const MOTION_TRAIL_SPAWN_INTERVAL_FAST := 0.025
const MOTION_TRAIL_MAX_ACTIVE := 12
const SEASONING_VISUAL_LAYER_NAME := "SeasoningVisual"
const PRODUCT_SEASONING_VISUAL_KIND_META := "product_seasoning_visual_kind"
const PRODUCT_SEASONING_VISUAL_LIFE_META := "product_seasoning_visual_life"
const PRODUCT_SEASONING_VISUAL_MAX_LIFE_META := "product_seasoning_visual_max_life"
const PRODUCT_SEASONING_VISUAL_VELOCITY_META := "product_seasoning_visual_velocity"
const PRODUCT_SEASONING_VISUAL_PHASE_META := "product_seasoning_visual_phase"
const PRODUCT_SEASONING_VISUAL_PHASE_SPEED_META := "product_seasoning_visual_phase_speed"
const PRODUCT_SEASONING_VISUAL_BASE_SCALE_META := "product_seasoning_visual_base_scale"
const PRODUCT_SEASONING_STACK_BASE_POS_META := "product_seasoning_stack_base_pos"
const PRODUCT_SEASONING_STACK_DEPTH_META := "product_seasoning_stack_depth"
const PRODUCT_SEASONING_STACK_RADIUS_X := 8.0
const PRODUCT_SEASONING_STACK_RADIUS_Y := 10.0
const PRODUCT_SEASONING_STACK_LIFT_CURVE := 2.6
const PRODUCT_SEASONING_STACK_ENGINE_Z_MAX := 4095
const PRODUCT_SEASONING_STACK_MAX_SCALE_BOOST := 1.05
const PRODUCT_SEASONING_EDGE_OVERHANG_START := 0.72
const PRODUCT_SEASONING_EDGE_OVERHANG_MAX := 7.0
const SEASONING_PARTICLE_ATLAS := preload("res://assets/textures/seasoning_particles/seasoning_particles.png")
const SEASONING_PARTICLE_SLOT_SIZE := Vector2(96.0, 96.0)
const SEASONING_PARTICLE_VARIANT_COUNT := 4
const MEAT_DONENESS := preload("res://scripts/systems/meat_doneness.gd")
const TEXTURE_COLLISION_BOUNDS := preload("res://scripts/ui/texture_collision_bounds.gd")

const PHYSICS_LIMITS := {
	"mass": Vector2(0.2, 5.0),
	"friction": Vector2(0.0, 1.0),
	"bounce": Vector2(0.0, 0.8),
	"linear_damp": Vector2(0.0, 2.0),
	"angular_damp": Vector2(0.0, 2.0),
	"gravity_scale": Vector2(0.2, 2.0),
}

const FALLBACK_PROFILES := {
	"physics": {
		"default": {
			"mass": 1.0,
			"friction": 0.6,
			"bounce": 0.25,
			"linear_damp": 0.2,
			"angular_damp": 0.2,
			"gravity_scale": 1.0
		}
	},
	"collision": {
		"default_box": {
			"shape": "rect",
			"size": [56, 56],
			"offset": [0, 0]
		}
	},
	"feedback": {
		"default": {
			"impact_sound": "normal",
			"impact_particle": "",
			"shake_scale": 0.0
		}
	}
}

var item_key: String = ""
var document_id: String = ""   # 可阅读文档的 document_id（与 item_key 一致）
var quality: String = "normal"
var product_tags: Array[String] = []   # 叙事载体标记（如 sleep_powder），递交时透传给 resolve_action
var attribute: String = ""   # L1 单属性（辛辣/清香/咸香/安眠）；覆盖式：set_attribute 直接替换
var is_held: bool = false
var feedback_profile: Dictionary = {}
var _pending_color: Color = Color.WHITE
var _pending_art_texture: Texture2D = null
var _icon_art: Sprite2D = null
var _profile_collision_shape: Shape2D = null
var _profile_collision_position: Vector2 = Vector2.ZERO
var _art_collision_active: bool = false
var _doneness = MEAT_DONENESS.new()
var _motion_trail_layer: Node2D = null
var _motion_trails: Array[Node2D] = []
var _motion_trail_spawn_elapsed: float = 0.0
var _seasoning_visual_layer: Node2D = null
var _seasoning_visual_effects: Array[Node2D] = []

signal fell_out_of_bounds(item: DeskItem)
signal open_requested(document_id: String)

var _fell_emitted: bool = false
var _last_impact_audio_msec: int = -1000

@onready var _visual_top: Polygon2D = $VisualTop
@onready var _visual_bottom: Polygon2D = $VisualBottom
@onready var _face_top: Marker2D = $FaceTop
@onready var _face_bottom: Marker2D = $FaceBottom
@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	_ensure_icon_art()
	_apply_base_color(_pending_color)
	_apply_art_texture()
	if attribute != "":
		_refresh_seasoning_visuals(4, global_position + Vector2(0.0, -72.0), false)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	if global_position.y > KILL_Y and not _fell_emitted:
		_fell_emitted = true
		fell_out_of_bounds.emit(self)
	_update_motion_trail(_delta)
	_update_seasoning_visual_effects(_delta)


func _update_motion_trail(delta: float) -> void:
	_update_motion_trail_effects(delta)
	if not visible:
		_motion_trail_spawn_elapsed = 0.0
		return
	var speed := linear_velocity.length()
	if speed < MOTION_TRAIL_SPEED_THRESHOLD:
		_motion_trail_spawn_elapsed = minf(_motion_trail_spawn_elapsed + delta, MOTION_TRAIL_SPAWN_INTERVAL_SLOW)
		return
	var speed_ratio := _motion_trail_speed_ratio(speed)
	var spawn_interval := lerpf(MOTION_TRAIL_SPAWN_INTERVAL_SLOW, MOTION_TRAIL_SPAWN_INTERVAL_FAST, speed_ratio)
	_motion_trail_spawn_elapsed += maxf(delta, 0.0)
	if _motion_trail_spawn_elapsed < spawn_interval:
		return
	_motion_trail_spawn_elapsed = 0.0
	_spawn_motion_trail(speed_ratio)


func _spawn_motion_trail(speed_ratio: float) -> void:
	_prune_invalid_motion_trails()
	while _motion_trails.size() >= MOTION_TRAIL_MAX_ACTIVE:
		var old: Node2D = _motion_trails.pop_front() as Node2D
		if old != null and is_instance_valid(old) and not old.is_queued_for_deletion():
			old.queue_free()
	var layer := _ensure_motion_trail_layer()
	var effect := Node2D.new()
	effect.name = "TrailGhost"
	effect.z_index = -1
	effect.set_meta(MOTION_TRAIL_META, true)
	effect.set_meta(MOTION_TRAIL_LIFE_META, 0.0)
	effect.set_meta(MOTION_TRAIL_MAX_LIFE_META, lerpf(0.18, 0.34, speed_ratio))
	effect.set_meta(MOTION_TRAIL_BASE_ALPHA_META, lerpf(0.24, 0.48, speed_ratio))
	layer.add_child(effect)
	var direction := linear_velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(0.0, -1.0)
	effect.global_position = global_position - direction * lerpf(8.0, 22.0, speed_ratio)
	effect.global_rotation = global_rotation
	_build_motion_trail_visual(effect, speed_ratio)
	_motion_trails.append(effect)


func _ensure_motion_trail_layer() -> Node2D:
	if _motion_trail_layer != null and is_instance_valid(_motion_trail_layer):
		_motion_trail_layer.z_index = z_index - 1
		return _motion_trail_layer
	_motion_trail_layer = get_node_or_null(MOTION_TRAIL_LAYER_NAME) as Node2D
	if _motion_trail_layer == null:
		_motion_trail_layer = Node2D.new()
		_motion_trail_layer.name = MOTION_TRAIL_LAYER_NAME
		add_child(_motion_trail_layer)
	_motion_trail_layer.top_level = true
	_motion_trail_layer.global_position = Vector2.ZERO
	_motion_trail_layer.z_as_relative = false
	_motion_trail_layer.z_index = z_index - 1
	return _motion_trail_layer


func _build_motion_trail_visual(effect: Node2D, speed_ratio: float) -> void:
	if _icon_art != null and _icon_art.texture != null and _icon_art.visible:
		var sprite := Sprite2D.new()
		sprite.name = "GhostSprite"
		sprite.texture = _icon_art.texture
		sprite.centered = _icon_art.centered
		sprite.region_enabled = _icon_art.region_enabled
		sprite.region_rect = _icon_art.region_rect
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = _icon_art.scale * lerpf(0.72, 0.94, speed_ratio)
		sprite.modulate = _motion_trail_color(speed_ratio)
		effect.add_child(sprite)
		return
	var polygon := Polygon2D.new()
	polygon.name = "GhostShape"
	polygon.polygon = _motion_trail_fallback_polygon()
	polygon.color = _motion_trail_color(speed_ratio)
	effect.add_child(polygon)


func _motion_trail_color(speed_ratio: float) -> Color:
	var base := _pending_color
	if quality == "good":
		base = Color(1.0, 0.74, 0.22)
	else:
		base = base.lerp(Color(1.0, 0.76, 0.34), 0.18)
	base.a = lerpf(0.24, 0.48, speed_ratio)
	return base


func _motion_trail_fallback_polygon() -> PackedVector2Array:
	var half := Vector2(18.0, 18.0)
	if _shape != null and _shape.shape is RectangleShape2D:
		var rect := _shape.shape as RectangleShape2D
		half = rect.size * 0.5
	elif _shape != null and _shape.shape is CircleShape2D:
		var circle := _shape.shape as CircleShape2D
		half = Vector2.ONE * circle.radius
	elif _shape != null and _shape.shape is CapsuleShape2D:
		var capsule := _shape.shape as CapsuleShape2D
		half = Vector2(capsule.radius, capsule.height * 0.5)
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])


func _update_motion_trail_effects(delta: float) -> void:
	if _motion_trails.is_empty():
		return
	for i in range(_motion_trails.size() - 1, -1, -1):
		var effect := _motion_trails[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_motion_trails.remove_at(i)
			continue
		var life := float(effect.get_meta(MOTION_TRAIL_LIFE_META, 0.0)) + maxf(delta, 0.0)
		var max_life := float(effect.get_meta(MOTION_TRAIL_MAX_LIFE_META, 0.2))
		effect.set_meta(MOTION_TRAIL_LIFE_META, life)
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		effect.scale = Vector2.ONE * lerpf(1.0, 0.86, progress)
		var visual := effect.get_child(0) as CanvasItem if effect.get_child_count() > 0 else null
		if visual != null:
			var base_alpha := float(effect.get_meta(MOTION_TRAIL_BASE_ALPHA_META, 0.3))
			visual.modulate.a = base_alpha * (1.0 - progress)
		if life >= max_life:
			_motion_trails.remove_at(i)
			effect.queue_free()


func _prune_invalid_motion_trails() -> void:
	for i in range(_motion_trails.size() - 1, -1, -1):
		var effect := _motion_trails[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_motion_trails.remove_at(i)


func _motion_trail_speed_ratio(speed: float) -> float:
	return clampf(
		(speed - MOTION_TRAIL_SPEED_THRESHOLD) / maxf(MOTION_TRAIL_FULL_SPEED - MOTION_TRAIL_SPEED_THRESHOLD, 0.01),
		0.0,
		1.0
	)


func _on_body_entered(_body: Node) -> void:
	if linear_velocity.length() < IMPACT_DEBUG_SPEED:
		return
	var now := Time.get_ticks_msec()
	if now - _last_impact_audio_msec < 100:
		return
	_last_impact_audio_msec = now
	GameManager.play_audio_event("collision")


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not document_id:
		return
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed \
		and event.double_click:
		open_requested.emit(document_id)


## 回收复用：被移回回收区后清除越界标记，使其再次掉落仍能触发回收。
func reset_fall_state() -> void:
	_fell_emitted = false


## 打上叙事标记（如 sleep_powder）。药酒标记附带淡紫染色以便辨识（占位视觉，正式 VFX 属 P5）。
func add_product_tag(tag: String) -> void:
	if not product_tags.has(tag):
		product_tags.append(tag)
	if tag == "sleep_powder":
		modulate = Color(0.72, 0.58, 0.88)


## 覆盖式写 L1 属性（后撒覆盖前者）。空串清除。
func set_attribute(a: String) -> void:
	attribute = a
	if is_node_ready() and attribute == "":
		_clear_seasoning_visuals()


func apply_seasoning_visual_feedback(a: String, intensity: int, source_global_position: Vector2) -> void:
	attribute = a
	if is_node_ready() and _product_seasoning_surface_count() == 0:
		_append_seasoning_deposit(intensity, source_global_position)


func can_accept_seasoning_particle(global_pos: Vector2) -> bool:
	var local_pos := to_local(global_pos)
	var half_extents := _seasoning_visual_half_extents()
	return absf(local_pos.x) <= half_extents.x \
		and local_pos.y >= -half_extents.y - 4.0 \
		and local_pos.y <= half_extents.y * 0.35


func stick_seasoning_particle(
	global_pos: Vector2,
	_seasoning_key: String,
	kind: String,
	region_rect: Rect2,
	tint: Color,
	source_scale: Vector2,
	source_rotation: float
) -> bool:
	if not can_accept_seasoning_particle(global_pos):
		return false
	if kind == "mist":
		return false
	var layer := _ensure_seasoning_visual_layer()
	var half_extents := _seasoning_visual_half_extents()
	var local_pos := to_local(global_pos)
	local_pos = Vector2(
		clampf(local_pos.x, -half_extents.x, half_extents.x),
		clampf(local_pos.y, -half_extents.y, half_extents.y * 0.28)
	)
	var stack_depth := _product_seasoning_stack_depth_at(layer, local_pos)
	var stack_offset := _product_seasoning_stack_offset(stack_depth)
	var edge_overhang := _product_seasoning_edge_overhang(local_pos, half_extents)
	var stack_scale := 1.0 + minf(
		pow(float(stack_depth), 0.82) * 0.065,
		PRODUCT_SEASONING_STACK_MAX_SCALE_BOOST
	)
	var effect := Node2D.new()
	effect.name = "ProductSeasoningStuck"
	effect.position = local_pos + stack_offset + edge_overhang
	effect.rotation = source_rotation + _product_seasoning_stack_rotation_offset(stack_depth)
	effect.scale = source_scale * stack_scale
	effect.z_index = mini(stack_depth, PRODUCT_SEASONING_STACK_ENGINE_Z_MAX)
	effect.set_meta(PRODUCT_SEASONING_VISUAL_KIND_META, "surface")
	effect.set_meta(PRODUCT_SEASONING_VISUAL_BASE_SCALE_META, maxf(effect.scale.x, effect.scale.y))
	effect.set_meta(PRODUCT_SEASONING_STACK_BASE_POS_META, local_pos)
	effect.set_meta(PRODUCT_SEASONING_STACK_DEPTH_META, stack_depth)
	effect.set_meta("product_seasoning_particle_kind", kind)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = SEASONING_PARTICLE_ATLAS
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = region_rect
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = tint
	if kind == "mist":
		sprite.modulate.a = maxf(sprite.modulate.a, 0.34)
	else:
		sprite.modulate.a = maxf(sprite.modulate.a, 0.72)
	effect.add_child(sprite)
	layer.add_child(effect)
	return true


func _product_seasoning_stack_depth_at(layer: Node2D, base_local_pos: Vector2) -> int:
	var depth := 0
	for child in layer.get_children():
		if not child is Node2D:
			continue
		var crumb := child as Node2D
		if crumb.is_queued_for_deletion():
			continue
		if String(crumb.get_meta(PRODUCT_SEASONING_VISUAL_KIND_META, "")) != "surface":
			continue
		var anchor_pos: Vector2 = crumb.position
		if crumb.has_meta(PRODUCT_SEASONING_STACK_BASE_POS_META):
			anchor_pos = crumb.get_meta(PRODUCT_SEASONING_STACK_BASE_POS_META) as Vector2
		if absf(anchor_pos.x - base_local_pos.x) <= PRODUCT_SEASONING_STACK_RADIUS_X \
				and absf(anchor_pos.y - base_local_pos.y) <= PRODUCT_SEASONING_STACK_RADIUS_Y:
			depth += 1
	return depth


func _product_seasoning_stack_offset(depth: int) -> Vector2:
	if depth <= 0:
		return Vector2.ZERO
	var lift := _product_seasoning_stack_lift(depth)
	var mound_progress := minf(1.0, sqrt(float(depth)) / 8.5)
	var x_t := float(posmod(depth * 5, 9)) / 8.0
	var y_t := float(posmod(depth * 7, 5)) / 4.0
	var side_radius := lerpf(2.4, 0.75, mound_progress)
	return Vector2(
		lerpf(-side_radius, side_radius, x_t),
		-lift + lerpf(-0.28, 0.28, y_t)
	)


func _product_seasoning_stack_lift(depth: int) -> float:
	return sqrt(float(maxi(depth, 0))) * PRODUCT_SEASONING_STACK_LIFT_CURVE


func _product_seasoning_edge_overhang(base_local_pos: Vector2, half_extents: Vector2) -> Vector2:
	if half_extents.x <= 0.01:
		return Vector2.ZERO
	var edge_ratio_x := absf(base_local_pos.x) / half_extents.x
	if edge_ratio_x <= PRODUCT_SEASONING_EDGE_OVERHANG_START:
		return Vector2.ZERO
	var progress := clampf(
		(edge_ratio_x - PRODUCT_SEASONING_EDGE_OVERHANG_START) / (1.0 - PRODUCT_SEASONING_EDGE_OVERHANG_START),
		0.0,
		1.0
	)
	var overhang := pow(progress, 1.15) * PRODUCT_SEASONING_EDGE_OVERHANG_MAX
	return Vector2(signf(base_local_pos.x) * overhang, 0.0)


func _product_seasoning_stack_rotation_offset(depth: int) -> float:
	if depth <= 0:
		return 0.0
	var t := float(posmod(depth * 3, 7)) / 6.0
	return lerpf(-0.22, 0.22, t)


func _refresh_seasoning_visuals(intensity: int, source_global_position: Vector2, include_impact: bool) -> void:
	_clear_seasoning_visuals()
	if attribute == "":
		return
	var layer := _ensure_seasoning_visual_layer()
	var effective_intensity := maxi(intensity, 1)
	var deposit_center := _seasoning_deposit_center(source_global_position)
	if include_impact:
		_spawn_product_seasoning_impact(layer, effective_intensity, deposit_center)
	_spawn_product_seasoning_surface(layer, effective_intensity, deposit_center)
	_spawn_product_seasoning_aroma(layer, effective_intensity, deposit_center)


func _append_seasoning_deposit(intensity: int, source_global_position: Vector2) -> void:
	if attribute == "":
		return
	var layer := _ensure_seasoning_visual_layer()
	var effective_intensity := maxi(intensity, 1)
	var deposit_center := _seasoning_deposit_center(source_global_position)
	_spawn_product_seasoning_impact(layer, effective_intensity, deposit_center)
	_spawn_product_seasoning_surface(layer, effective_intensity, deposit_center)
	_spawn_product_seasoning_aroma(layer, effective_intensity, deposit_center)


func _clear_seasoning_visuals() -> void:
	_seasoning_visual_effects.clear()
	var layer := _ensure_seasoning_visual_layer()
	for child in layer.get_children():
		child.queue_free()


func _ensure_seasoning_visual_layer() -> Node2D:
	if _seasoning_visual_layer != null and is_instance_valid(_seasoning_visual_layer):
		return _seasoning_visual_layer
	_seasoning_visual_layer = get_node_or_null(SEASONING_VISUAL_LAYER_NAME) as Node2D
	if _seasoning_visual_layer == null:
		_seasoning_visual_layer = Node2D.new()
		_seasoning_visual_layer.name = SEASONING_VISUAL_LAYER_NAME
		add_child(_seasoning_visual_layer)
	_seasoning_visual_layer.z_as_relative = true
	_seasoning_visual_layer.z_index = 12
	return _seasoning_visual_layer


func _product_seasoning_surface_count() -> int:
	var layer := get_node_or_null(SEASONING_VISUAL_LAYER_NAME) as Node2D
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is Node2D \
				and not child.is_queued_for_deletion() \
				and String((child as Node2D).get_meta(PRODUCT_SEASONING_VISUAL_KIND_META, "")) == "surface":
			count += 1
	return count


func _spawn_product_seasoning_impact(layer: Node2D, intensity: int, deposit_center: Vector2) -> void:
	var count := clampi(4 + intensity, 6, 22)
	var half_extents := _seasoning_visual_half_extents()
	var element := _seasoning_impact_element(attribute)
	for i in range(count):
		var slot := (float(i) + 0.5) / float(maxi(count, 1))
		var side := lerpf(-1.0, 1.0, slot)
		var local_pos := deposit_center + Vector2(
			side * lerpf(4.0, minf(half_extents.x * 0.42, 15.0), absf(side)),
			4.0 + sin(slot * PI) * 5.0
		)
		var velocity := Vector2(
			side * lerpf(22.0, 72.0, minf(1.0, float(intensity) / 12.0)),
			-lerpf(24.0, 56.0, sin(slot * PI))
		)
		var effect := _new_product_seasoning_effect(
			"ProductSeasoningImpact",
			"impact",
			element,
			i,
			local_pos,
			0.07 + float(i % 4) * 0.008,
			0.48 + float(i % 3) * 0.05,
			velocity
		)
		layer.add_child(effect)
		_seasoning_visual_effects.append(effect)


func _spawn_product_seasoning_surface(layer: Node2D, intensity: int, deposit_center: Vector2) -> void:
	var count := clampi(8 + intensity * 2, 10, 44)
	var half_extents := _seasoning_visual_half_extents()
	var pile_radius := _seasoning_deposit_radius(intensity, half_extents)
	var element := _seasoning_surface_element(attribute)
	for i in range(count):
		var local_pos := _seasoning_surface_position(i, count, deposit_center, pile_radius, half_extents)
		var scale_value := 0.046 + float(i % 5) * 0.006
		var effect := _new_product_seasoning_effect(
			"ProductSeasoningFleck",
			"surface",
			element,
			i,
			local_pos,
			scale_value,
			0.0,
			Vector2.ZERO
		)
		layer.add_child(effect)


func _spawn_product_seasoning_aroma(layer: Node2D, intensity: int, deposit_center: Vector2) -> void:
	var count := clampi(3 + int(floor(float(intensity) * 0.5)), 4, 16)
	var half_extents := _seasoning_visual_half_extents()
	for i in range(count):
		var slot := (float(i) + 0.5) / float(maxi(count, 1))
		var wave := sin(slot * PI)
		var local_pos := Vector2(
			deposit_center.x + lerpf(-9.0, 9.0, slot),
			-half_extents.y - 8.0 - wave * 8.0
		)
		var velocity := Vector2(
			lerpf(-10.0, 10.0, slot),
			-lerpf(16.0, 36.0, minf(1.0, float(intensity) / 14.0))
		)
		var effect := _new_product_seasoning_effect(
			"ProductSeasoningAroma",
			"aroma",
			_seasoning_aroma_element(attribute),
			i,
			local_pos,
			0.088 + float(i % 4) * 0.012,
			0.82 + float(i % 5) * 0.08,
			velocity
		)
		layer.add_child(effect)
		_seasoning_visual_effects.append(effect)


func _new_product_seasoning_effect(
	node_name: String,
	visual_kind: String,
	element: String,
	variant: int,
	local_pos: Vector2,
	scale_value: float,
	max_life: float,
	velocity: Vector2
) -> Node2D:
	var effect := Node2D.new()
	effect.name = node_name
	effect.position = local_pos
	effect.rotation = _stable_seasoning_particle_rotation(variant, visual_kind)
	effect.scale = Vector2.ONE * scale_value
	effect.set_meta(PRODUCT_SEASONING_VISUAL_KIND_META, visual_kind)
	effect.set_meta(PRODUCT_SEASONING_VISUAL_BASE_SCALE_META, scale_value)
	if max_life > 0.0:
		effect.set_meta(PRODUCT_SEASONING_VISUAL_LIFE_META, 0.0)
		effect.set_meta(PRODUCT_SEASONING_VISUAL_MAX_LIFE_META, max_life)
		effect.set_meta(PRODUCT_SEASONING_VISUAL_VELOCITY_META, velocity)
		effect.set_meta(PRODUCT_SEASONING_VISUAL_PHASE_META, float(variant) * 0.73)
		effect.set_meta(PRODUCT_SEASONING_VISUAL_PHASE_SPEED_META, 2.0 + float(variant % 5) * 0.34)
	var sprite := _new_product_seasoning_particle_sprite(element, variant)
	sprite.name = "Sprite"
	sprite.modulate = _seasoning_visual_color(attribute, visual_kind)
	effect.add_child(sprite)
	return effect


func _new_product_seasoning_particle_sprite(element: String, variant: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = SEASONING_PARTICLE_ATLAS
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		Vector2(
			float(posmod(variant, SEASONING_PARTICLE_VARIANT_COUNT)) * SEASONING_PARTICLE_SLOT_SIZE.x,
			float(_seasoning_particle_element_row(element)) * SEASONING_PARTICLE_SLOT_SIZE.y
		),
		SEASONING_PARTICLE_SLOT_SIZE
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _seasoning_surface_element(attr: String) -> String:
	match attr:
		"辛辣", "清香":
			return "flake"
		"安眠":
			return "mist"
		_:
			return "dust"


func _seasoning_impact_element(attr: String) -> String:
	match attr:
		"辛辣":
			return "spark"
		"清香":
			return "flake"
		_:
			return "dust"


func _seasoning_aroma_element(attr: String) -> String:
	match attr:
		"辛辣":
			return "spark"
		_:
			return "mist"


func _seasoning_particle_element_row(element: String) -> int:
	match element:
		"flake":
			return 1
		"mist":
			return 2
		"spark":
			return 3
		"settle_cloud":
			return 4
		_:
			return 0


func _seasoning_visual_color(attr: String, visual_kind: String) -> Color:
	var color := Color(0.92, 0.76, 0.36, 0.95)
	match attr:
		"辛辣":
			color = Color(1.0, 0.34, 0.14, 0.96)
		"清香":
			color = Color(0.43, 0.93, 0.48, 0.92)
		"咸香":
			color = Color(0.96, 0.9, 0.68, 0.94)
		"安眠":
			color = Color(0.68, 0.48, 0.95, 0.9)
	if visual_kind == "aroma":
		color.a *= 0.62
	return color


func _stable_seasoning_particle_rotation(variant: int, visual_kind: String) -> float:
	var step := 0.37 if visual_kind == "surface" else 0.22
	return -0.38 + float(variant % 5) * step


func _seasoning_visual_half_extents() -> Vector2:
	var half := Vector2(28.0, 22.0)
	if _shape != null and _shape.shape is RectangleShape2D:
		var rect := _shape.shape as RectangleShape2D
		half = rect.size * Vector2(0.44, 0.34)
	elif _shape != null and _shape.shape is CircleShape2D:
		var circle := _shape.shape as CircleShape2D
		half = Vector2(circle.radius * 0.82, circle.radius * 0.62)
	elif _shape != null and _shape.shape is CapsuleShape2D:
		var capsule := _shape.shape as CapsuleShape2D
		half = Vector2(capsule.radius * 0.92, capsule.height * 0.28)
	elif _icon_art != null and _icon_art.texture != null:
		half = _icon_art.texture.get_size() * _icon_art.scale * 0.32
	return half.clamp(Vector2(12.0, 10.0), Vector2(54.0, 42.0))


func _seasoning_deposit_center(source_global_position: Vector2) -> Vector2:
	var half_extents := _seasoning_visual_half_extents()
	var source_local := to_local(source_global_position)
	return Vector2(
		clampf(source_local.x, -half_extents.x * 0.82, half_extents.x * 0.82),
		clampf(source_local.y, -half_extents.y * 0.68, half_extents.y * 0.22)
	)


func _seasoning_deposit_radius(intensity: int, half_extents: Vector2) -> Vector2:
	return Vector2(
		clampf(6.0 + float(intensity) * 0.72, 8.0, minf(half_extents.x * 0.64, 20.0)),
		clampf(4.0 + float(intensity) * 0.42, 5.0, minf(half_extents.y * 0.56, 13.0))
	)


func _seasoning_surface_position(index: int, count: int, deposit_center: Vector2, pile_radius: Vector2, half_extents: Vector2) -> Vector2:
	var angle := float(index) * 2.399963 + float(_seasoning_attribute_seed(attribute)) * 0.11
	var ring := pow((float(index) + 0.5) / float(maxi(count, 1)), 0.72)
	var offset := Vector2(cos(angle) * pile_radius.x, sin(angle) * pile_radius.y) * ring
	offset += Vector2(
		lerpf(-1.8, 1.8, float((index * 3) % 7) / 6.0),
		lerpf(-1.2, 1.2, float((index * 5) % 7) / 6.0)
	)
	return Vector2(
		clampf(deposit_center.x + offset.x, -half_extents.x, half_extents.x),
		clampf(deposit_center.y + offset.y, -half_extents.y, half_extents.y)
	)


func _seasoning_attribute_seed(attr: String) -> int:
	var seed := 0
	for i in range(attr.length()):
		seed += attr.unicode_at(i) * (i + 3)
	return seed


func _update_seasoning_visual_effects(delta: float) -> void:
	if _seasoning_visual_effects.is_empty():
		return
	for i in range(_seasoning_visual_effects.size() - 1, -1, -1):
		var effect := _seasoning_visual_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_seasoning_visual_effects.remove_at(i)
			continue
		var life := float(effect.get_meta(PRODUCT_SEASONING_VISUAL_LIFE_META, 0.0)) + maxf(delta, 0.0)
		var max_life := float(effect.get_meta(PRODUCT_SEASONING_VISUAL_MAX_LIFE_META, 0.75))
		var kind := String(effect.get_meta(PRODUCT_SEASONING_VISUAL_KIND_META, ""))
		var velocity := effect.get_meta(PRODUCT_SEASONING_VISUAL_VELOCITY_META, Vector2.ZERO) as Vector2
		var phase := float(effect.get_meta(PRODUCT_SEASONING_VISUAL_PHASE_META, 0.0))
		var phase_speed := float(effect.get_meta(PRODUCT_SEASONING_VISUAL_PHASE_SPEED_META, 2.0))
		phase += delta * phase_speed
		effect.set_meta(PRODUCT_SEASONING_VISUAL_PHASE_META, phase)
		effect.set_meta(PRODUCT_SEASONING_VISUAL_LIFE_META, life)
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		if kind == "impact":
			velocity.y += 90.0 * delta
			effect.set_meta(PRODUCT_SEASONING_VISUAL_VELOCITY_META, velocity)
			effect.position += Vector2(velocity.x + sin(phase) * 4.0, velocity.y) * delta
			effect.rotation += delta * (2.6 + phase_speed)
		else:
			effect.position += Vector2(velocity.x + sin(phase) * 5.0, velocity.y) * delta
		var base_scale := float(effect.get_meta(PRODUCT_SEASONING_VISUAL_BASE_SCALE_META, 0.1))
		if kind == "impact":
			effect.scale = Vector2.ONE * base_scale * lerpf(1.08, 0.68, progress)
		else:
			effect.scale = Vector2.ONE * base_scale * lerpf(0.88, 1.46, progress)
		var sprite := effect.get_node_or_null("Sprite") as Sprite2D
		if sprite != null:
			var color := _seasoning_visual_color(attribute, kind)
			sprite.modulate.a = color.a * (1.0 - progress)
		if life >= max_life:
			_seasoning_visual_effects.remove_at(i)
			effect.queue_free()


func set_color(c: Color) -> void:
	_pending_color = c
	_doneness.set_raw_color(c)
	if is_node_ready():
		_apply_base_color(c)


func set_art_texture(texture: Texture2D) -> void:
	_pending_art_texture = texture
	if is_node_ready():
		_apply_art_texture()


func set_item(key: String, item_data: Dictionary, profiles: Dictionary = {}) -> void:
	setup_item(key, item_data, profiles)


func setup_item(key: String, item_data: Dictionary, profiles: Dictionary = {}) -> void:
	item_key = key
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	set_art_texture(null)
	var rgb: Array = item_data.get("color", [0.8, 0.8, 0.8])
	set_color(Color(rgb[0], rgb[1], rgb[2]))
	var source_profiles := _merge_with_fallback_profiles(profiles)
	var physics_id: String = item_data.get("physics_profile", "default")
	var collision_id: String = item_data.get("collision_profile", "default_box")
	var feedback_id: String = item_data.get("feedback_profile", "default")
	apply_physics_profile(_resolve_profile(source_profiles, "physics", physics_id, "default"))
	apply_collision_profile(_resolve_profile(source_profiles, "collision", collision_id, "default_box"))
	apply_feedback_profile(_resolve_profile(source_profiles, "feedback", feedback_id, "default"))


func apply_physics_profile(profile: Dictionary) -> void:
	mass = _clamp_profile_value(profile, "mass", 1.0)
	linear_damp = _clamp_profile_value(profile, "linear_damp", 0.2)
	angular_damp = _clamp_profile_value(profile, "angular_damp", 0.2)
	gravity_scale = _clamp_profile_value(profile, "gravity_scale", 1.0)
	var mat := PhysicsMaterial.new()
	mat.friction = _clamp_profile_value(profile, "friction", 0.6)
	mat.bounce = _clamp_profile_value(profile, "bounce", 0.25)
	physics_material_override = mat


func apply_collision_profile(profile: Dictionary) -> void:
	var collision_shape := _shape if is_node_ready() else get_node_or_null("Shape") as CollisionShape2D
	if collision_shape == null:
		return
	var offset := _array_to_vector2(profile.get("offset", [0, 0]), Vector2.ZERO)
	collision_shape.position = offset
	var shape_type: String = profile.get("shape", "rect")
	match shape_type:
		"circle":
			var circle := CircleShape2D.new()
			circle.radius = clampf(float(profile.get("radius", 20.0)), 4.0, 80.0)
			collision_shape.shape = circle
			_set_visual_circle(circle.radius)
		"capsule":
			var capsule := CapsuleShape2D.new()
			capsule.radius = clampf(float(profile.get("radius", 10.0)), 4.0, 80.0)
			capsule.height = clampf(float(profile.get("height", 54.0)), capsule.radius * 2.0, 160.0)
			collision_shape.shape = capsule
			_set_visual_capsule(capsule.radius, capsule.height)
		_:
			var rect := RectangleShape2D.new()
			rect.size = _array_to_vector2(profile.get("size", [40, 40]), Vector2(40, 40)).clamp(Vector2(4, 4), Vector2(160, 160))
			collision_shape.shape = rect
			_set_visual_rect(rect.size)
	_remember_profile_collision()


func apply_feedback_profile(profile: Dictionary) -> void:
	feedback_profile = profile.duplicate(true)


func down_face_index() -> int:
	return MEAT_DONENESS.down_face_of(_face_top.global_position, _face_bottom.global_position)


func add_heat(face: int, amount: float) -> void:
	if _pending_art_texture != null:
		set_art_texture(null)
	_doneness.add_heat(face, amount)
	_refresh_face_colors()


func grill_result() -> String:
	return _doneness.result()


func _apply_base_color(c: Color) -> void:
	if not is_node_ready():
		return
	_visual_top.color = c
	_visual_bottom.color = c


func _refresh_face_colors() -> void:
	if not is_node_ready():
		return
	_visual_top.color = _doneness.face_color(0)
	_visual_bottom.color = _doneness.face_color(1)


func _merge_with_fallback_profiles(profiles: Dictionary) -> Dictionary:
	var merged := FALLBACK_PROFILES.duplicate(true)
	for section in profiles.keys():
		if profiles[section] is Dictionary:
			if not merged.has(section):
				merged[section] = {}
			for key in profiles[section].keys():
				merged[section][key] = profiles[section][key]
	return merged


func _resolve_profile(profiles: Dictionary, section: String, profile_id: String, default_id: String) -> Dictionary:
	var section_data: Dictionary = profiles.get(section, {})
	if section_data.has(profile_id) and section_data[profile_id] is Dictionary:
		return section_data[profile_id]
	if profile_id != default_id:
		push_warning("[DeskItem] Unknown %s profile: %s, using %s" % [section, profile_id, default_id])
	return section_data.get(default_id, {})


func _clamp_profile_value(profile: Dictionary, key: String, default_value: float) -> float:
	var limits: Vector2 = PHYSICS_LIMITS.get(key, Vector2(-INF, INF))
	return clampf(float(profile.get(key, default_value)), limits.x, limits.y)


func _array_to_vector2(value, fallback: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _set_visual_rect(size: Vector2) -> void:
	var half := size * 0.5
	var top_poly := PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, 0.0),
		Vector2(-half.x, 0.0)
	])
	var bottom_poly := PackedVector2Array([
		Vector2(-half.x, 0.0),
		Vector2(half.x, 0.0),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	_apply_split_polygons(top_poly, bottom_poly)


func _set_visual_circle(radius: float) -> void:
	var points_top := PackedVector2Array()
	var points_bottom := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		var p := Vector2(cos(a), sin(a)) * radius
		if p.y <= 0.0:
			points_top.append(p)
		else:
			points_bottom.append(p)
	points_top.append(Vector2(radius, 0.0))
	points_top.append(Vector2(-radius, 0.0))
	points_bottom.append(Vector2(-radius, 0.0))
	points_bottom.append(Vector2(radius, 0.0))
	_apply_split_polygons(points_top, points_bottom)


func _set_visual_capsule(radius: float, height: float) -> void:
	var half_body := maxf((height * 0.5) - radius, 0.0)
	var points_top := PackedVector2Array()
	var points_bottom := PackedVector2Array()
	for i in range(8):
		var a := PI + PI * float(i) / 7.0
		points_top.append(Vector2(cos(a) * radius, -half_body + sin(a) * radius))
	for i in range(8):
		var a := PI * float(i) / 7.0
		points_bottom.append(Vector2(cos(a) * radius, half_body + sin(a) * radius))
	_apply_split_polygons(points_top, points_bottom)


func _apply_split_polygons(top_poly: PackedVector2Array, bottom_poly: PackedVector2Array) -> void:
	if is_node_ready():
		_visual_top.polygon = top_poly
		_visual_bottom.polygon = bottom_poly
		_apply_icon_art_scale()
	else:
		var top := get_node_or_null("VisualTop") as Polygon2D
		var bot := get_node_or_null("VisualBottom") as Polygon2D
		if top != null:
			top.polygon = top_poly
		if bot != null:
			bot.polygon = bottom_poly


func _ensure_icon_art() -> void:
	_icon_art = get_node_or_null("IconArt") as Sprite2D
	if _icon_art != null:
		return
	_icon_art = Sprite2D.new()
	_icon_art.name = "IconArt"
	_icon_art.centered = true
	_icon_art.visible = false
	_icon_art.z_index = 1
	_icon_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_icon_art)


func _apply_art_texture() -> void:
	_ensure_icon_art()
	_icon_art.texture = _pending_art_texture
	var has_art := _pending_art_texture != null
	_icon_art.visible = has_art
	_visual_top.visible = not has_art
	_visual_bottom.visible = not has_art
	_apply_icon_art_scale()
	if has_art:
		_apply_art_collision_bounds()
	else:
		_restore_profile_collision()


func _apply_icon_art_scale() -> void:
	if _icon_art == null or _icon_art.texture == null:
		return
	_icon_art.scale = Vector2.ONE * ART_TEXTURE_SCALE


func _remember_profile_collision() -> void:
	var collision_shape := _shape if is_node_ready() else get_node_or_null("Shape") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return
	_profile_collision_shape = collision_shape.shape.duplicate()
	_profile_collision_position = collision_shape.position
	_art_collision_active = false


func _restore_profile_collision() -> void:
	if not _art_collision_active or _profile_collision_shape == null:
		return
	_shape.shape = _profile_collision_shape.duplicate()
	_shape.position = _profile_collision_position
	_art_collision_active = false


func _apply_art_collision_bounds() -> void:
	if _icon_art == null or _icon_art.texture == null:
		return
	var polygon := TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_convex_polygon(_icon_art)
	if polygon.size() >= 3:
		var convex := ConvexPolygonShape2D.new()
		convex.points = polygon
		_shape.shape = convex
		_shape.position = Vector2.ZERO
		_art_collision_active = true
		return
	var art_bounds: Rect2 = TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(_icon_art)
	if art_bounds.size == Vector2.ZERO:
		return
	var rect := RectangleShape2D.new()
	rect.size = art_bounds.size
	_shape.shape = rect
	_shape.position = art_bounds.get_center()
	_art_collision_active = true
