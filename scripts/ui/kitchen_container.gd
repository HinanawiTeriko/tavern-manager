class_name KitchenContainer
extends RigidBody2D

signal recipe_consumed(product_key: String)

const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const COOK_STATION_STATE := preload("res://scripts/systems/cook_station_state.gd")
const TEXTURE_COLLISION_BOUNDS := preload("res://scripts/ui/texture_collision_bounds.gd")
const PHYSICS_MOTION_TRAIL := preload("res://scripts/ui/physics_motion_trail.gd")
const GRILL_VAPOR_LAYER_NAME := "GrillVaporLayer"
const GRILL_VAPOR_LAYER_Z_INDEX := 17
const GRILL_VAPOR_SPAWN_INTERVAL := 0.09
const GRILL_VAPOR_MAX_ACTIVE := 44
const GRILL_VAPOR_OFFSCREEN_Y := -10.0
const GRILL_VAPOR_TEXTURE_PATH := "res://assets/textures/grill_vapor/grill_vapor.png"
const GRILL_VAPOR_SLOT_SIZE := Vector2(64.0, 112.0)
const GRILL_VAPOR_VARIANT_COUNT := 4
const GRILL_VAPOR_VELOCITY_META := "grill_vapor_velocity"
const GRILL_VAPOR_PHASE_META := "grill_vapor_phase"
const GRILL_VAPOR_PHASE_SPEED_META := "grill_vapor_phase_speed"
const GRILL_VAPOR_LIFE_META := "grill_vapor_life"
const GRILL_VAPOR_MAX_LIFE_META := "grill_vapor_max_life"
const GRILL_VAPOR_QUALITY_META := "grill_vapor_quality"
const GRILL_VAPOR_VARIANT_META := "grill_vapor_variant"
const GRILL_FEEDBACK_LAYER_NAME := "GrillFeedbackLayer"
const GRILL_FEEDBACK_LAYER_Z_INDEX := 20
const GRILL_FEEDBACK_MAX_ACTIVE := 44
const GRILL_FEEDBACK_OFFSCREEN_Y := -10.0
const GRILL_FEEDBACK_TEXTURE_PATH := "res://assets/textures/grill_feedback/grill_feedback.png"
const GRILL_FEEDBACK_SLOT_SIZE := Vector2(192.0, 160.0)
const GRILL_FEEDBACK_VARIANT_COUNT := 4
const GRILL_PRESS_SPARK_INTERVAL := 0.12
const GRILL_BURN_WARNING_RATIO := 0.72
const GRILL_FEEDBACK_ELEMENT_META := "grill_feedback_element"
const GRILL_FEEDBACK_WORD_META := "grill_feedback_word"
const GRILL_FEEDBACK_VELOCITY_META := "grill_feedback_velocity"
const GRILL_FEEDBACK_PHASE_META := "grill_feedback_phase"
const GRILL_FEEDBACK_PHASE_SPEED_META := "grill_feedback_phase_speed"
const GRILL_FEEDBACK_LIFE_META := "grill_feedback_life"
const GRILL_FEEDBACK_MAX_LIFE_META := "grill_feedback_max_life"
const GRILL_FEEDBACK_BASE_SCALE_META := "grill_feedback_base_scale"
const GRILL_FEEDBACK_FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const GRILL_DONE_WORDS := ["ZILA!", "PERFECT!", "SO GOOD", "SERVE IT!"]
const GRILL_WARNING_WORDS := ["BURNING!", "GRAB IT!", "DANGER!"]
const GRILL_BURNT_WORDS := ["BURNT!", "CHARRED!", "DARK COOK"]
const POT_EFFECT_LAYER_NAME := "PotEffectLayer"
const POT_EFFECT_LAYER_Z_INDEX := 18
const POT_EFFECT_TEXTURE_PATH := "res://assets/textures/pot_effects/pot_effects.png"
const POT_EFFECT_SLOT_SIZE := Vector2(80.0, 96.0)
const POT_EFFECT_VARIANT_COUNT := 4
const POT_EFFECT_MAX_ACTIVE := 160
const POT_EFFECT_OFFSCREEN_Y := -10.0
const POT_SIMMER_INTERVAL := 0.62
const POT_STIR_EFFECT_THRESHOLD := 4.0
const POT_STIR_SNAP_DISTANCE := 60.0
const POT_EFFECT_VELOCITY_META := "pot_effect_velocity"
const POT_EFFECT_PHASE_META := "pot_effect_phase"
const POT_EFFECT_PHASE_SPEED_META := "pot_effect_phase_speed"
const POT_EFFECT_LIFE_META := "pot_effect_life"
const POT_EFFECT_MAX_LIFE_META := "pot_effect_max_life"
const POT_EFFECT_KIND_META := "pot_effect_kind"
const POT_EFFECT_ELEMENT_META := "pot_effect_element"
const POT_EFFECT_VARIANT_META := "pot_effect_variant"
const POT_EFFECT_BASE_SCALE_META := "pot_effect_base_scale"
const POT_FAILURE_FEEDBACK_LAYER_NAME := "PotFailureFeedback"
const POT_FAILURE_FEEDBACK_LAYER_Z_INDEX := 20
const POT_FAILURE_FEEDBACK_OFFSCREEN_Y := -10.0
const POT_FAILURE_FEEDBACK_KIND_META := "pot_failure_feedback_kind"
const POT_FAILURE_FEEDBACK_VELOCITY_META := "pot_failure_feedback_velocity"
const POT_FAILURE_FEEDBACK_PHASE_META := "pot_failure_feedback_phase"
const POT_FAILURE_FEEDBACK_PHASE_SPEED_META := "pot_failure_feedback_phase_speed"
const POT_FAILURE_FEEDBACK_LIFE_META := "pot_failure_feedback_life"
const POT_FAILURE_FEEDBACK_MAX_LIFE_META := "pot_failure_feedback_max_life"
const POT_FAILURE_FEEDBACK_BASE_SCALE_META := "pot_failure_feedback_base_scale"
const POT_WALL_COLLISION_THICKNESS := 14.0
const POT_RIM_COLLISION_THICKNESS := 10.0
const POT_BOTTOM_COLLISION_THICKNESS := 24.0
const POT_BOTTOM_COLLISION_INSET := 6.0
const POT_MAX_INGREDIENTS := 2

@export_enum("grill", "pot") var container_key: String = "grill"
@export var cook_time: float = 2.5
@export var burn_time: float = 5.0
@export var required_stir: float = 750.0
@export var stir_scale: float = 1.0
@export var intake_inner_half_width: float = 43.0
@export var intake_top_y: float = -59.0
@export var intake_bottom_y: float = -17.0
# 搅拌判定区：比进料口更宽更深，覆盖整个锅内部，让勺尖伸进汤里搅也算数。
@export var stir_zone_half_width: float = 44.0
@export var stir_zone_top_y: float = -59.0
@export var stir_zone_bottom_y: float = 40.0
# —— 烤架按压煎制 ——
@export var heat_rate: float = 1.0
@export var held_heat_multiplier: float = 2.25
@export var passive_vapor_rate: float = 0.5
@export var held_vapor_rate: float = 0.95

@onready var _intake: Area2D = $Intake
@onready var _output_anchor: Marker2D = $OutputAnchor
@onready var _sear_zone: Area2D = get_node_or_null("SearZone")
@onready var _art: Sprite2D = get_node_or_null("Art")

