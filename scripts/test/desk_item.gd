class_name DeskItem
extends RigidBody2D

const KILL_Y: float = 800.0
const IMPACT_DEBUG_SPEED: float = 260.0
const MEAT_DONENESS := preload("res://scripts/systems/meat_doneness.gd")

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
var is_held: bool = false
var feedback_profile: Dictionary = {}
var _pending_color: Color = Color.WHITE
var _doneness = MEAT_DONENESS.new()

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
	_apply_base_color(_pending_color)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	if global_position.y > KILL_Y and not _fell_emitted:
		_fell_emitted = true
		fell_out_of_bounds.emit(self)


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


func set_color(c: Color) -> void:
	_pending_color = c
	_doneness.set_raw_color(c)
	if is_node_ready():
		_apply_base_color(c)


func set_item(key: String, item_data: Dictionary, profiles: Dictionary = {}) -> void:
	setup_item(key, item_data, profiles)


func setup_item(key: String, item_data: Dictionary, profiles: Dictionary = {}) -> void:
	item_key = key
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
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


func apply_feedback_profile(profile: Dictionary) -> void:
	feedback_profile = profile.duplicate(true)


func down_face_index() -> int:
	return MEAT_DONENESS.down_face_of(_face_top.global_position, _face_bottom.global_position)


func add_heat(face: int, amount: float) -> void:
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
	else:
		var top := get_node_or_null("VisualTop") as Polygon2D
		var bot := get_node_or_null("VisualBottom") as Polygon2D
		if top != null:
			top.polygon = top_poly
		if bot != null:
			bot.polygon = bottom_poly