var _items_parent: Node2D = null
var _state = COOK_STATION_STATE.new()
var _stir_tracking: bool = false
var _prev_tip_pos: Vector2 = Vector2.ZERO
var _searing_bodies: Array = []   # 上一帧在烤区内的肉,用于检测离开
var _grill_elapsed_by_item: Dictionary = {}
var _last_stir_audio_msec: int = -1000
var _grill_vapor_layer: Node2D = null
var _grill_vapors: Array[Node2D] = []
var _grill_vapor_spawn_elapsed: float = 0.0
var _grill_vapor_texture: Texture2D = null
var _grill_feedback_layer: Node2D = null
var _grill_feedbacks: Array[Node2D] = []
var _grill_press_spark_elapsed: float = 0.0
var _grill_warning_elapsed_by_item: Dictionary = {}
var _grill_feedback_texture: Texture2D = null
var _pot_effect_layer: Node2D = null
var _pot_effects: Array[Node2D] = []
var _pot_failure_feedback_layer: Node2D = null
var _pot_failure_feedbacks: Array[Node2D] = []
var _pot_simmer_elapsed: float = 0.0
var _pot_effect_texture: Texture2D = null
var _motion_trail = PHYSICS_MOTION_TRAIL.new()


func _ready() -> void:
	set_process(true)
	set_physics_process(true)
	assert(GameManager.craft != null, "[KitchenContainer] GameManager.craft is not ready")
	_items_parent = get_parent().get_node("Items")
	assert(_items_parent != null, "[KitchenContainer] Missing sibling Items node")
	_configure_state()
	mass = 2.0
	gravity_scale = 1.0
	linear_damp = 0.8
	angular_damp = 4.0
	lock_rotation = false
	# 锅是固定灶台：冻结成静态，勺子搅拌时才有稳定对象，不会被勺子推跑。
	if container_key == "pot":
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
	_fit_collision_to_art_bounds()
	# Intake「吞料」是炖锅机制；烤架只靠 SearZone 按压煎制，不该吞掉放上去的生料。
	if container_key == "pot":
		_intake.body_entered.connect(_on_intake_body_entered)


func _process(delta: float) -> void:
	_update_container_motion_trail(delta)


func _physics_process(delta: float) -> void:
	if container_key == "pot":
		for body in _intake.get_overlapping_bodies():
			if body is StirSpoon:
				_accumulate_stir(body, delta)
			else:
				_try_accept_body(body)
		if _pot_has_ingredients() and not _state.is_ready():
			_try_spawn_pot_simmer(delta)
		else:
			_pot_simmer_elapsed = 0.0
		if _state.is_ready():
			_finish_current(GameManager.craft.query_recipe(container_key, _state.ingredients()))
		_update_pot_effects(delta)
		_update_pot_failure_feedbacks(delta)
		return

	# grill: 按压煎制
	_process_grill_sear(delta)
	_update_grill_vapors(delta)
	_update_grill_feedbacks(delta)


## 抓取时解冻。锅释放后重新冻结，避免搅拌时被勺子推走。
func begin_action_session() -> void:
	sleeping = false
	freeze = false


func end_action_session() -> void:
	if container_key == "pot":
		freeze = true


## 勺尖在锅内时，按勺尖的"移动距离"累积搅拌进度——比读物理速度稳，
## 不受勺子被锅壁约束影响（料为空时 add_stir 自动忽略）。
func _update_container_motion_trail(delta: float) -> void:
	_motion_trail.update(
		self,
		delta,
		_art,
		_container_motion_trail_fallback_polygon(),
		_container_motion_trail_tint()
	)


func _container_motion_trail_tint() -> Color:
	if container_key == "pot":
		return Color(0.30, 0.53, 0.62, 1.0)
	return Color(0.80, 0.34, 0.18, 1.0)


func _container_motion_trail_fallback_polygon() -> PackedVector2Array:
	if container_key == "pot":
		return PackedVector2Array([
			Vector2(-50.0, 40.0),
			Vector2(-42.0, -42.0),
			Vector2(42.0, -42.0),
			Vector2(50.0, 40.0),
		])
	return PackedVector2Array([
		Vector2(-75.0, 18.0),
		Vector2(75.0, 18.0),
		Vector2(68.0, -18.0),
		Vector2(-68.0, -18.0),
	])


func _accumulate_stir(spoon: StirSpoon, _delta: float) -> void:
	var tip: Vector2 = spoon.tip_global_position()
	if not _is_point_inside_stir_zone(tip):
		_stir_tracking = false
		return
	if not _stir_tracking:
		_stir_tracking = true
		_prev_tip_pos = tip
		return
	var moved: float = tip.distance_to(_prev_tip_pos)
	_prev_tip_pos = tip
	if moved > POT_STIR_SNAP_DISTANCE:   # 防瞬移/抓取跳变造成的尖峰
		return
	var has_ingredients := _pot_has_ingredients()
	_state.add_stir(moved * stir_scale)
	if moved > POT_STIR_EFFECT_THRESHOLD and has_ingredients:
		_spawn_pot_stir_effects(moved)
		if Time.get_ticks_msec() - _last_stir_audio_msec >= 180:
			_last_stir_audio_msec = Time.get_ticks_msec()
			GameManager.play_audio_event("pot_stir")


## 烤架：被抓着且贴在 SearZone 内的物品累计时间，到阈值直接切换物品状态。
func _process_grill_sear(delta: float) -> void:
	if _sear_zone == null:
		return
	var active_searing: Array = []
	for body in _sear_zone.get_overlapping_bodies():
		if not body is DeskItem:
			continue
		var item: DeskItem = body
		if not can_sear_item_key(item.item_key):
			continue
		active_searing.append(item)
		if not _searing_bodies.has(item):
			GameManager.play_audio_event("grill_sizzle")
		var is_pressed := item.is_held
		var cook_delta := delta * maxf(heat_rate, 0.0)
		if is_pressed:
			cook_delta *= maxf(held_heat_multiplier, 1.0)
		_try_spawn_grill_vapor(item, delta, is_pressed)
		if is_pressed:
			_try_spawn_grill_press_feedback(item, delta)
		_try_spawn_grill_burn_warning(item)
		_advance_grill_item(item, cook_delta)
	_searing_bodies = active_searing
	_prune_grill_elapsed_items()


## 烤制进度只改状态，不再驱动物品逐帧变色。
func _advance_grill_item(item: DeskItem, delta: float) -> void:
	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
		return
	var elapsed := float(_grill_elapsed_by_item.get(item, 0.0)) + maxf(delta, 0.0)
	_grill_elapsed_by_item[item] = elapsed
	var product_key := _grill_product_for_elapsed(item.item_key, elapsed)
	if product_key == "":
		return
	_apply_grill_product_state(item, product_key)
	_grill_elapsed_by_item[item] = 0.0


func _grill_product_for_elapsed(item_key: String, elapsed: float) -> String:
	if elapsed < _grill_threshold_for_item(item_key):
		return ""
	if item_key == "meat_cooked" or item_key == "bread":
		return _burnt_key_for(item_key)
	return GameManager.craft.query_recipe("grill", [item_key])


func _grill_threshold_for_item(item_key: String) -> float:
	if item_key == "meat_cooked" or item_key == "bread":
		return maxf(burn_time - cook_time, 0.0)
	return cook_time


func _apply_grill_product_state(item: DeskItem, product_key: String) -> void:
	if container_key == "grill" and product_key.ends_with("_burnt"):
		_spawn_grill_vapor_burst(item.global_position, "char", 4)
		_spawn_grill_burnt_feedback(item.global_position)
	elif container_key == "grill" and product_key != "":
		_spawn_grill_done_feedback(item.global_position, product_key)
	var data: Dictionary = GameManager.craft.get_item(product_key)
	item.set_item(product_key, data, GameManager.craft.get_item_physics_profiles())
	GameManager.apply_material_icon_to_desk_item(item)
	recipe_consumed.emit(product_key)


func _prune_grill_elapsed_items() -> void:
	for item in _grill_elapsed_by_item.keys():
		if not is_instance_valid(item) or item.is_queued_for_deletion():
			_grill_elapsed_by_item.erase(item)
	for item in _grill_warning_elapsed_by_item.keys():
		if not is_instance_valid(item) or item.is_queued_for_deletion():
			_grill_warning_elapsed_by_item.erase(item)


func _try_spawn_grill_press_feedback(item: DeskItem, delta: float) -> void:
	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
		return
	_grill_press_spark_elapsed += maxf(delta, 0.0)
	if _grill_press_spark_elapsed < GRILL_PRESS_SPARK_INTERVAL:
		return
	_grill_press_spark_elapsed = 0.0
	_spawn_grill_heat_glow(item.global_position)
	var spark_count := 2
	for i in range(spark_count):
		_spawn_grill_feedback_spark("press_spark", item.global_position, i, spark_count, false)
	if randf() < 0.12:
		_spawn_grill_flame_feedback(item.global_position)


func _try_spawn_grill_burn_warning(item: DeskItem) -> void:
	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
		return
	if item.item_key != "meat_cooked" and item.item_key != "bread":
		return
	var threshold := _grill_threshold_for_item(item.item_key)
	if threshold <= 0.0:
		return
	var elapsed := float(_grill_elapsed_by_item.get(item, 0.0))
	if elapsed / threshold < GRILL_BURN_WARNING_RATIO:
		return
	var last_warning_elapsed := float(_grill_warning_elapsed_by_item.get(item, -999.0))
	if elapsed - last_warning_elapsed < threshold * 0.34:
		return
	_grill_warning_elapsed_by_item[item] = elapsed
	var word: String = String(GRILL_WARNING_WORDS[randi_range(0, GRILL_WARNING_WORDS.size() - 1)])
	_spawn_grill_feedback_word(
		"burn_warning",
		item.global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-58.0, -42.0)),
		word,
		Color(1.0, 0.36, 0.12, 1.0),
		23,
		1.0
	)
	_spawn_grill_feedback_spark("char_spark", item.global_position, 0, 1, true)


func _spawn_grill_done_feedback(origin: Vector2, _product_key: String) -> void:
	_spawn_grill_heat_glow(origin)
	var word: String = String(GRILL_DONE_WORDS[randi_range(0, GRILL_DONE_WORDS.size() - 1)])
	_spawn_grill_feedback_word(
		"done_word",
		origin + Vector2(randf_range(-10.0, 10.0), randf_range(-60.0, -44.0)),
		word,
		Color(1.0, 0.82, 0.22, 1.0),
		24,
		randf_range(0.96, 1.12)
	)
	for i in range(5):
		_spawn_grill_feedback_spark("done_spark", origin, i, 5, false)
	_spawn_grill_flame_feedback(origin)


func _spawn_grill_burnt_feedback(origin: Vector2) -> void:
	var word: String = String(GRILL_BURNT_WORDS[randi_range(0, GRILL_BURNT_WORDS.size() - 1)])
	_spawn_grill_feedback_word(
		"burnt_word",
		origin + Vector2(randf_range(-10.0, 10.0), randf_range(-62.0, -46.0)),
		word,
		Color(0.78, 0.70, 0.58, 1.0),
		23,
		randf_range(0.9, 1.04)
	)
	for i in range(5):
		_spawn_grill_feedback_spark("char_spark", origin, i, 5, true)
	_spawn_grill_flame_feedback(origin)


func _spawn_grill_heat_glow(origin: Vector2) -> void:
	var effect := _new_grill_feedback_effect(
		"press_glow",
		origin + Vector2(0.0, randf_range(12.0, 18.0)),
		Vector2.ZERO,
		randf_range(0.18, 0.26),
		randf_range(0.60, 0.76),
		-2
	)
	if effect == null:
		return
	_build_grill_feedback_sprite(effect, "heat_glow")


func _spawn_grill_feedback_spark(element: String, origin: Vector2, index: int, count: int, charred: bool) -> void:
	var slot := (float(index) + randf_range(0.12, 0.88)) / float(maxi(count, 1))
	var angle := lerpf(-PI * 0.92, -PI * 0.08, slot)
	if charred:
		angle = lerpf(-PI * 0.98, -PI * 0.02, slot)
	var is_transition := element == "done_spark" or charred
	var distance := randf_range(16.0, 30.0)
	if is_transition:
		distance = randf_range(24.0, 42.0)
	var offset := Vector2(cos(angle), sin(angle)) * distance + Vector2(randf_range(-6.0, 6.0), randf_range(-16.0, -5.0))
	var speed := randf_range(46.0, 96.0)
	if charred:
		speed = randf_range(34.0, 70.0)
	var velocity := Vector2(cos(angle) * speed * randf_range(0.55, 0.95), sin(angle) * speed)
	var effect := _new_grill_feedback_effect(
		element,
		origin + offset,
		velocity,
		randf_range(0.28, 0.52) if not charred else randf_range(0.42, 0.68),
		randf_range(0.60, 0.92) if not charred else randf_range(0.68, 1.00),
		5
	)
	if effect == null:
		return
	_build_grill_feedback_sprite(effect, "char_spark" if charred else _grill_spark_visual_element(element))


func _spawn_grill_flame_feedback(origin: Vector2) -> void:
	var effect := _new_grill_feedback_effect(
		"flame",
		origin + Vector2(randf_range(-18.0, 18.0), randf_range(-30.0, -14.0)),
		Vector2(randf_range(-12.0, 12.0), -randf_range(34.0, 58.0)),
		randf_range(0.30, 0.50),
		randf_range(0.62, 0.88),
		7
	)
	if effect == null:
		return
	_build_grill_feedback_sprite(effect, "flame")


func _new_grill_feedback_effect(
	element: String,
	origin: Vector2,
	velocity: Vector2,
	max_life: float,
	base_scale: float,
	z_index: int
) -> Node2D:
	_prune_invalid_grill_feedbacks()
	if _grill_feedbacks.size() >= GRILL_FEEDBACK_MAX_ACTIVE:
		return null
	var layer := _ensure_grill_feedback_layer()
	var effect := Node2D.new()
	effect.name = "GrillFeedback"
	if element == "press_glow":
		effect.name = "GrillHeatGlow"
	elif element.ends_with("spark"):
		effect.name = "GrillSpark"
	elif element.ends_with("word") or element == "burn_warning":
		effect.name = "GrillFeedbackWord"
	effect.z_index = z_index
	effect.scale = Vector2.ONE * base_scale
	effect.set_meta(GRILL_FEEDBACK_ELEMENT_META, element)
	effect.set_meta(GRILL_FEEDBACK_VELOCITY_META, velocity)
	effect.set_meta(GRILL_FEEDBACK_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(GRILL_FEEDBACK_PHASE_SPEED_META, randf_range(1.1, 3.0))
	effect.set_meta(GRILL_FEEDBACK_LIFE_META, 0.0)
	effect.set_meta(GRILL_FEEDBACK_MAX_LIFE_META, max_life)
	effect.set_meta(GRILL_FEEDBACK_BASE_SCALE_META, base_scale)
	layer.add_child(effect)
	effect.global_position = origin
	_grill_feedbacks.append(effect)
	return effect


func _spawn_grill_feedback_word(
	element: String,
	origin: Vector2,
	word: String,
	color: Color,
	font_size: int,
	base_scale: float
) -> void:
	var effect := _new_grill_feedback_effect(
		element,
		origin,
		Vector2(randf_range(-12.0, 12.0), -randf_range(46.0, 78.0)),
		randf_range(0.82, 1.12),
		base_scale,
		12
	)
	if effect == null:
		return
	effect.set_meta(GRILL_FEEDBACK_WORD_META, word)
	var label := Label.new()
	label.name = "Label"
	label.text = word
	label.size = Vector2(144.0, 38.0)
	label.position = Vector2(-72.0, -19.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GRILL_FEEDBACK_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.025, 0.008, 0.94))
	effect.add_child(label)


func _build_grill_feedback_sprite(effect: Node2D, visual_element: String) -> void:
	var texture := _load_grill_feedback_texture()
	if texture == null:
		return
	var variant := randi_range(0, GRILL_FEEDBACK_VARIANT_COUNT - 1)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		Vector2(
			float(variant) * GRILL_FEEDBACK_SLOT_SIZE.x,
			float(_grill_feedback_region_row(visual_element)) * GRILL_FEEDBACK_SLOT_SIZE.y
		),
		GRILL_FEEDBACK_SLOT_SIZE
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * _grill_feedback_sprite_scale(visual_element)
	sprite.flip_h = randf() > 0.5
	sprite.modulate = Color(1.0, 1.0, 1.0, _grill_feedback_sprite_alpha(visual_element))
	effect.rotation = randf_range(-0.7, 0.7)
	effect.add_child(sprite)


func _grill_spark_visual_element(feedback_element: String) -> String:
	if feedback_element == "done_spark":
		return "done_spark"
	return "oil_spark"


func _grill_feedback_region_row(visual_element: String) -> int:
	if visual_element == "done_spark":
		return 1
	if visual_element == "char_spark":
		return 2
	if visual_element == "heat_glow":
		return 3
	if visual_element == "flame":
		return 4
	return 0


func _grill_feedback_sprite_scale(visual_element: String) -> float:
	if visual_element == "heat_glow":
		return randf_range(0.16, 0.22)
	if visual_element == "flame":
		return randf_range(0.18, 0.25)
	if visual_element == "done_spark":
		return randf_range(0.15, 0.22)
	if visual_element == "char_spark":
		return randf_range(0.16, 0.23)
	return randf_range(0.15, 0.22)


func _grill_feedback_sprite_alpha(visual_element: String) -> float:
	if visual_element == "heat_glow":
		return 0.42
	if visual_element == "flame":
		return 0.72
	if visual_element == "done_spark":
		return 0.82
	if visual_element == "char_spark":
		return 0.72
	return 0.78


func _load_grill_feedback_texture() -> Texture2D:
	if _grill_feedback_texture != null:
		return _grill_feedback_texture
	var imported := TextureManager.try_load(GRILL_FEEDBACK_TEXTURE_PATH)
	if imported != null:
		_grill_feedback_texture = imported
		return _grill_feedback_texture
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(GRILL_FEEDBACK_TEXTURE_PATH))
	if err != OK:
		push_warning("[KitchenContainer] missing grill feedback texture: " + GRILL_FEEDBACK_TEXTURE_PATH)
		return null
	var image_texture := ImageTexture.create_from_image(image)
	image_texture.resource_path = GRILL_FEEDBACK_TEXTURE_PATH
	_grill_feedback_texture = image_texture
	return _grill_feedback_texture


func _ensure_grill_feedback_layer() -> Node2D:
	if _grill_feedback_layer != null and is_instance_valid(_grill_feedback_layer):
		return _grill_feedback_layer
	_grill_feedback_layer = get_node_or_null(GRILL_FEEDBACK_LAYER_NAME) as Node2D
	if _grill_feedback_layer == null:
		_grill_feedback_layer = Node2D.new()
		_grill_feedback_layer.name = GRILL_FEEDBACK_LAYER_NAME
		add_child(_grill_feedback_layer)
	_grill_feedback_layer.top_level = true
	_grill_feedback_layer.global_position = Vector2.ZERO
	_grill_feedback_layer.z_as_relative = false
	_grill_feedback_layer.z_index = GRILL_FEEDBACK_LAYER_Z_INDEX
	return _grill_feedback_layer


func _update_grill_feedbacks(delta: float) -> void:
	if _grill_feedbacks.is_empty():
		return
	for i in range(_grill_feedbacks.size() - 1, -1, -1):
		var effect := _grill_feedbacks[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_grill_feedbacks.remove_at(i)
			continue
		var velocity := effect.get_meta(GRILL_FEEDBACK_VELOCITY_META, Vector2.ZERO) as Vector2
		var phase := float(effect.get_meta(GRILL_FEEDBACK_PHASE_META, 0.0))
		var phase_speed := float(effect.get_meta(GRILL_FEEDBACK_PHASE_SPEED_META, 1.0))
		var life := float(effect.get_meta(GRILL_FEEDBACK_LIFE_META, 0.0)) + maxf(delta, 0.0)
		var max_life := float(effect.get_meta(GRILL_FEEDBACK_MAX_LIFE_META, 0.8))
		var element := String(effect.get_meta(GRILL_FEEDBACK_ELEMENT_META, ""))
		phase += delta * phase_speed
		effect.set_meta(GRILL_FEEDBACK_PHASE_META, phase)
		effect.set_meta(GRILL_FEEDBACK_LIFE_META, life)
		effect.global_position += Vector2(velocity.x + sin(phase) * 5.0, velocity.y) * delta
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		var alpha := clampf(1.0 - progress, 0.0, 1.0)
		var base_scale := float(effect.get_meta(GRILL_FEEDBACK_BASE_SCALE_META, 1.0))
		if element == "press_glow":
			effect.modulate.a = minf(0.55, alpha * 0.75)
			effect.scale = Vector2.ONE * base_scale * lerpf(0.65, 1.05, progress)
		elif element.ends_with("word") or element == "burn_warning":
			effect.modulate.a = minf(1.0, alpha * 1.15)
			effect.scale = Vector2.ONE * base_scale * lerpf(0.88, 1.16, sin(progress * PI))
		else:
			effect.modulate.a = minf(0.85, alpha)
			effect.rotation += delta * (4.0 + phase_speed)
			effect.scale = Vector2.ONE * base_scale * lerpf(0.82, 1.08, sin(progress * PI))
		if effect.global_position.y <= GRILL_FEEDBACK_OFFSCREEN_Y or life >= max_life:
			_grill_feedbacks.remove_at(i)
			effect.queue_free()


func _prune_invalid_grill_feedbacks() -> void:
	for i in range(_grill_feedbacks.size() - 1, -1, -1):
		var effect := _grill_feedbacks[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_grill_feedbacks.remove_at(i)


func _try_spawn_grill_vapor(item: DeskItem, delta: float, is_pressed: bool = false) -> void:
	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
		return
	var spawn_rate := held_vapor_rate if is_pressed else passive_vapor_rate
	_grill_vapor_spawn_elapsed += delta * maxf(spawn_rate, 0.0)
	if _grill_vapor_spawn_elapsed < GRILL_VAPOR_SPAWN_INTERVAL:
		return
	_grill_vapor_spawn_elapsed = 0.0
	_prune_invalid_grill_vapors()
	if _grill_vapors.size() >= GRILL_VAPOR_MAX_ACTIVE:
		return
	var quality := _grill_vapor_quality_for_item(item.item_key)
	_spawn_grill_vapor_burst(item.global_position, quality, _grill_vapor_burst_count(quality, is_pressed))


func _spawn_grill_vapor_burst(origin: Vector2, quality: String, burst_count: int) -> void:
	_prune_invalid_grill_vapors()
	for i in range(burst_count):
		if _grill_vapors.size() >= GRILL_VAPOR_MAX_ACTIVE:
			return
		_spawn_grill_vapor(origin, quality, i, burst_count)


func _spawn_grill_vapor(origin: Vector2, quality: String, burst_index: int, burst_count: int) -> void:
	var layer := _ensure_grill_vapor_layer()
	var vapor := Node2D.new()
	vapor.name = "Vapor"
	vapor.z_index = 0
	vapor.set_meta(GRILL_VAPOR_QUALITY_META, quality)
	var slot_fraction := (float(burst_index) + randf_range(0.15, 0.85)) / float(maxi(burst_count, 1))
	var spread := 18.0 if quality == "char" else 12.0
	var offset := Vector2(
		lerpf(-spread, spread, slot_fraction) + randf_range(-5.0, 5.0),
		randf_range(-32.0, -14.0)
	)
	layer.add_child(vapor)
	vapor.global_position = origin + offset
	var side_speed := 10.0 if quality == "steam" else 14.0
	var rise_speed := randf_range(54.0, 84.0)
	if quality == "smoke":
		rise_speed = randf_range(44.0, 72.0)
	elif quality == "char":
		rise_speed = randf_range(36.0, 66.0)
	vapor.set_meta(GRILL_VAPOR_VELOCITY_META, Vector2(randf_range(-side_speed, side_speed), -rise_speed))
	vapor.set_meta(GRILL_VAPOR_PHASE_META, randf_range(0.0, TAU))
	vapor.set_meta(GRILL_VAPOR_PHASE_SPEED_META, randf_range(1.1, 2.8))
	var max_life := randf_range(0.55, 0.85)
	if quality == "smoke":
		max_life = randf_range(0.65, 0.95)
	if quality == "char":
		max_life = randf_range(0.70, 1.05)
	vapor.set_meta(GRILL_VAPOR_LIFE_META, 0.0)
	vapor.set_meta(GRILL_VAPOR_MAX_LIFE_META, max_life)
	_build_grill_vapor_sprite(vapor, quality)
	_grill_vapors.append(vapor)


func _grill_vapor_quality_for_item(item_key: String) -> String:
	if item_key == "meat_cooked" or item_key == "bread":
		return "smoke"
	return "steam"


func _grill_vapor_burst_count(quality: String, is_pressed: bool = false) -> int:
	if quality == "char":
		return 4 if is_pressed else 3
	if quality == "smoke":
		return 3 if is_pressed else 2
	return 2 if is_pressed else 1


func _grill_vapor_region_row(quality: String) -> int:
	if quality == "char":
		return 2
	if quality == "smoke":
		return 1
	return 0


func _grill_vapor_sprite_scale(quality: String) -> float:
	if quality == "char":
		return randf_range(0.16, 0.23)
	if quality == "smoke":
		return randf_range(0.15, 0.21)
	return randf_range(0.13, 0.18)


func _ensure_grill_vapor_layer() -> Node2D:
	if _grill_vapor_layer != null and is_instance_valid(_grill_vapor_layer):
		return _grill_vapor_layer
	_grill_vapor_layer = get_node_or_null(GRILL_VAPOR_LAYER_NAME) as Node2D
	if _grill_vapor_layer == null:
		_grill_vapor_layer = Node2D.new()
		_grill_vapor_layer.name = GRILL_VAPOR_LAYER_NAME
		add_child(_grill_vapor_layer)
	_grill_vapor_layer.top_level = true
	_grill_vapor_layer.global_position = Vector2.ZERO
	_grill_vapor_layer.z_as_relative = false
	_grill_vapor_layer.z_index = GRILL_VAPOR_LAYER_Z_INDEX
	return _grill_vapor_layer


func _build_grill_vapor_sprite(vapor: Node2D, quality: String) -> void:
	var texture := _load_grill_vapor_texture()
	if texture == null:
		return
	var variant := randi_range(0, GRILL_VAPOR_VARIANT_COUNT - 1)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		Vector2(float(variant) * GRILL_VAPOR_SLOT_SIZE.x, float(_grill_vapor_region_row(quality)) * GRILL_VAPOR_SLOT_SIZE.y),
		GRILL_VAPOR_SLOT_SIZE
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * _grill_vapor_sprite_scale(quality)
	sprite.flip_h = randf() > 0.5
	sprite.modulate = Color(1.0, 1.0, 1.0, _grill_vapor_max_alpha(quality))
	vapor.set_meta(GRILL_VAPOR_VARIANT_META, variant)
	vapor.add_child(sprite)


func _grill_vapor_max_alpha(quality: String) -> float:
	if quality == "char":
		return 0.70
	if quality == "smoke":
		return 0.62
	return 0.56


func _load_grill_vapor_texture() -> Texture2D:
	if _grill_vapor_texture != null:
		return _grill_vapor_texture
	var imported := TextureManager.try_load(GRILL_VAPOR_TEXTURE_PATH)
	if imported != null:
		_grill_vapor_texture = imported
		return _grill_vapor_texture
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(GRILL_VAPOR_TEXTURE_PATH))
	if err != OK:
		push_warning("[KitchenContainer] missing grill vapor texture: " + GRILL_VAPOR_TEXTURE_PATH)
		return null
	var image_texture := ImageTexture.create_from_image(image)
	image_texture.resource_path = GRILL_VAPOR_TEXTURE_PATH
	_grill_vapor_texture = image_texture
	return _grill_vapor_texture


func _update_grill_vapors(delta: float) -> void:
	if _grill_vapors.is_empty():
		return
	for i in range(_grill_vapors.size() - 1, -1, -1):
		var vapor := _grill_vapors[i]
		if vapor == null or not is_instance_valid(vapor) or vapor.is_queued_for_deletion():
			_grill_vapors.remove_at(i)
			continue
		var velocity := vapor.get_meta(GRILL_VAPOR_VELOCITY_META) as Vector2
		var phase := float(vapor.get_meta(GRILL_VAPOR_PHASE_META))
		var phase_speed := float(vapor.get_meta(GRILL_VAPOR_PHASE_SPEED_META))
		var life := float(vapor.get_meta(GRILL_VAPOR_LIFE_META)) + delta
		var max_life := float(vapor.get_meta(GRILL_VAPOR_MAX_LIFE_META))
		phase += delta * phase_speed
		vapor.set_meta(GRILL_VAPOR_PHASE_META, phase)
		vapor.set_meta(GRILL_VAPOR_LIFE_META, life)
		var wander := sin(phase) * 6.0
		vapor.global_position += Vector2(velocity.x + wander, velocity.y) * delta
		var sprite := vapor.get_node_or_null("Sprite") as Sprite2D
		if sprite != null:
			var quality := String(vapor.get_meta(GRILL_VAPOR_QUALITY_META, "steam"))
			var alpha := clampf(1.0 - life / maxf(max_life, 0.01), 0.0, 1.0)
			sprite.modulate.a = minf(_grill_vapor_max_alpha(quality), alpha * 0.75)
		if vapor.global_position.y <= GRILL_VAPOR_OFFSCREEN_Y or life >= max_life:
			_grill_vapors.remove_at(i)
			vapor.queue_free()


func _prune_invalid_grill_vapors() -> void:
	for i in range(_grill_vapors.size() - 1, -1, -1):
		var vapor := _grill_vapors[i]
		if vapor == null or not is_instance_valid(vapor) or vapor.is_queued_for_deletion():
			_grill_vapors.remove_at(i)


func _pot_has_ingredients() -> bool:
	return not _state.ingredients().is_empty()


func _try_spawn_pot_simmer(delta: float) -> void:
	_pot_simmer_elapsed += maxf(delta, 0.0)
	if _pot_simmer_elapsed < POT_SIMMER_INTERVAL:
		return
	_pot_simmer_elapsed = 0.0
	var progress := _pot_stir_ratio()
	if progress >= 0.76:
		_spawn_pot_effect("simmer", "aroma", 0, 2, 0.0)
		_spawn_pot_effect("simmer", "bubble" if randf() < 0.55 else "oil", 1, 2, 0.0)
	elif progress >= 0.42:
		var warm_element := "steam" if randf() < 0.62 else "bubble"
		_spawn_pot_effect("simmer", warm_element, 0, 1, 0.0)
	else:
		var element := "bubble" if randf() < 0.68 else "steam"
		_spawn_pot_effect("simmer", element, 0, 1, 0.0)


func _spawn_pot_stir_effects(moved: float) -> void:
	var burst_count := clampi(int(ceil(moved * 0.75)), 4, 8)
	var sequence := ["ripple", "bubble", "fleck", "steam", "oil", "bubble", "ripple", "fleck"]
	for i in range(burst_count):
		_spawn_pot_effect("stir", String(sequence[i % sequence.size()]), i, burst_count, moved)


func _spawn_pot_ready_burst() -> void:
	for i in range(6):
		_spawn_pot_effect("ready", "aroma", i, 6, 0.0)
	for i in range(3):
		_spawn_pot_effect("ready", "oil", i, 3, 0.0)


func _spawn_pot_failure_feedback() -> void:
	var sequence := ["steam", "fleck", "bubble", "oil"]
	for i in range(sequence.size()):
		_spawn_pot_effect("failed", String(sequence[i]), i, sequence.size(), 0.0)
	_spawn_pot_failure_word(_pot_surface_origin())


func _spawn_pot_effect(kind: String, element: String, burst_index: int, burst_count: int, moved: float) -> void:
	_prune_invalid_pot_effects()
	if _pot_effects.size() >= POT_EFFECT_MAX_ACTIVE:
		return
	var layer := _ensure_pot_effect_layer()
	var effect := Node2D.new()
	effect.name = "PotEffect"
	effect.z_index = 0
	effect.set_meta(POT_EFFECT_KIND_META, kind)
	effect.set_meta(POT_EFFECT_ELEMENT_META, element)
	var slot_fraction := (float(burst_index) + randf_range(0.15, 0.85)) / float(maxi(burst_count, 1))
	var spread := 27.0
	if kind == "simmer":
		spread = 20.0
	elif kind == "ready":
		spread = 32.0
	elif kind == "failed":
		spread = 24.0
	var x_offset := lerpf(-spread, spread, slot_fraction) + randf_range(-5.0, 5.0)
	var y_offset := randf_range(-8.0, 3.0)
	if element == "steam" or element == "aroma":
		y_offset = randf_range(-18.0, -8.0)
	elif element == "ripple":
		y_offset = randf_range(-4.0, 5.0)
	elif element == "fleck":
		y_offset = randf_range(-10.0, 2.0)
	elif element == "oil":
		y_offset = randf_range(-5.0, 4.0)
	layer.add_child(effect)
	effect.global_position = _pot_surface_origin() + Vector2(x_offset, y_offset)
	var side_speed := 8.0 + minf(moved, 24.0) * 0.18
	var rise_speed := 20.0
	if element == "ripple":
		rise_speed = randf_range(2.0, 8.0)
		side_speed = 5.0
	elif element == "fleck":
		rise_speed = randf_range(12.0, 24.0)
		side_speed = 10.0 + minf(moved, 24.0) * 0.24
	elif element == "oil":
		rise_speed = randf_range(4.0, 12.0)
		side_speed = 6.0
	elif element == "steam":
		rise_speed = randf_range(34.0, 58.0)
	elif element == "aroma":
		rise_speed = randf_range(44.0, 70.0)
	elif kind == "simmer":
		rise_speed = randf_range(18.0, 32.0)
	else:
		rise_speed = randf_range(24.0, 44.0)
	effect.set_meta(POT_EFFECT_VELOCITY_META, Vector2(randf_range(-side_speed, side_speed), -rise_speed))
	effect.set_meta(POT_EFFECT_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(POT_EFFECT_PHASE_SPEED_META, randf_range(1.0, 2.6))
	var max_life := randf_range(0.58, 0.86)
	if element == "ripple":
		max_life = randf_range(0.36, 0.52)
	elif element == "fleck":
		max_life = randf_range(0.36, 0.58)
	elif element == "oil":
		max_life = randf_range(0.30, 0.48)
	elif element == "steam":
		max_life = randf_range(0.88, 1.18)
	elif element == "aroma":
		max_life = randf_range(1.05, 1.38)
	elif kind == "failed":
		max_life = randf_range(0.62, 0.92)
	elif kind == "simmer":
		max_life = randf_range(0.82, 1.12)
	effect.set_meta(POT_EFFECT_LIFE_META, 0.0)
	effect.set_meta(POT_EFFECT_MAX_LIFE_META, max_life)
	_build_pot_effect_sprite(effect, element, kind)
	_pot_effects.append(effect)


func _pot_surface_origin() -> Vector2:
	var soup := get_node_or_null("Soup") as Node2D
	if soup != null:
		return soup.global_position
	return to_global(Vector2(0.0, -30.0))


func _pot_stir_ratio() -> float:
	if required_stir <= 0.0:
		return 1.0
	return clampf(float(_state._stir_progress) / maxf(required_stir, 0.01), 0.0, 1.0)


func _ensure_pot_effect_layer() -> Node2D:
	if _pot_effect_layer != null and is_instance_valid(_pot_effect_layer):
		return _pot_effect_layer
	_pot_effect_layer = get_node_or_null(POT_EFFECT_LAYER_NAME) as Node2D
	if _pot_effect_layer == null:
		_pot_effect_layer = Node2D.new()
		_pot_effect_layer.name = POT_EFFECT_LAYER_NAME
		add_child(_pot_effect_layer)
	_pot_effect_layer.top_level = true
	_pot_effect_layer.global_position = Vector2.ZERO
	_pot_effect_layer.z_as_relative = false
	_pot_effect_layer.z_index = POT_EFFECT_LAYER_Z_INDEX
	return _pot_effect_layer


func _spawn_pot_failure_word(origin: Vector2) -> void:
	_prune_invalid_pot_failure_feedbacks()
	if _pot_failure_feedbacks.size() >= 8:
		return
	var layer := _ensure_pot_failure_feedback_layer()
	var effect := Node2D.new()
	effect.name = "PotFailureWord"
	effect.z_index = 0
	effect.scale = Vector2.ONE * randf_range(0.78, 0.9)
	var word := "废品"
	effect.set_meta(POT_FAILURE_FEEDBACK_KIND_META, "failed")
	effect.set_meta(POT_FAILURE_FEEDBACK_VELOCITY_META, Vector2(randf_range(-9.0, 9.0), -randf_range(38.0, 62.0)))
	effect.set_meta(POT_FAILURE_FEEDBACK_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(POT_FAILURE_FEEDBACK_PHASE_SPEED_META, randf_range(0.9, 1.7))
	effect.set_meta(POT_FAILURE_FEEDBACK_LIFE_META, 0.0)
	effect.set_meta(POT_FAILURE_FEEDBACK_MAX_LIFE_META, randf_range(0.82, 1.08))
	effect.set_meta(POT_FAILURE_FEEDBACK_BASE_SCALE_META, effect.scale.x)
	layer.add_child(effect)
	effect.global_position = origin + Vector2(randf_range(-10.0, 10.0), randf_range(-40.0, -28.0))
	var label := Label.new()
	label.name = "Label"
	label.text = word
	label.size = Vector2(76.0, 28.0)
	label.position = Vector2(-38.0, -14.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GRILL_FEEDBACK_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.50, 0.42, 0.30, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.94))
	effect.add_child(label)
	_pot_failure_feedbacks.append(effect)


func _ensure_pot_failure_feedback_layer() -> Node2D:
	if _pot_failure_feedback_layer != null and is_instance_valid(_pot_failure_feedback_layer):
		return _pot_failure_feedback_layer
	_pot_failure_feedback_layer = get_node_or_null(POT_FAILURE_FEEDBACK_LAYER_NAME) as Node2D
	if _pot_failure_feedback_layer == null:
		_pot_failure_feedback_layer = Node2D.new()
		_pot_failure_feedback_layer.name = POT_FAILURE_FEEDBACK_LAYER_NAME
		add_child(_pot_failure_feedback_layer)
	_pot_failure_feedback_layer.top_level = true
	_pot_failure_feedback_layer.global_position = Vector2.ZERO
	_pot_failure_feedback_layer.z_as_relative = false
	_pot_failure_feedback_layer.z_index = POT_FAILURE_FEEDBACK_LAYER_Z_INDEX
	return _pot_failure_feedback_layer


func _build_pot_effect_sprite(effect: Node2D, element: String, kind: String) -> void:
	var texture := _load_pot_effect_texture()
	if texture == null:
		return
	var variant := randi_range(0, POT_EFFECT_VARIANT_COUNT - 1)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		Vector2(float(variant) * POT_EFFECT_SLOT_SIZE.x, float(_pot_effect_region_row(element)) * POT_EFFECT_SLOT_SIZE.y),
		POT_EFFECT_SLOT_SIZE
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var base_scale := _pot_effect_sprite_scale(element, kind)
	sprite.scale = Vector2.ONE * base_scale
	sprite.flip_h = randf() > 0.5
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.92)
	if kind == "failed":
		sprite.modulate = Color(0.30, 0.26, 0.18, 0.78)
		if element == "steam":
			sprite.modulate = Color(0.20, 0.19, 0.17, 0.62)
		elif element == "fleck":
			sprite.modulate = Color(0.38, 0.25, 0.12, 0.86)
	effect.set_meta(POT_EFFECT_VARIANT_META, variant)
	effect.set_meta(POT_EFFECT_BASE_SCALE_META, base_scale)
	effect.add_child(sprite)


func _pot_effect_region_row(element: String) -> int:
	if element == "oil":
		return 5
	if element == "fleck":
		return 4
	if element == "aroma":
		return 3
	if element == "steam":
		return 2
	if element == "ripple":
		return 1
	return 0


func _pot_effect_sprite_scale(element: String, kind: String) -> float:
	if element == "oil":
		return randf_range(0.18, 0.26)
	if element == "fleck":
		return randf_range(0.18, 0.27)
	if element == "aroma":
		return randf_range(0.23, 0.31)
	if element == "steam":
		return randf_range(0.18, 0.25)
	if element == "ripple":
		return randf_range(0.24, 0.34)
	if kind == "simmer":
		return randf_range(0.17, 0.22)
	return randf_range(0.20, 0.28)


func _load_pot_effect_texture() -> Texture2D:
	if _pot_effect_texture != null:
		return _pot_effect_texture
	var imported := TextureManager.try_load(POT_EFFECT_TEXTURE_PATH)
	if imported != null:
		_pot_effect_texture = imported
		return _pot_effect_texture
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(POT_EFFECT_TEXTURE_PATH))
	if err != OK:
		push_warning("[KitchenContainer] missing pot effect texture: " + POT_EFFECT_TEXTURE_PATH)
		return null
	var image_texture := ImageTexture.create_from_image(image)
	image_texture.resource_path = POT_EFFECT_TEXTURE_PATH
	_pot_effect_texture = image_texture
	return _pot_effect_texture


func _update_pot_effects(delta: float) -> void:
	if _pot_effects.is_empty():
		return
	for i in range(_pot_effects.size() - 1, -1, -1):
		var effect := _pot_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_pot_effects.remove_at(i)
			continue
		var velocity := effect.get_meta(POT_EFFECT_VELOCITY_META) as Vector2
		var phase := float(effect.get_meta(POT_EFFECT_PHASE_META))
		var phase_speed := float(effect.get_meta(POT_EFFECT_PHASE_SPEED_META))
		var life := float(effect.get_meta(POT_EFFECT_LIFE_META)) + delta
		var max_life := float(effect.get_meta(POT_EFFECT_MAX_LIFE_META))
		var element := String(effect.get_meta(POT_EFFECT_ELEMENT_META, ""))
		phase += delta * phase_speed
		effect.set_meta(POT_EFFECT_PHASE_META, phase)
		effect.set_meta(POT_EFFECT_LIFE_META, life)
		var wander := sin(phase) * 4.5
		effect.global_position += Vector2(velocity.x + wander, velocity.y) * delta
		var sprite := effect.get_node_or_null("Sprite") as Sprite2D
		if sprite != null:
			var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
			var alpha := clampf(1.0 - progress, 0.0, 1.0)
			sprite.modulate.a = minf(0.92, alpha * 1.18)
			if element == "ripple":
				var base_scale := float(effect.get_meta(POT_EFFECT_BASE_SCALE_META, 0.28))
				sprite.scale = Vector2.ONE * base_scale * lerpf(0.86, 1.32, progress)
		if effect.global_position.y <= POT_EFFECT_OFFSCREEN_Y or life >= max_life:
			_pot_effects.remove_at(i)
			effect.queue_free()


func _update_pot_failure_feedbacks(delta: float) -> void:
	if _pot_failure_feedbacks.is_empty():
		return
	for i in range(_pot_failure_feedbacks.size() - 1, -1, -1):
		var effect := _pot_failure_feedbacks[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_pot_failure_feedbacks.remove_at(i)
			continue
		var velocity := effect.get_meta(POT_FAILURE_FEEDBACK_VELOCITY_META, Vector2.ZERO) as Vector2
		var phase := float(effect.get_meta(POT_FAILURE_FEEDBACK_PHASE_META, 0.0))
		var phase_speed := float(effect.get_meta(POT_FAILURE_FEEDBACK_PHASE_SPEED_META, 1.0))
		var life := float(effect.get_meta(POT_FAILURE_FEEDBACK_LIFE_META, 0.0)) + maxf(delta, 0.0)
		var max_life := float(effect.get_meta(POT_FAILURE_FEEDBACK_MAX_LIFE_META, 0.9))
		phase += delta * phase_speed
		effect.set_meta(POT_FAILURE_FEEDBACK_PHASE_META, phase)
		effect.set_meta(POT_FAILURE_FEEDBACK_LIFE_META, life)
		effect.global_position += Vector2(velocity.x + sin(phase) * 3.0, velocity.y) * delta
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		var alpha := clampf(1.0 - progress, 0.0, 1.0)
		var base_scale := float(effect.get_meta(POT_FAILURE_FEEDBACK_BASE_SCALE_META, 0.84))
		effect.modulate.a = minf(0.92, alpha * 1.12)
		effect.scale = Vector2.ONE * base_scale * lerpf(0.9, 1.08, sin(progress * PI))
		if effect.global_position.y <= POT_FAILURE_FEEDBACK_OFFSCREEN_Y or life >= max_life:
			_pot_failure_feedbacks.remove_at(i)
			effect.queue_free()


func _prune_invalid_pot_failure_feedbacks() -> void:
	for i in range(_pot_failure_feedbacks.size() - 1, -1, -1):
		var effect := _pot_failure_feedbacks[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_pot_failure_feedbacks.remove_at(i)


func _prune_invalid_pot_effects() -> void:
	for i in range(_pot_effects.size() - 1, -1, -1):
		var effect := _pot_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_pot_effects.remove_at(i)


func _is_point_inside_stir_zone(global_pos: Vector2) -> bool:
	var local_pos: Vector2 = to_local(global_pos)
	return absf(local_pos.x) <= stir_zone_half_width \
		and local_pos.y >= stir_zone_top_y \
		and local_pos.y <= stir_zone_bottom_y


func can_sear_item_key(item_key: String) -> bool:
	if item_key == "":
		return false
	if item_key == "meat_cooked" or item_key == "bread":
		return true
	if GameManager.craft.is_product(item_key):
		return false
	return GameManager.craft.query_recipe("grill", [item_key]) != ""


func _configure_state() -> void:
	if container_key == "pot":
		_state.configure_pot(required_stir)
	else:
		_state.configure_grill(cook_time, burn_time)


func _on_intake_body_entered(body: Node) -> void:
	_try_accept_body(body)


func _try_accept_body(body: Node) -> void:
	if not body is DeskItem:
		return
	var item: DeskItem = body
	if item.is_queued_for_deletion() or item.item_key == "":
		return
	if GameManager.craft.is_product(item.item_key):
		return
	if not is_item_inside_intake(item):
		return
	if container_key == "pot" and _state.ingredients().size() >= POT_MAX_INGREDIENTS:
		_reject_extra_ingredient(item)
		return
	_state.add_item(item.item_key)
	GameManager.play_audio_event("ingredient_drop")
	item.queue_free()
	print("[KitchenContainer] ", container_key, " accepted ", item.item_key)


func _reject_extra_ingredient(item: DeskItem) -> void:
	var reject_x := randf_range(-intake_inner_half_width * 0.45, intake_inner_half_width * 0.45)
	item.global_position = to_global(Vector2(reject_x, intake_top_y - 24.0))
	item.linear_velocity = Vector2(randf_range(-70.0, 70.0), -190.0)
	item.angular_velocity = randf_range(-7.0, 7.0)
	item.sleeping = false


func is_item_inside_intake(item: Node2D) -> bool:
	return _is_point_inside_intake(item.global_position)


func is_spoon_inside(spoon: StirSpoon) -> bool:
	if container_key == "pot":
		return _is_point_inside_stir_zone(spoon.tip_global_position())
	return _is_point_inside_intake(spoon.tip_global_position())


func _is_point_inside_intake(global_pos: Vector2) -> bool:
	var local_pos: Vector2 = to_local(global_pos)
	return absf(local_pos.x) <= intake_inner_half_width \
		and local_pos.y >= intake_top_y \
		and local_pos.y <= intake_bottom_y


func _finish_current(product_key: String) -> void:
	var ingredients := _state.ingredients()
	if product_key == "":
		product_key = _single_stir_operation_result(ingredients)
	if container_key == "pot" and product_key != "":
		_spawn_pot_ready_burst()
	_state.clear()
	_configure_state()
	if product_key == "":
		product_key = GameManager.craft.failure_product_for_container(container_key)
		if product_key == "":
			print("[KitchenContainer] ", container_key, " no recipe for ", ingredients)
			return
		print("[KitchenContainer] ", container_key, " no recipe for ", ingredients, ", spawned failure product ", product_key)
		if container_key == "pot":
			_spawn_pot_failure_feedback()
	_spawn_product(product_key)
	recipe_consumed.emit(product_key)


func _single_stir_operation_result(ingredients: Array) -> String:
	if container_key != "pot" or ingredients.size() != 1:
		return ""
	var ops: Dictionary = GameManager.craft.get_operations(String(ingredients[0]))
	return String(ops.get("stir", ""))


func _burnt_key_for(raw_key: String) -> String:
	if raw_key.begins_with("meat"):
		return "meat_burnt"
	return "bread_burnt"


func _spawn_product(product_key: String) -> void:
	var product: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_parent.add_child(product)
	product.global_position = _output_anchor.global_position
	var item_data: Dictionary = GameManager.craft.get_item(product_key)
	product.set_item(product_key, item_data, GameManager.craft.get_item_physics_profiles())
	GameManager.apply_material_icon_to_desk_item(product)
	product.linear_velocity = Vector2(randf_range(-70.0, 70.0), -180.0)
	GameManager.play_audio_event("product_ready")


func _fit_collision_to_art_bounds() -> void:
	var bounds: Rect2 = TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(_art)
	if bounds.size == Vector2.ZERO:
		return
	if container_key == "grill":
		_fit_grill_collision_to_bounds(bounds)
	elif container_key == "pot":
		_fit_pot_collision_to_bounds(bounds)


func _fit_grill_collision_to_bounds(bounds: Rect2) -> void:
	_set_rect_shape("Body", bounds.size, bounds.get_center())
	_set_rect_shape("Intake/Shape", Vector2(bounds.size.x, minf(bounds.size.y, 48.0)), Vector2.ZERO)
	_set_rect_shape("SearZone/Shape", Vector2(bounds.size.x, minf(bounds.size.y, 28.0)), Vector2.ZERO)
	intake_inner_half_width = bounds.size.x * 0.5


func _fit_pot_collision_to_bounds(bounds: Rect2) -> void:
	_set_rect_shape("PickupArea/Shape", bounds.size, bounds.get_center())
	var left := bounds.position.x
	var right := bounds.position.x + bounds.size.x
	var top := bounds.position.y
	var bottom := bounds.position.y + bounds.size.y
	var inset := bounds.size.x * 0.1
	var top_left := Vector2(left + inset, top)
	var top_right := Vector2(right - inset, top)
	var bottom_left := Vector2(left, bottom)
	var bottom_right := Vector2(right, bottom)
	_set_thick_segment_shape("WallLeft", bottom_left, top_left, POT_WALL_COLLISION_THICKNESS)
	_set_thick_segment_shape("WallRight", bottom_right, top_right, POT_WALL_COLLISION_THICKNESS)
	_set_thick_segment_shape("WallBottom", bottom_left + Vector2(0.0, -POT_BOTTOM_COLLISION_INSET),
		bottom_right + Vector2(0.0, -POT_BOTTOM_COLLISION_INSET), POT_BOTTOM_COLLISION_THICKNESS)
	_set_thick_segment_shape("RimLeft", top_left, Vector2(-intake_inner_half_width, top), POT_RIM_COLLISION_THICKNESS)
	_set_thick_segment_shape("RimRight", Vector2(intake_inner_half_width, top), top_right, POT_RIM_COLLISION_THICKNESS)


func _set_rect_shape(path: String, size: Vector2, pos: Vector2) -> void:
	var node := get_node_or_null(path) as CollisionShape2D
	if node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = size
	node.shape = rect
	node.position = pos


func _set_segment_shape(path: String, a: Vector2, b: Vector2) -> void:
	var node := get_node_or_null(path) as CollisionShape2D
	if node == null:
		return
	var segment := SegmentShape2D.new()
	segment.a = a
	segment.b = b
	node.shape = segment


func _set_thick_segment_shape(path: String, a: Vector2, b: Vector2, thickness: float) -> void:
	var node := get_node_or_null(path) as CollisionShape2D
	if node == null:
		return
	var delta := b - a
	var length := delta.length()
	if length <= 0.0:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(thickness, 1.0), length + maxf(thickness, 1.0))
	node.shape = rect
	node.position = (a + b) * 0.5
	node.rotation = delta.angle() - PI * 0.5


func pop_last_ingredient() -> String:
	if container_key != "pot":
		return ""
	return _state.pop_last_item()


func ingredient_output_position() -> Vector2:
	return _output_anchor.global_position
