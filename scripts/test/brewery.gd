class_name Brewery
extends RigidBody2D

## Barrel container body. It keeps normal gravity, can be grabbed/shaken,
## and continues as a physics body after release.
signal recipe_consumed(product_key: String)

const CONTAINER_KEY := "barrel"
const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const TEXTURE_COLLISION_BOUNDS := preload("res://scripts/ui/texture_collision_bounds.gd")
const PHYSICS_MOTION_TRAIL := preload("res://scripts/ui/physics_motion_trail.gd")
const INGREDIENT_INTAKE_VFX := preload("res://scripts/ui/ingredient_intake_vfx.gd")
const BARREL_MASS := 2.5
const BARREL_LINEAR_DAMP := 0.8
const BARREL_ANGULAR_DAMP := 4.0
const MAX_INGREDIENTS := 2
const MOUTH_INNER_HALF_WIDTH := 24.0
const MOUTH_TOP_Y := -64.0
const MOUTH_BOTTOM_Y := -34.0
const SPOON_ZONE_INNER_HALF_WIDTH := 40.0
const SPOON_ZONE_TOP_Y := MOUTH_TOP_Y
const SPOON_ZONE_BOTTOM_Y := 40.0
const BARREL_CONFIG := "res://data/barrel.json"
const QUALITY_DRINK_TEXTURE_PREFIX := "res://assets/textures/tavern/items/"
const SHAKE_BUBBLE_LAYER_NAME := "ShakeBubbles"
const SHAKE_BUBBLE_LAYER_Z_INDEX := 18
const SHAKE_BUBBLE_SPAWN_INTERVAL := 0.018
const SHAKE_BUBBLE_MAX_ACTIVE := 220
const SHAKE_BUBBLE_FOAM_MAX_ACTIVE := 680
const SHAKE_BUBBLE_MOUTH_SPAWN_HALF_WIDTH := MOUTH_INNER_HALF_WIDTH + 14.0
const SHAKE_BUBBLE_FOAM_PRESSURE_GAIN := 1.05
const SHAKE_BUBBLE_FOAM_PRESSURE_DECAY := 0.7
const SHAKE_BUBBLE_FOAM_SPEED_START_MULT := 2.8
const SHAKE_BUBBLE_FOAM_SPEED_FULL_MULT := 4.8
const SHAKE_BUBBLE_FOAM_OVER_GOOD_FULL_COUNT := 28.0
const SHAKE_BUBBLE_FOAM_BURST_BONUS := 42
const SHAKE_BUBBLE_FOAM_SIDE_SPEED_BONUS := 88.0
const SHAKE_BUBBLE_FOAM_OUTWARD_SPEED_BONUS := 152.0
const SHAKE_BUBBLE_FOAM_WANDER_BONUS := 18.0
const SHAKE_BUBBLE_EMISSION_RESERVE := 6
const SHAKE_BUBBLE_MOVEMENT_MIN_SPEED_MULT := 0.45
const SHAKE_BUBBLE_SPEED_BONUS_START_MULT := 1.4
const SHAKE_BUBBLE_SPEED_BONUS_FULL_MULT := 4.8
const SHAKE_BUBBLE_MAX_SPEED_MULTIPLIER := 1.9
const SHAKE_BUBBLE_OFFSCREEN_Y := -10.0
const SHAKE_BUBBLE_TEXTURE_PATH := "res://assets/textures/barrel_bubbles/barrel_bubbles.png"
const SHAKE_BUBBLE_SLOT_SIZE := Vector2(80.0, 80.0)
const SHAKE_BUBBLE_VARIANT_COUNT := 4
const SHAKE_BUBBLE_VELOCITY_META := "barrel_bubble_velocity"
const SHAKE_BUBBLE_PHASE_META := "barrel_bubble_phase"
const SHAKE_BUBBLE_PHASE_SPEED_META := "barrel_bubble_phase_speed"
const SHAKE_BUBBLE_QUALITY_META := "barrel_bubble_quality"
const SHAKE_BUBBLE_VARIANT_META := "barrel_bubble_variant"
const SHAKE_BUBBLE_FOAM_PRESSURE_META := "barrel_bubble_foam_pressure"
const SHAKE_BUBBLE_LATERAL_INFLUENCE_META := "barrel_bubble_lateral_influence"
const GOOD_CELEBRATION_LAYER_NAME := "GoodBrewCelebration"
const GOOD_CELEBRATION_LAYER_Z_INDEX := 22
const GOOD_CELEBRATION_TEXTURE_PATH := "res://assets/textures/barrel_celebration/barrel_celebration.png"
const GOOD_CELEBRATION_FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const GOOD_CELEBRATION_SLOT_SIZE := Vector2(96.0, 128.0)
const GOOD_CELEBRATION_VARIANT_COUNT := 4
const GOOD_CELEBRATION_MAX_ACTIVE := 240
const GOOD_CELEBRATION_OFFSCREEN_Y := -10.0
const GOOD_CELEBRATION_VELOCITY_META := "barrel_celebration_velocity"
const GOOD_CELEBRATION_PHASE_META := "barrel_celebration_phase"
const GOOD_CELEBRATION_PHASE_SPEED_META := "barrel_celebration_phase_speed"
const GOOD_CELEBRATION_LIFE_META := "barrel_celebration_life"
const GOOD_CELEBRATION_MAX_LIFE_META := "barrel_celebration_max_life"
const GOOD_CELEBRATION_ELEMENT_META := "barrel_celebration_element"
const GOOD_CELEBRATION_VARIANT_META := "barrel_celebration_variant"
const GOOD_CELEBRATION_BASE_SCALE_META := "barrel_celebration_base_scale"
const GOOD_CELEBRATION_WORD_META := "barrel_celebration_word"
const GOOD_CELEBRATION_WORDS: Array[String] = ["牛逼", "绝品", "神酿", "爆香", "上头", "天成"]
const NORMAL_FEEDBACK_LAYER_NAME := "NormalBrewFeedback"
const NORMAL_FEEDBACK_LAYER_Z_INDEX := 20
const NORMAL_FEEDBACK_MAX_ACTIVE := 24
const NORMAL_FEEDBACK_OFFSCREEN_Y := -10.0
const NORMAL_FEEDBACK_VELOCITY_META := "normal_brew_feedback_velocity"
const NORMAL_FEEDBACK_PHASE_META := "normal_brew_feedback_phase"
const NORMAL_FEEDBACK_PHASE_SPEED_META := "normal_brew_feedback_phase_speed"
const NORMAL_FEEDBACK_LIFE_META := "normal_brew_feedback_life"
const NORMAL_FEEDBACK_MAX_LIFE_META := "normal_brew_feedback_max_life"
const NORMAL_FEEDBACK_WORD_META := "normal_brew_feedback_word"
const NORMAL_FEEDBACK_BASE_SCALE_META := "normal_brew_feedback_base_scale"
const NORMAL_FEEDBACK_WORDS: Array[String] = ["成了", "稳了", "顺口", "够味", "不赖", "过关"]
const FAILED_FEEDBACK_LAYER_NAME := "FailedBrewFeedback"
const FAILED_FEEDBACK_KIND_META := "failed_brew_feedback_kind"
const FAILED_FEEDBACK_WORD_META := "failed_brew_feedback_word"
const OUTPUT_BURST_LAYER_NAME := "BrewOutputBurst"
const OUTPUT_BURST_LAYER_Z_INDEX := 21
const OUTPUT_BURST_MAX_ACTIVE := 96
const OUTPUT_BURST_OFFSCREEN_Y := -10.0
const OUTPUT_BURST_QUALITY_META := "brew_output_burst_quality"
const OUTPUT_BURST_ELEMENT_META := "brew_output_burst_element"
const OUTPUT_BURST_VELOCITY_META := "brew_output_burst_velocity"
const OUTPUT_BURST_PHASE_META := "brew_output_burst_phase"
const OUTPUT_BURST_PHASE_SPEED_META := "brew_output_burst_phase_speed"
const OUTPUT_BURST_LIFE_META := "brew_output_burst_life"
const OUTPUT_BURST_MAX_LIFE_META := "brew_output_burst_max_life"
const OUTPUT_BURST_BASE_SCALE_META := "brew_output_burst_base_scale"
const BREW_PRODUCT_VFX_NAME := "BrewProductVfx"
const BREW_PRODUCT_VFX_QUALITY_META := "brew_product_vfx_quality"
const BREW_PRODUCT_VFX_ELEMENT_META := "brew_product_vfx_element"
const BREW_PRODUCT_VFX_LIFE_META := "brew_product_vfx_life"
const BREW_PRODUCT_VFX_MAX_LIFE_META := "brew_product_vfx_max_life"
const BREW_PRODUCT_VFX_BASE_SCALE_META := "brew_product_vfx_base_scale"
const BREW_COMBO_HUD_NAME := "BrewComboHud"
const BREW_COMBO_VFX_LAYER_NAME := "BrewComboVfx"
const BREW_COMBO_VFX_LAYER_Z_INDEX := 24
const BREW_COMBO_MAX_ACTIVE_VFX := 80
const BREW_COMBO_IDLE_RESET_TIME := 0.86
const BREW_COMBO_VFX_OFFSCREEN_Y := -20.0
const BREW_COMBO_CAMERA_NAME := "BrewShakeCamera"
const BREW_COMBO_SHAKE_DECAY := 9.0
const BREW_COMBO_SHAKE_MAX := 7.0
const BREW_COMBO_VELOCITY_META := "brew_combo_velocity"
const BREW_COMBO_PHASE_META := "brew_combo_phase"
const BREW_COMBO_PHASE_SPEED_META := "brew_combo_phase_speed"
const BREW_COMBO_LIFE_META := "brew_combo_life"
const BREW_COMBO_MAX_LIFE_META := "brew_combo_max_life"
const BREW_COMBO_ELEMENT_META := "brew_combo_element"
const BREW_COMBO_BASE_SCALE_META := "brew_combo_base_scale"
const BREW_COMBO_SPARK_WORDS: Array[String] = ["离谱", "炸桶", "上天", "酒神", "还在摇"]

@onready var _mouth: Area2D = $Mouth
@onready var _output_anchor: Marker2D = $OutputAnchor
@onready var _art: Sprite2D = $Art

var _items_parent: Node2D = null
var _pending_keys: Array[String] = []
var _shake := BrewShakeMeter.new()
var _session_active: bool = false
var _shake_bubble_layer: Node2D = null
var _shake_bubbles: Array[Node2D] = []
var _shake_bubble_spawn_elapsed: float = 0.0
var _shake_bubble_texture: Texture2D = null
var _last_shake_bubble_quality_tier: String = ""
var _shake_bubble_foam_pressure: float = 0.0
var _quality_drink_textures: Dictionary = {}
var _good_celebration_layer: Node2D = null
var _good_celebration_effects: Array[Node2D] = []
var _good_celebration_texture: Texture2D = null
var _normal_feedback_layer: Node2D = null
var _failed_feedback_layer: Node2D = null
var _normal_feedback_effects: Array[Node2D] = []
var _output_burst_layer: Node2D = null
var _output_burst_effects: Array[Node2D] = []
var _product_output_vfx_nodes: Array[Node2D] = []
var _brew_combo: int = 0
var _brew_combo_idle_time: float = 0.0
var _brew_combo_pulse: float = 0.0
var _brew_combo_peak_rank: int = -1
var _brew_combo_hud: CanvasLayer = null
var _brew_combo_label: Label = null
var _brew_combo_rank_label: Label = null
var _brew_combo_vfx_layer: Node2D = null
var _brew_combo_vfx_effects: Array[Node2D] = []
var _screen_shake_amount: float = 0.0
var _screen_shake_phase: float = 0.0
var _brew_shake_camera: Camera2D = null
var _motion_trail = PHYSICS_MOTION_TRAIL.new()


func _ready() -> void:
	assert(GameManager.craft != null, "[Brewery] GameManager.craft is not ready")
	_items_parent = get_parent().get_node("Items")
	assert(_items_parent != null, "[Brewery] Missing sibling Items node")
	mass = BARREL_MASS
	freeze = false
	gravity_scale = 1.0
	linear_damp = BARREL_LINEAR_DAMP
	angular_damp = BARREL_ANGULAR_DAMP
	lock_rotation = false
	_fit_collision_to_art_bounds()
	_mouth.body_entered.connect(_on_mouth_body_entered)
	_load_shake_config()


func _physics_process(delta: float) -> void:
	var counted_shake := false
	if _session_active:
		var shake_count_before := _shake.shake_count
		_shake.add_sample(linear_velocity)
		counted_shake = _shake.shake_count > shake_count_before
		_update_brew_combo(delta, counted_shake)
	else:
		_update_brew_combo(delta, false)
	_update_container_motion_trail(delta)
	_update_shake_bubble_foam_pressure(delta)
	_update_shake_bubbles(delta)
	if _session_active:
		_try_spawn_shake_bubble(delta)
	_update_brew_output_burst(delta)
	_update_product_output_vfx(delta)
	_update_normal_brew_feedback(delta)
	_update_brew_combo_hud(delta)
	_update_brew_combo_vfx(delta)
	_update_brew_screen_shake(delta)
	_update_good_celebration_effects(delta)
	for body in _mouth.get_overlapping_bodies():
		_try_accept_mouth_body(body)


func _on_mouth_body_entered(body: Node) -> void:
	_try_accept_mouth_body(body)


func _update_container_motion_trail(delta: float) -> void:
	_motion_trail.update(
		self,
		delta,
		_art,
		_container_motion_trail_fallback_polygon(),
		Color(0.72, 0.42, 0.20, 1.0)
	)


func _container_motion_trail_fallback_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-50.0, 40.0),
		Vector2(-40.0, -40.0),
		Vector2(40.0, -40.0),
		Vector2(50.0, 40.0),
	])


func _try_accept_mouth_body(body: Node) -> void:
	if not body is DeskItem:
		return
	var item: DeskItem = body
	if item.is_queued_for_deletion():
		return
	if item.item_key == "":
		return
	if GameManager.craft.is_product(item.item_key):
		return
	if not _is_item_inside_mouth_opening(item):
		return
	if _pending_keys.size() >= MAX_INGREDIENTS:
		_reject_extra_ingredient(item)
		return
	_pending_keys.append(item.item_key)
	INGREDIENT_INTAKE_VFX.spawn(self, item, item.item_key, _mouth_center_global_position(), Color(0.96, 0.62, 0.28, 1.0))
	GameManager.play_audio_event("ingredient_drop")
	item.queue_free()


func _reject_extra_ingredient(item: DeskItem) -> void:
	item.global_position = to_global(Vector2(randf_range(-16.0, 16.0), MOUTH_TOP_Y - 28.0))
	item.linear_velocity = Vector2(randf_range(-90.0, 90.0), -240.0)
	item.angular_velocity = randf_range(-8.0, 8.0)
	item.sleeping = false


func _is_item_inside_mouth_opening(item: DeskItem) -> bool:
	return _is_point_inside_mouth_opening(item.global_position)


func is_item_inside_mouth(item: Node2D) -> bool:
	return item != null and _is_point_inside_mouth_opening(item.global_position)


func _mouth_center_global_position() -> Vector2:
	return to_global(Vector2(0.0, (MOUTH_TOP_Y + MOUTH_BOTTOM_Y) * 0.5))


func is_spoon_inside(spoon: StirSpoon) -> bool:
	var local_pos: Vector2 = to_local(spoon.tip_global_position())
	return absf(local_pos.x) <= SPOON_ZONE_INNER_HALF_WIDTH \
		and local_pos.y >= SPOON_ZONE_TOP_Y \
		and local_pos.y <= SPOON_ZONE_BOTTOM_Y


func _is_point_inside_mouth_opening(global_pos: Vector2) -> bool:
	var local_pos: Vector2 = to_local(global_pos)
	return absf(local_pos.x) <= MOUTH_INNER_HALF_WIDTH \
		and local_pos.y >= MOUTH_TOP_Y \
		and local_pos.y <= MOUTH_BOTTOM_Y


func _spawn_product(product_key: String, quality: String = "normal") -> void:
	var product: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_parent.add_child(product)
	product.global_position = _output_anchor.global_position
	var item_data: Dictionary = GameManager.craft.get_item(product_key)
	product.set_item(product_key, item_data, GameManager.craft.get_item_physics_profiles())
	GameManager.apply_material_icon_to_desk_item(product)
	product.quality = quality
	_apply_brew_product_quality_art(product, product_key, quality)
	# 冒桶口：向上 + 轻微偏外的初速度，重力把它带成弧线落桌。
	# 朝上离开桶口，且产出物是成品（_try_accept 的 is_product 守卫会拦它），不会被自己收回。
	var out_dir := 1.0 if randf() > 0.5 else -1.0
	product.linear_velocity = Vector2(out_dir * 90.0, -260.0)
	_attach_brew_product_vfx(product, quality, product.linear_velocity)
	_spawn_brew_output_burst(product.global_position, quality, product.linear_velocity)
	if quality == "good":
		_spawn_good_brew_celebration(product.global_position, product.linear_velocity)
	elif quality == "normal":
		_spawn_normal_brew_feedback(product.global_position)
	elif quality == "failed":
		_spawn_failed_brew_feedback(product.global_position)
	GameManager.play_audio_event("product_ready")


func _apply_brew_product_quality_art(product: DeskItem, product_key: String, quality: String) -> void:
	if product == null or quality != "good":
		return
	var texture_path := "%s%s_%s.png" % [QUALITY_DRINK_TEXTURE_PREFIX, product_key, quality]
	var texture := _load_brew_quality_drink_texture(texture_path)
	if texture == null:
		return
	product.set_art_texture(texture)


func _load_brew_quality_drink_texture(texture_path: String) -> Texture2D:
	if _quality_drink_textures.has(texture_path):
		return _quality_drink_textures[texture_path]
	var imported := TextureManager.try_load(texture_path)
	if imported != null:
		_quality_drink_textures[texture_path] = imported
		return imported
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(texture_path))
	if err != OK:
		return null
	var image_texture := ImageTexture.create_from_image(image)
	image_texture.resource_path = texture_path
	_quality_drink_textures[texture_path] = image_texture
	return image_texture


func _attach_brew_product_vfx(product: DeskItem, quality: String, product_velocity: Vector2) -> void:
	if product == null:
		return
	_prune_invalid_product_output_vfx()
	var vfx := Node2D.new()
	vfx.name = BREW_PRODUCT_VFX_NAME
	vfx.z_index = 12
	vfx.show_behind_parent = true
	vfx.set_meta(BREW_PRODUCT_VFX_QUALITY_META, quality)
	vfx.set_meta(BREW_PRODUCT_VFX_LIFE_META, 0.0)
	vfx.set_meta(BREW_PRODUCT_VFX_MAX_LIFE_META, 1.18 if quality == "good" else 0.82)
	vfx.set_meta(BREW_PRODUCT_VFX_BASE_SCALE_META, 1.0)
	product.add_child(vfx)
	vfx.position = Vector2.ZERO
	var direction := product_velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(0.0, -1.0)
	var behind := -direction
	var trail_count := 8 if quality == "good" else 4
	for i in range(trail_count):
		var t := float(i) / float(maxi(trail_count - 1, 1))
		var offset := behind * lerpf(10.0, 58.0 if quality == "good" else 34.0, t)
		offset += Vector2(randf_range(-8.0, 8.0), randf_range(-5.0, 5.0))
		_add_product_vfx_sprite(vfx, quality, "trail", offset, randf_range(0.92, 1.12))
	if quality == "good":
		_add_product_vfx_sprite(vfx, quality, "glow", Vector2.ZERO, 1.0)
		for i in range(4):
			_add_product_vfx_sprite(
				vfx,
				quality,
				"spark",
				Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 12.0)),
				randf_range(0.88, 1.12)
			)
	_product_output_vfx_nodes.append(vfx)


func _add_product_vfx_sprite(vfx: Node2D, quality: String, element: String, local_offset: Vector2, scale_mult: float) -> void:
	var texture := _load_good_celebration_texture()
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = element.capitalize() + "Sprite"
	sprite.texture = texture
	sprite.centered = true
	sprite.region_enabled = true
	var source_element := _product_vfx_sprite_source_element(element)
	var variant := randi_range(0, GOOD_CELEBRATION_VARIANT_COUNT - 1)
	sprite.region_rect = Rect2(
		Vector2(float(variant) * GOOD_CELEBRATION_SLOT_SIZE.x, float(_good_celebration_region_row(source_element)) * GOOD_CELEBRATION_SLOT_SIZE.y),
		GOOD_CELEBRATION_SLOT_SIZE
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = local_offset
	sprite.rotation = randf_range(-0.18, 0.18)
	sprite.scale = Vector2.ONE * _product_vfx_sprite_scale(quality, element) * scale_mult
	sprite.modulate = _product_vfx_color(quality, element)
	sprite.set_meta(BREW_PRODUCT_VFX_ELEMENT_META, element)
	vfx.add_child(sprite)


func _product_vfx_sprite_source_element(element: String) -> String:
	if element == "spark":
		return "star"
	if element == "glow":
		return "ring"
	return "trail"


func _product_vfx_sprite_scale(quality: String, element: String) -> float:
	if element == "glow":
		return 0.46
	if element == "spark":
		return randf_range(0.20, 0.30)
	if quality == "good":
		return randf_range(0.24, 0.36)
	return randf_range(0.18, 0.26)


func _product_vfx_color(quality: String, element: String) -> Color:
	if quality == "good":
		if element == "glow":
			return Color(1.0, 0.82, 0.22, 0.74)
		if element == "spark":
			return Color(1.0, 0.93, 0.42, 0.96)
		return Color(1.0, 0.76, 0.24, 0.86)
	if quality == "failed":
		return Color(0.24, 0.22, 0.16, 0.58)
	return Color(0.92, 0.90, 0.74, 0.68)


func _update_product_output_vfx(delta: float) -> void:
	if _product_output_vfx_nodes.is_empty():
		return
	for i in range(_product_output_vfx_nodes.size() - 1, -1, -1):
		var vfx := _product_output_vfx_nodes[i]
		if vfx == null or not is_instance_valid(vfx) or vfx.is_queued_for_deletion():
			_product_output_vfx_nodes.remove_at(i)
			continue
		var life := float(vfx.get_meta(BREW_PRODUCT_VFX_LIFE_META)) + delta
		var max_life := float(vfx.get_meta(BREW_PRODUCT_VFX_MAX_LIFE_META))
		vfx.set_meta(BREW_PRODUCT_VFX_LIFE_META, life)
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		vfx.scale = Vector2.ONE * lerpf(1.0, 0.72, progress)
		for child in vfx.get_children():
			if not child is Sprite2D:
				continue
			var sprite := child as Sprite2D
			sprite.modulate.a = clampf(1.0 - progress, 0.0, 1.0)
		if life >= max_life:
			_product_output_vfx_nodes.remove_at(i)
			vfx.queue_free()


func _prune_invalid_product_output_vfx() -> void:
	for i in range(_product_output_vfx_nodes.size() - 1, -1, -1):
		var vfx := _product_output_vfx_nodes[i]
		if vfx == null or not is_instance_valid(vfx) or vfx.is_queued_for_deletion():
			_product_output_vfx_nodes.remove_at(i)


func _spawn_brew_output_burst(origin: Vector2, quality: String, product_velocity: Vector2) -> void:
	var direction := product_velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(0.0, -1.0)
	if quality == "good":
		_spawn_brew_output_burst_effect(
			quality,
			"impact",
			origin + direction * 8.0,
			Vector2(randf_range(-8.0, 8.0), -randf_range(24.0, 44.0)),
			0.42,
			randf_range(0.58, 0.72)
		)
		_spawn_brew_output_burst_effect(
			quality,
			"flash",
			origin + Vector2(randf_range(-4.0, 4.0), -10.0),
			Vector2(randf_range(-6.0, 6.0), -randf_range(30.0, 52.0)),
			0.34,
			randf_range(0.42, 0.56)
		)
	var pop_count := 14 if quality == "good" else 6
	for i in range(pop_count):
		var angle := lerpf(-PI * 0.88, -PI * 0.12, (float(i) + randf_range(0.12, 0.88)) / float(pop_count))
		var distance := randf_range(10.0, 34.0 if quality == "good" else 22.0)
		var offset := Vector2(cos(angle), sin(angle)) * distance
		var rise := randf_range(82.0, 146.0 if quality == "good" else 108.0)
		_spawn_brew_output_burst_effect(
			quality,
			"pop",
			origin + offset + Vector2(randf_range(-4.0, 4.0), randf_range(-6.0, 2.0)),
			Vector2(offset.x * randf_range(0.9, 1.7), -rise),
			randf_range(0.48, 0.78 if quality == "good" else 0.62),
			randf_range(0.18, 0.30 if quality == "good" else 0.23)
		)


func _spawn_brew_output_burst_effect(quality: String, element: String, origin: Vector2, velocity: Vector2, max_life: float, base_scale: float) -> void:
	_prune_invalid_brew_output_burst()
	if _output_burst_effects.size() >= OUTPUT_BURST_MAX_ACTIVE:
		return
	var layer := _ensure_brew_output_burst_layer()
	var effect := Node2D.new()
	effect.name = "OutputBurst"
	effect.z_index = 4 if element == "impact" or element == "flash" else 1
	effect.set_meta(OUTPUT_BURST_QUALITY_META, quality)
	effect.set_meta(OUTPUT_BURST_ELEMENT_META, element)
	effect.set_meta(OUTPUT_BURST_VELOCITY_META, velocity)
	effect.set_meta(OUTPUT_BURST_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(OUTPUT_BURST_PHASE_SPEED_META, randf_range(1.2, 3.4))
	effect.set_meta(OUTPUT_BURST_LIFE_META, 0.0)
	effect.set_meta(OUTPUT_BURST_MAX_LIFE_META, max_life)
	effect.set_meta(OUTPUT_BURST_BASE_SCALE_META, base_scale)
	layer.add_child(effect)
	effect.global_position = origin
	_build_brew_output_burst_sprite(effect, quality, element, base_scale)
	_output_burst_effects.append(effect)


func _ensure_brew_output_burst_layer() -> Node2D:
	if _output_burst_layer != null and is_instance_valid(_output_burst_layer):
		return _output_burst_layer
	_output_burst_layer = get_node_or_null(OUTPUT_BURST_LAYER_NAME) as Node2D
	if _output_burst_layer == null:
		_output_burst_layer = Node2D.new()
		_output_burst_layer.name = OUTPUT_BURST_LAYER_NAME
		add_child(_output_burst_layer)
	_output_burst_layer.top_level = true
	_output_burst_layer.global_position = Vector2.ZERO
	_output_burst_layer.z_as_relative = false
	_output_burst_layer.z_index = OUTPUT_BURST_LAYER_Z_INDEX
	return _output_burst_layer


func _build_brew_output_burst_sprite(effect: Node2D, quality: String, element: String, base_scale: float) -> void:
	var texture := _load_good_celebration_texture()
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = true
	sprite.region_enabled = true
	var source_element := "gold_bubble"
	if element == "impact" or element == "flash":
		source_element = "ring"
	var variant := randi_range(0, GOOD_CELEBRATION_VARIANT_COUNT - 1)
	sprite.region_rect = Rect2(
		Vector2(float(variant) * GOOD_CELEBRATION_SLOT_SIZE.x, float(_good_celebration_region_row(source_element)) * GOOD_CELEBRATION_SLOT_SIZE.y),
		GOOD_CELEBRATION_SLOT_SIZE
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * base_scale
	sprite.rotation = randf_range(-0.18, 0.18)
	sprite.modulate = _brew_output_burst_color(quality, element)
	effect.add_child(sprite)


func _brew_output_burst_color(quality: String, element: String) -> Color:
	if quality == "good":
		if element == "impact":
			return Color(1.0, 0.72, 0.18, 0.94)
		if element == "flash":
			return Color(1.0, 0.96, 0.60, 0.88)
		return Color(1.0, 0.82, 0.28, 0.84)
	if quality == "failed":
		return Color(0.28, 0.25, 0.18, 0.68)
	return Color(0.88, 0.86, 0.72, 0.72)


func _update_brew_output_burst(delta: float) -> void:
	if _output_burst_effects.is_empty():
		return
	for i in range(_output_burst_effects.size() - 1, -1, -1):
		var effect := _output_burst_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_output_burst_effects.remove_at(i)
			continue
		var velocity := effect.get_meta(OUTPUT_BURST_VELOCITY_META) as Vector2
		var phase := float(effect.get_meta(OUTPUT_BURST_PHASE_META))
		var phase_speed := float(effect.get_meta(OUTPUT_BURST_PHASE_SPEED_META))
		var life := float(effect.get_meta(OUTPUT_BURST_LIFE_META)) + delta
		var max_life := float(effect.get_meta(OUTPUT_BURST_MAX_LIFE_META))
		var element := String(effect.get_meta(OUTPUT_BURST_ELEMENT_META, ""))
		phase += delta * phase_speed
		effect.set_meta(OUTPUT_BURST_PHASE_META, phase)
		effect.set_meta(OUTPUT_BURST_LIFE_META, life)
		effect.global_position += Vector2(velocity.x + sin(phase) * 4.0, velocity.y) * delta
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		var sprite := effect.get_node_or_null("Sprite") as Sprite2D
		if sprite != null:
			var base_scale := float(effect.get_meta(OUTPUT_BURST_BASE_SCALE_META, 0.24))
			sprite.modulate.a = clampf(1.0 - progress, 0.0, 1.0)
			if element == "impact" or element == "flash":
				sprite.scale = Vector2.ONE * base_scale * lerpf(0.82, 1.62, progress)
		if effect.global_position.y <= OUTPUT_BURST_OFFSCREEN_Y or life >= max_life:
			_output_burst_effects.remove_at(i)
			effect.queue_free()


func _prune_invalid_brew_output_burst() -> void:
	for i in range(_output_burst_effects.size() - 1, -1, -1):
		var effect := _output_burst_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_output_burst_effects.remove_at(i)


func _try_spawn_shake_bubble(delta: float) -> void:
	if _pending_keys.is_empty():
		_last_shake_bubble_quality_tier = ""
		return
	if linear_velocity.length() < _shake_bubble_movement_min_speed():
		return
	var quality := _shake_bubble_quality_tier()
	var tier_changed := _last_shake_bubble_quality_tier != "" and quality != _last_shake_bubble_quality_tier
	_shake_bubble_spawn_elapsed += delta
	if not tier_changed and _shake_bubble_spawn_elapsed < SHAKE_BUBBLE_SPAWN_INTERVAL:
		return
	_shake_bubble_spawn_elapsed = 0.0
	_prune_invalid_shake_bubbles()
	_spawn_shake_bubble_burst(quality)
	_last_shake_bubble_quality_tier = quality


func _spawn_shake_bubble_burst(quality: String) -> void:
	var burst_count := _shake_bubble_burst_count(quality)
	var active_cap := _shake_bubble_active_cap()
	_make_room_for_shake_bubble_burst(quality, burst_count, active_cap)
	for i in range(burst_count):
		if _shake_bubbles.size() >= active_cap:
			return
		_spawn_shake_bubble(quality, i, burst_count)


func _make_room_for_shake_bubble_burst(quality: String, burst_count: int, active_cap: int) -> void:
	var needed := maxi(0, _shake_bubbles.size() + maxi(burst_count, 0) - active_cap)
	if needed <= 0:
		return
	var target_rank := _shake_bubble_quality_rank(quality)
	for rank in range(target_rank):
		var index := 0
		while index < _shake_bubbles.size() and needed > 0:
			var bubble := _shake_bubbles[index]
			if bubble == null or not is_instance_valid(bubble) or bubble.is_queued_for_deletion():
				_shake_bubbles.remove_at(index)
				continue
			if _shake_bubble_quality_rank(String(bubble.get_meta(SHAKE_BUBBLE_QUALITY_META, ""))) == rank:
				bubble.queue_free()
				_shake_bubbles.remove_at(index)
				needed -= 1
				continue
			index += 1
	var reserve_needed := mini(needed, SHAKE_BUBBLE_EMISSION_RESERVE)
	var index := 0
	while index < _shake_bubbles.size() and reserve_needed > 0:
		var bubble := _shake_bubbles[index]
		if bubble == null or not is_instance_valid(bubble) or bubble.is_queued_for_deletion():
			_shake_bubbles.remove_at(index)
			continue
		bubble.queue_free()
		_shake_bubbles.remove_at(index)
		reserve_needed -= 1


func _shake_bubble_quality_rank(quality: String) -> int:
	if quality == "good":
		return 2
	if quality == "normal":
		return 1
	return 0


func _spawn_shake_bubble(quality: String, burst_index: int, burst_count: int) -> void:
	var layer := _ensure_shake_bubble_layer()
	var bubble := Node2D.new()
	bubble.name = "Bubble"
	bubble.z_index = 0
	bubble.set_meta(SHAKE_BUBBLE_QUALITY_META, quality)
	var slot_fraction := (float(burst_index) + randf_range(0.15, 0.85)) / float(maxi(burst_count, 1))
	var spawn_half_width := _shake_bubble_spawn_half_width(quality)
	var foam_pressure := _shake_bubble_pressure_for_quality(quality)
	var horizontal_motion_ratio := _shake_bubble_horizontal_motion_ratio()
	var lateral_foam_pressure := foam_pressure * horizontal_motion_ratio
	var mouth_x := lerpf(-spawn_half_width, spawn_half_width, slot_fraction)
	var mouth_local := Vector2(
		mouth_x + randf_range(-5.0, 5.0),
		MOUTH_TOP_Y - randf_range(2.0, 16.0)
	)
	layer.add_child(bubble)
	bubble.global_position = to_global(mouth_local)
	var over_good_count := _shake_bubble_over_good_count()
	var side_speed := 18.0 if quality == "pending" else 24.0
	var rise_speed := randf_range(86.0, 130.0)
	if quality == "normal":
		side_speed += minf(10.0, float(maxi(_shake.shake_count - _shake.min_count, 0)) * 1.2)
		rise_speed = randf_range(102.0, 152.0) + float(_brew_combo_stage()) * 4.0
	elif quality == "good":
		var good_side_speed := float(_brew_combo_stage()) * 4.0 + minf(38.0, float(over_good_count) * 0.72)
		side_speed += good_side_speed * lerpf(0.25, 1.0, horizontal_motion_ratio)
		rise_speed = randf_range(118.0, 176.0) + float(_brew_combo_stage()) * 7.0 + minf(72.0, float(over_good_count) * 1.15)
		side_speed += lateral_foam_pressure * SHAKE_BUBBLE_FOAM_SIDE_SPEED_BONUS
		var floating_rise_speed := randf_range(54.0, 96.0) + float(_brew_combo_stage()) * 3.0
		rise_speed = lerpf(rise_speed, floating_rise_speed, foam_pressure * 0.72)
	var outward_bias := (slot_fraction - 0.5) * 2.0 * lateral_foam_pressure * SHAKE_BUBBLE_FOAM_OUTWARD_SPEED_BONUS
	bubble.set_meta(SHAKE_BUBBLE_VELOCITY_META, Vector2(randf_range(-side_speed, side_speed) + outward_bias, -rise_speed))
	bubble.set_meta(SHAKE_BUBBLE_PHASE_META, randf_range(0.0, TAU))
	bubble.set_meta(SHAKE_BUBBLE_PHASE_SPEED_META, randf_range(1.5, 3.4))
	bubble.set_meta(SHAKE_BUBBLE_FOAM_PRESSURE_META, foam_pressure)
	bubble.set_meta(SHAKE_BUBBLE_LATERAL_INFLUENCE_META, lateral_foam_pressure)
	_build_bubble_sprite(bubble, quality)
	_shake_bubbles.append(bubble)


func _shake_bubble_quality_tier() -> String:
	if _shake.shake_count >= _shake.good_count:
		return "good"
	if _shake.shake_count >= _shake.min_count:
		return "normal"
	return "pending"


func _shake_bubble_burst_count(quality: String) -> int:
	var full_count := 3
	if quality == "good":
		var over_good_bonus := mini(56, int(float(_shake_bubble_over_good_count()) * 0.8))
		var foam_bonus := int(round(_shake_bubble_pressure_for_quality(quality) * float(SHAKE_BUBBLE_FOAM_BURST_BONUS)))
		full_count = clampi(16 + over_good_bonus + foam_bonus, 16, 114)
	elif quality == "normal":
		var normal_bonus := int(float(maxi(_shake.shake_count - _shake.min_count, 0)) * 1.1)
		full_count = clampi(8 + normal_bonus, 8, 22)
	else:
		full_count = 2
	full_count = maxi(1, int(round(float(full_count) * _shake_bubble_speed_multiplier())))
	return full_count


func _update_shake_bubble_foam_pressure(delta: float) -> void:
	var target_pressure := 0.0
	if _session_active and not _pending_keys.is_empty() and _shake.shake_count > _shake.good_count:
		var speed := linear_velocity.length()
		var start_speed := _shake.min_speed * SHAKE_BUBBLE_FOAM_SPEED_START_MULT
		var full_speed := _shake.min_speed * SHAKE_BUBBLE_FOAM_SPEED_FULL_MULT
		var speed_pressure := clampf(inverse_lerp(start_speed, full_speed, speed), 0.0, 1.0)
		var over_good_pressure := clampf(
			float(_shake_bubble_over_good_count()) / SHAKE_BUBBLE_FOAM_OVER_GOOD_FULL_COUNT,
			0.0,
			1.0
		)
		target_pressure = maxf(speed_pressure, over_good_pressure)
	if target_pressure > 0.0:
		_shake_bubble_foam_pressure = minf(
			1.0,
			_shake_bubble_foam_pressure + delta * SHAKE_BUBBLE_FOAM_PRESSURE_GAIN * target_pressure
		)
	else:
		_shake_bubble_foam_pressure = maxf(
			0.0,
			_shake_bubble_foam_pressure - delta * SHAKE_BUBBLE_FOAM_PRESSURE_DECAY
		)


func _shake_bubble_active_cap() -> int:
	return clampi(
		int(round(lerpf(
			float(SHAKE_BUBBLE_MAX_ACTIVE),
			float(SHAKE_BUBBLE_FOAM_MAX_ACTIVE),
			_shake_bubble_foam_pressure
		))),
		SHAKE_BUBBLE_MAX_ACTIVE,
		SHAKE_BUBBLE_FOAM_MAX_ACTIVE
	)


func _shake_bubble_pressure_for_quality(quality: String) -> float:
	if quality != "good":
		return 0.0
	return _shake_bubble_foam_pressure


func _shake_bubble_horizontal_motion_ratio() -> float:
	var speed := linear_velocity.length()
	if speed <= 0.001:
		return 0.0
	return clampf(absf(linear_velocity.x) / speed, 0.0, 1.0)


func _shake_bubble_spawn_half_width(quality: String) -> float:
	if quality == "pending":
		return MOUTH_INNER_HALF_WIDTH + 14.0
	return SHAKE_BUBBLE_MOUTH_SPAWN_HALF_WIDTH


func _shake_bubble_movement_min_speed() -> float:
	return _shake.min_speed * SHAKE_BUBBLE_MOVEMENT_MIN_SPEED_MULT


func _shake_bubble_speed_multiplier() -> float:
	var speed := linear_velocity.length()
	var start_speed := _shake.min_speed * SHAKE_BUBBLE_SPEED_BONUS_START_MULT
	if speed <= start_speed:
		return 1.0
	var full_speed := _shake.min_speed * SHAKE_BUBBLE_SPEED_BONUS_FULL_MULT
	var t := inverse_lerp(start_speed, full_speed, speed)
	return lerpf(1.0, SHAKE_BUBBLE_MAX_SPEED_MULTIPLIER, clampf(t, 0.0, 1.0))


func _shake_bubble_over_good_count() -> int:
	return maxi(0, _shake.shake_count - _shake.good_count)


func _shake_bubble_region_row(quality: String) -> int:
	if quality == "good":
		return 2
	if quality == "normal":
		return 1
	return 0


func _shake_bubble_sprite_scale(quality: String) -> float:
	var combo_bonus := minf(0.12, float(_brew_combo) * 0.0025)
	if quality == "good":
		return randf_range(0.20, 0.30) + combo_bonus + minf(0.18, float(_shake_bubble_over_good_count()) * 0.003)
	if quality == "normal":
		return randf_range(0.18, 0.25) + combo_bonus * 0.45
	return randf_range(0.15, 0.20) + combo_bonus * 0.2


func _ensure_shake_bubble_layer() -> Node2D:
	if _shake_bubble_layer != null and is_instance_valid(_shake_bubble_layer):
		return _shake_bubble_layer
	_shake_bubble_layer = get_node_or_null(SHAKE_BUBBLE_LAYER_NAME) as Node2D
	if _shake_bubble_layer == null:
		_shake_bubble_layer = Node2D.new()
		_shake_bubble_layer.name = SHAKE_BUBBLE_LAYER_NAME
		add_child(_shake_bubble_layer)
	_shake_bubble_layer.top_level = true
	_shake_bubble_layer.global_position = Vector2.ZERO
	_shake_bubble_layer.z_as_relative = false
	_shake_bubble_layer.z_index = SHAKE_BUBBLE_LAYER_Z_INDEX
	return _shake_bubble_layer


func _build_bubble_sprite(bubble: Node2D, quality: String) -> void:
	var texture := _load_shake_bubble_texture()
	if texture == null:
		return
	var variant := randi_range(0, SHAKE_BUBBLE_VARIANT_COUNT - 1)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		Vector2(float(variant) * SHAKE_BUBBLE_SLOT_SIZE.x, float(_shake_bubble_region_row(quality)) * SHAKE_BUBBLE_SLOT_SIZE.y),
		SHAKE_BUBBLE_SLOT_SIZE
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * _shake_bubble_sprite_scale(quality)
	sprite.flip_h = randf() > 0.5
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.94)
	bubble.set_meta(SHAKE_BUBBLE_VARIANT_META, variant)
	bubble.add_child(sprite)


func _load_shake_bubble_texture() -> Texture2D:
	if _shake_bubble_texture != null:
		return _shake_bubble_texture
	var imported := TextureManager.try_load(SHAKE_BUBBLE_TEXTURE_PATH)
	if imported != null:
		_shake_bubble_texture = imported
		return _shake_bubble_texture
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(SHAKE_BUBBLE_TEXTURE_PATH))
	if err != OK:
		push_warning("[Brewery] missing barrel bubble texture: " + SHAKE_BUBBLE_TEXTURE_PATH)
		return null
	var image_texture := ImageTexture.create_from_image(image)
	image_texture.resource_path = SHAKE_BUBBLE_TEXTURE_PATH
	_shake_bubble_texture = image_texture
	return _shake_bubble_texture


func _update_shake_bubbles(delta: float) -> void:
	if _shake_bubbles.is_empty():
		return
	for i in range(_shake_bubbles.size() - 1, -1, -1):
		var bubble := _shake_bubbles[i]
		if bubble == null or not is_instance_valid(bubble) or bubble.is_queued_for_deletion():
			_shake_bubbles.remove_at(i)
			continue
		var velocity := bubble.get_meta(SHAKE_BUBBLE_VELOCITY_META) as Vector2
		var phase := float(bubble.get_meta(SHAKE_BUBBLE_PHASE_META))
		var phase_speed := float(bubble.get_meta(SHAKE_BUBBLE_PHASE_SPEED_META))
		var lateral_influence := float(bubble.get_meta(SHAKE_BUBBLE_LATERAL_INFLUENCE_META, 0.0))
		phase += delta * phase_speed
		bubble.set_meta(SHAKE_BUBBLE_PHASE_META, phase)
		var wander := sin(phase) * (9.0 + lateral_influence * SHAKE_BUBBLE_FOAM_WANDER_BONUS)
		bubble.global_position += Vector2(velocity.x + wander, velocity.y) * delta
		if bubble.global_position.y <= SHAKE_BUBBLE_OFFSCREEN_Y:
			_shake_bubbles.remove_at(i)
			bubble.queue_free()


func _prune_invalid_shake_bubbles() -> void:
	for i in range(_shake_bubbles.size() - 1, -1, -1):
		var bubble := _shake_bubbles[i]
		if bubble == null or not is_instance_valid(bubble) or bubble.is_queued_for_deletion():
			_shake_bubbles.remove_at(i)


func _update_brew_combo(delta: float, counted_shake: bool) -> void:
	if counted_shake and not _pending_keys.is_empty():
		_brew_combo += 1
		_brew_combo_idle_time = 0.0
		_brew_combo_pulse = 0.18
		var rank_index := _brew_combo_rank_index(_brew_combo)
		if rank_index > _brew_combo_peak_rank:
			_brew_combo_peak_rank = rank_index
			_spawn_brew_combo_rank_burst(_brew_combo_rank_text(_brew_combo), rank_index)
		if _brew_combo >= _shake.min_count:
			_add_brew_screen_shake(_brew_combo_shake_amount(_brew_combo))
		if _brew_combo >= _shake.good_count:
			_spawn_brew_combo_spark_burst(_brew_combo_stage())
		_ensure_brew_combo_hud()
		_refresh_brew_combo_hud()
		return
	if _brew_combo <= 0:
		return
	_brew_combo_idle_time += delta
	if _brew_combo_idle_time >= BREW_COMBO_IDLE_RESET_TIME:
		_reset_brew_combo_feedback()


func _brew_combo_rank_index(combo: int) -> int:
	if combo >= 40:
		return 6 + int(floor(float(combo - 40) / 12.0))
	if combo >= 28:
		return 5
	if combo >= 20:
		return 4
	if combo >= 14:
		return 3
	if combo >= 8:
		return 2
	if combo >= 4:
		return 1
	return 0


func _brew_combo_rank_text(combo: int) -> String:
	if combo >= 40:
		return "酒神 +%d" % (1 + int(floor(float(combo - 40) / 12.0)))
	if combo >= 28:
		return "酒神"
	if combo >= 20:
		return "神酿"
	if combo >= 14:
		return "醇爆"
	if combo >= 8:
		return "沸腾"
	if combo >= 4:
		return "上劲"
	return "起泡"


func _brew_combo_stage() -> int:
	if _brew_combo >= _shake.good_count + 30:
		return 5
	if _brew_combo >= _shake.good_count + 16:
		return 4
	if _brew_combo >= _shake.good_count:
		return 3
	if _brew_combo >= maxi(_shake.min_count, _shake.good_count - 2):
		return 2
	if _brew_combo >= _shake.min_count:
		return 1
	return 0


func _brew_combo_shake_amount(combo: int) -> float:
	if combo < _shake.min_count:
		return 0.0
	if combo < _shake.good_count:
		return 1.45
	if combo < _shake.good_count + 12:
		return 3.25
	return minf(BREW_COMBO_SHAKE_MAX, 4.2 + float(combo - _shake.good_count) * 0.08)


func _ensure_brew_combo_hud() -> CanvasLayer:
	if _brew_combo_hud != null and is_instance_valid(_brew_combo_hud):
		return _brew_combo_hud
	_brew_combo_hud = get_node_or_null(BREW_COMBO_HUD_NAME) as CanvasLayer
	if _brew_combo_hud == null:
		_brew_combo_hud = CanvasLayer.new()
		_brew_combo_hud.name = BREW_COMBO_HUD_NAME
		_brew_combo_hud.layer = 60
		add_child(_brew_combo_hud)
	_build_brew_combo_hud_labels()
	return _brew_combo_hud


func _build_brew_combo_hud_labels() -> void:
	if _brew_combo_hud == null:
		return
	_brew_combo_label = _brew_combo_hud.get_node_or_null("ComboLabel") as Label
	if _brew_combo_label == null:
		_brew_combo_label = Label.new()
		_brew_combo_label.name = "ComboLabel"
		_brew_combo_label.position = Vector2(830.0, 82.0)
		_brew_combo_label.size = Vector2(390.0, 42.0)
		_brew_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_brew_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_brew_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_brew_combo_hud.add_child(_brew_combo_label)
	_brew_combo_label.add_theme_font_override("font", GOOD_CELEBRATION_FONT)
	_brew_combo_label.add_theme_font_size_override("font_size", 28)
	_brew_combo_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.24, 1.0))
	_brew_combo_label.add_theme_constant_override("outline_size", 4)
	_brew_combo_label.add_theme_color_override("font_outline_color", Color(0.07, 0.02, 0.01, 0.92))

	_brew_combo_rank_label = _brew_combo_hud.get_node_or_null("RankLabel") as Label
	if _brew_combo_rank_label == null:
		_brew_combo_rank_label = Label.new()
		_brew_combo_rank_label.name = "RankLabel"
		_brew_combo_rank_label.position = Vector2(890.0, 126.0)
		_brew_combo_rank_label.size = Vector2(330.0, 46.0)
		_brew_combo_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_brew_combo_rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_brew_combo_rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_brew_combo_hud.add_child(_brew_combo_rank_label)
	_brew_combo_rank_label.add_theme_font_override("font", GOOD_CELEBRATION_FONT)
	_brew_combo_rank_label.add_theme_font_size_override("font_size", 34)
	_brew_combo_rank_label.add_theme_color_override("font_color", _brew_combo_rank_color(_brew_combo_rank_index(maxi(_brew_combo, 1))))
	_brew_combo_rank_label.add_theme_constant_override("outline_size", 5)
	_brew_combo_rank_label.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.02, 0.94))


func _refresh_brew_combo_hud() -> void:
	var hud := _ensure_brew_combo_hud()
	if hud == null:
		return
	if _brew_combo_label == null or _brew_combo_rank_label == null:
		_build_brew_combo_hud_labels()
	if _brew_combo_label == null or _brew_combo_rank_label == null:
		return
	_brew_combo_label.visible = _brew_combo > 0
	_brew_combo_rank_label.visible = _brew_combo > 0
	_brew_combo_label.text = "BREW COMBO x%d" % _brew_combo
	var rank_index := _brew_combo_rank_index(_brew_combo)
	_brew_combo_rank_label.text = _brew_combo_rank_text(_brew_combo)
	_brew_combo_rank_label.add_theme_color_override("font_color", _brew_combo_rank_color(rank_index))


func _update_brew_combo_hud(delta: float) -> void:
	if _brew_combo_label == null or _brew_combo_rank_label == null:
		return
	_brew_combo_pulse = maxf(0.0, _brew_combo_pulse - delta)
	var pulse := 1.0 + minf(1.0, _brew_combo_pulse / 0.18) * 0.18
	_brew_combo_label.scale = Vector2.ONE * pulse
	_brew_combo_rank_label.scale = Vector2.ONE * (1.0 + (pulse - 1.0) * 1.45)


func _brew_combo_rank_color(rank_index: int) -> Color:
	if rank_index >= 6:
		return Color(1.0, 0.34, 0.92, 1.0)
	if rank_index >= 5:
		return Color(1.0, 0.70, 0.22, 1.0)
	if rank_index >= 4:
		return Color(0.78, 0.96, 1.0, 1.0)
	if rank_index >= 3:
		return Color(1.0, 0.43, 0.18, 1.0)
	if rank_index >= 2:
		return Color(0.62, 0.86, 1.0, 1.0)
	if rank_index >= 1:
		return Color(0.88, 0.82, 0.62, 1.0)
	return Color(0.78, 0.80, 0.76, 1.0)


func _ensure_brew_combo_vfx_layer() -> Node2D:
	if _brew_combo_vfx_layer != null and is_instance_valid(_brew_combo_vfx_layer):
		return _brew_combo_vfx_layer
	_brew_combo_vfx_layer = get_node_or_null(BREW_COMBO_VFX_LAYER_NAME) as Node2D
	if _brew_combo_vfx_layer == null:
		_brew_combo_vfx_layer = Node2D.new()
		_brew_combo_vfx_layer.name = BREW_COMBO_VFX_LAYER_NAME
		add_child(_brew_combo_vfx_layer)
	_brew_combo_vfx_layer.top_level = true
	_brew_combo_vfx_layer.global_position = Vector2.ZERO
	_brew_combo_vfx_layer.z_as_relative = false
	_brew_combo_vfx_layer.z_index = BREW_COMBO_VFX_LAYER_Z_INDEX
	return _brew_combo_vfx_layer


func _spawn_brew_combo_rank_burst(text: String, rank_index: int) -> void:
	_prune_invalid_brew_combo_vfx()
	if _brew_combo_vfx_effects.size() >= BREW_COMBO_MAX_ACTIVE_VFX:
		return
	var layer := _ensure_brew_combo_vfx_layer()
	var effect := Node2D.new()
	effect.name = "ComboRankBurst"
	effect.z_index = 8
	effect.scale = Vector2.ONE * randf_range(0.82, 1.05)
	effect.set_meta(BREW_COMBO_ELEMENT_META, "rank")
	effect.set_meta(BREW_COMBO_VELOCITY_META, Vector2(randf_range(-18.0, 18.0), -randf_range(58.0, 92.0)))
	effect.set_meta(BREW_COMBO_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(BREW_COMBO_PHASE_SPEED_META, randf_range(1.2, 2.4))
	effect.set_meta(BREW_COMBO_LIFE_META, 0.0)
	effect.set_meta(BREW_COMBO_MAX_LIFE_META, randf_range(0.72, 1.05))
	effect.set_meta(BREW_COMBO_BASE_SCALE_META, effect.scale.x)
	layer.add_child(effect)
	effect.global_position = _output_anchor.global_position + Vector2(randf_range(-28.0, 28.0), randf_range(-78.0, -54.0))
	var label := Label.new()
	label.name = "Label"
	label.text = text
	label.size = Vector2(160.0, 40.0)
	label.position = Vector2(-80.0, -20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GOOD_CELEBRATION_FONT)
	label.add_theme_font_size_override("font_size", 26 if rank_index < 6 else 30)
	label.add_theme_color_override("font_color", _brew_combo_rank_color(rank_index))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.02, 0.92))
	effect.add_child(label)
	_brew_combo_vfx_effects.append(effect)


func _spawn_brew_combo_spark_burst(stage: int) -> void:
	_prune_invalid_brew_combo_vfx()
	var spawn_count := clampi(stage + int(float(_brew_combo) / 18.0), 3, 10)
	for i in range(spawn_count):
		if _brew_combo_vfx_effects.size() >= BREW_COMBO_MAX_ACTIVE_VFX:
			return
		_spawn_brew_combo_spark(stage, i, spawn_count)
	if stage >= 5 and randi_range(0, 4) == 0:
		_spawn_brew_combo_rank_burst(BREW_COMBO_SPARK_WORDS[randi_range(0, BREW_COMBO_SPARK_WORDS.size() - 1)], _brew_combo_rank_index(_brew_combo))


func _spawn_brew_combo_spark(stage: int, index: int, count: int) -> void:
	var layer := _ensure_brew_combo_vfx_layer()
	var effect := Node2D.new()
	effect.name = "ComboSpark"
	effect.z_index = 2
	effect.set_meta(BREW_COMBO_ELEMENT_META, "spark")
	var angle := lerpf(-PI * 0.92, -PI * 0.08, (float(index) + randf_range(0.15, 0.85)) / float(maxi(count, 1)))
	var distance := randf_range(20.0, 48.0 + float(stage) * 8.0)
	var offset := Vector2(cos(angle), sin(angle)) * distance
	effect.set_meta(BREW_COMBO_VELOCITY_META, Vector2(offset.x * randf_range(0.7, 1.35), -randf_range(58.0, 118.0 + stage * 14.0)))
	effect.set_meta(BREW_COMBO_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(BREW_COMBO_PHASE_SPEED_META, randf_range(1.8, 3.8))
	effect.set_meta(BREW_COMBO_LIFE_META, 0.0)
	effect.set_meta(BREW_COMBO_MAX_LIFE_META, randf_range(0.45, 0.86))
	layer.add_child(effect)
	effect.global_position = _output_anchor.global_position + offset + Vector2(randf_range(-6.0, 6.0), randf_range(-14.0, 0.0))
	_build_brew_combo_spark_sprite(effect, stage)
	_brew_combo_vfx_effects.append(effect)


func _build_brew_combo_spark_sprite(effect: Node2D, stage: int) -> void:
	var texture := _load_good_celebration_texture()
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = true
	sprite.region_enabled = true
	var row := 2 if stage < 5 else 3
	var variant := randi_range(0, GOOD_CELEBRATION_VARIANT_COUNT - 1)
	sprite.region_rect = Rect2(
		Vector2(float(variant) * GOOD_CELEBRATION_SLOT_SIZE.x, float(row) * GOOD_CELEBRATION_SLOT_SIZE.y),
		GOOD_CELEBRATION_SLOT_SIZE
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * randf_range(0.18, 0.34)
	sprite.flip_h = randf() > 0.5
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.94)
	effect.set_meta(BREW_COMBO_BASE_SCALE_META, sprite.scale.x)
	effect.add_child(sprite)


func _update_brew_combo_vfx(delta: float) -> void:
	if _brew_combo_vfx_effects.is_empty():
		return
	for i in range(_brew_combo_vfx_effects.size() - 1, -1, -1):
		var effect := _brew_combo_vfx_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_brew_combo_vfx_effects.remove_at(i)
			continue
		var velocity := effect.get_meta(BREW_COMBO_VELOCITY_META) as Vector2
		var phase := float(effect.get_meta(BREW_COMBO_PHASE_META))
		var phase_speed := float(effect.get_meta(BREW_COMBO_PHASE_SPEED_META))
		var life := float(effect.get_meta(BREW_COMBO_LIFE_META)) + delta
		var max_life := float(effect.get_meta(BREW_COMBO_MAX_LIFE_META))
		var element := String(effect.get_meta(BREW_COMBO_ELEMENT_META, ""))
		phase += delta * phase_speed
		effect.set_meta(BREW_COMBO_PHASE_META, phase)
		effect.set_meta(BREW_COMBO_LIFE_META, life)
		effect.global_position += Vector2(velocity.x + sin(phase) * 5.0, velocity.y) * delta
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		effect.modulate.a = clampf(1.0 - progress, 0.0, 1.0)
		if element == "rank":
			var base_scale := float(effect.get_meta(BREW_COMBO_BASE_SCALE_META, 0.94))
			effect.scale = Vector2.ONE * base_scale * lerpf(0.8, 1.18, sin(progress * PI))
		if effect.global_position.y <= BREW_COMBO_VFX_OFFSCREEN_Y or life >= max_life:
			_brew_combo_vfx_effects.remove_at(i)
			effect.queue_free()


func _prune_invalid_brew_combo_vfx() -> void:
	for i in range(_brew_combo_vfx_effects.size() - 1, -1, -1):
		var effect := _brew_combo_vfx_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_brew_combo_vfx_effects.remove_at(i)


func _add_brew_screen_shake(amount: float) -> void:
	if amount <= 0.0:
		return
	_screen_shake_amount = minf(BREW_COMBO_SHAKE_MAX, maxf(_screen_shake_amount, amount))
	_ensure_brew_shake_camera()


func _ensure_brew_shake_camera() -> Camera2D:
	if _brew_shake_camera != null and is_instance_valid(_brew_shake_camera):
		return _brew_shake_camera
	_brew_shake_camera = get_node_or_null(BREW_COMBO_CAMERA_NAME) as Camera2D
	if _brew_shake_camera == null:
		_brew_shake_camera = Camera2D.new()
		_brew_shake_camera.name = BREW_COMBO_CAMERA_NAME
		_brew_shake_camera.top_level = true
		add_child(_brew_shake_camera)
	_brew_shake_camera.global_position = get_viewport_rect().size * 0.5
	_brew_shake_camera.zoom = Vector2.ONE
	_brew_shake_camera.make_current()
	return _brew_shake_camera


func _update_brew_screen_shake(delta: float) -> void:
	if _screen_shake_amount <= 0.0:
		if _brew_shake_camera != null and is_instance_valid(_brew_shake_camera):
			_brew_shake_camera.offset = Vector2.ZERO
		return
	var camera := _ensure_brew_shake_camera()
	if camera == null:
		return
	camera.global_position = get_viewport_rect().size * 0.5
	_screen_shake_phase += delta * 42.0
	camera.offset = Vector2(
		sin(_screen_shake_phase * 1.73),
		cos(_screen_shake_phase * 2.11)
	) * _screen_shake_amount
	_screen_shake_amount = maxf(0.0, _screen_shake_amount - BREW_COMBO_SHAKE_DECAY * delta)


func _reset_brew_combo_feedback() -> void:
	_brew_combo = 0
	_brew_combo_idle_time = 0.0
	_brew_combo_pulse = 0.0
	_brew_combo_peak_rank = -1
	if _brew_combo_label != null and is_instance_valid(_brew_combo_label):
		_brew_combo_label.visible = false
	if _brew_combo_rank_label != null and is_instance_valid(_brew_combo_rank_label):
		_brew_combo_rank_label.visible = false
	_screen_shake_amount = 0.0
	if _brew_shake_camera != null and is_instance_valid(_brew_shake_camera):
		_brew_shake_camera.offset = Vector2.ZERO
	if _brew_combo_vfx_layer != null and is_instance_valid(_brew_combo_vfx_layer):
		for child in _brew_combo_vfx_layer.get_children():
			child.queue_free()
	_brew_combo_vfx_effects.clear()


func _spawn_normal_brew_feedback(origin: Vector2) -> void:
	_prune_invalid_normal_brew_feedback()
	if _normal_feedback_effects.size() >= NORMAL_FEEDBACK_MAX_ACTIVE:
		return
	var layer := _ensure_normal_feedback_layer()
	var effect := Node2D.new()
	effect.name = "NormalWordBurst"
	effect.z_index = 0
	effect.scale = Vector2.ONE * randf_range(0.76, 0.9)
	var word := NORMAL_FEEDBACK_WORDS[randi_range(0, NORMAL_FEEDBACK_WORDS.size() - 1)]
	effect.set_meta(NORMAL_FEEDBACK_WORD_META, word)
	effect.set_meta(NORMAL_FEEDBACK_VELOCITY_META, Vector2(randf_range(-10.0, 10.0), -randf_range(48.0, 72.0)))
	effect.set_meta(NORMAL_FEEDBACK_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(NORMAL_FEEDBACK_PHASE_SPEED_META, randf_range(1.0, 2.0))
	effect.set_meta(NORMAL_FEEDBACK_LIFE_META, 0.0)
	effect.set_meta(NORMAL_FEEDBACK_MAX_LIFE_META, randf_range(0.72, 0.96))
	effect.set_meta(NORMAL_FEEDBACK_BASE_SCALE_META, effect.scale.x)
	layer.add_child(effect)
	effect.global_position = origin + Vector2(randf_range(-12.0, 12.0), randf_range(-42.0, -30.0))
	_build_normal_brew_feedback_label(effect, word)
	_normal_feedback_effects.append(effect)


func _spawn_failed_brew_feedback(origin: Vector2) -> void:
	_prune_invalid_normal_brew_feedback()
	if _normal_feedback_effects.size() >= NORMAL_FEEDBACK_MAX_ACTIVE:
		return
	var layer := _ensure_failed_feedback_layer()
	var effect := Node2D.new()
	effect.name = "FailedWordBurst"
	effect.z_index = 0
	effect.scale = Vector2.ONE * randf_range(0.74, 0.86)
	var word := "废品"
	effect.set_meta(FAILED_FEEDBACK_KIND_META, "failed")
	effect.set_meta(FAILED_FEEDBACK_WORD_META, word)
	effect.set_meta(NORMAL_FEEDBACK_WORD_META, word)
	effect.set_meta(NORMAL_FEEDBACK_VELOCITY_META, Vector2(randf_range(-8.0, 8.0), -randf_range(38.0, 58.0)))
	effect.set_meta(NORMAL_FEEDBACK_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(NORMAL_FEEDBACK_PHASE_SPEED_META, randf_range(0.8, 1.6))
	effect.set_meta(NORMAL_FEEDBACK_LIFE_META, 0.0)
	effect.set_meta(NORMAL_FEEDBACK_MAX_LIFE_META, randf_range(0.78, 1.04))
	effect.set_meta(NORMAL_FEEDBACK_BASE_SCALE_META, effect.scale.x)
	layer.add_child(effect)
	effect.global_position = origin + Vector2(randf_range(-10.0, 10.0), randf_range(-38.0, -28.0))
	_build_failed_brew_feedback_label(effect, word)
	_normal_feedback_effects.append(effect)


func _ensure_normal_feedback_layer() -> Node2D:
	if _normal_feedback_layer != null and is_instance_valid(_normal_feedback_layer):
		return _normal_feedback_layer
	_normal_feedback_layer = get_node_or_null(NORMAL_FEEDBACK_LAYER_NAME) as Node2D
	if _normal_feedback_layer == null:
		_normal_feedback_layer = Node2D.new()
		_normal_feedback_layer.name = NORMAL_FEEDBACK_LAYER_NAME
		add_child(_normal_feedback_layer)
	_normal_feedback_layer.top_level = true
	_normal_feedback_layer.global_position = Vector2.ZERO
	_normal_feedback_layer.z_as_relative = false
	_normal_feedback_layer.z_index = NORMAL_FEEDBACK_LAYER_Z_INDEX
	return _normal_feedback_layer


func _ensure_failed_feedback_layer() -> Node2D:
	if _failed_feedback_layer != null and is_instance_valid(_failed_feedback_layer):
		return _failed_feedback_layer
	_failed_feedback_layer = get_node_or_null(FAILED_FEEDBACK_LAYER_NAME) as Node2D
	if _failed_feedback_layer == null:
		_failed_feedback_layer = Node2D.new()
		_failed_feedback_layer.name = FAILED_FEEDBACK_LAYER_NAME
		add_child(_failed_feedback_layer)
	_failed_feedback_layer.top_level = true
	_failed_feedback_layer.global_position = Vector2.ZERO
	_failed_feedback_layer.z_as_relative = false
	_failed_feedback_layer.z_index = NORMAL_FEEDBACK_LAYER_Z_INDEX
	return _failed_feedback_layer


func _build_normal_brew_feedback_label(effect: Node2D, word: String) -> void:
	var label := Label.new()
	label.name = "Label"
	label.text = word
	label.size = Vector2(76.0, 28.0)
	label.position = Vector2(-38.0, -14.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GOOD_CELEBRATION_FONT)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.72, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.07, 0.82))
	effect.add_child(label)


func _build_failed_brew_feedback_label(effect: Node2D, word: String) -> void:
	var label := Label.new()
	label.name = "Label"
	label.text = word
	label.size = Vector2(76.0, 28.0)
	label.position = Vector2(-38.0, -14.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GOOD_CELEBRATION_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.48, 0.44, 0.34, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.02, 0.92))
	effect.add_child(label)


func _update_normal_brew_feedback(delta: float) -> void:
	if _normal_feedback_effects.is_empty():
		return
	for i in range(_normal_feedback_effects.size() - 1, -1, -1):
		var effect := _normal_feedback_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_normal_feedback_effects.remove_at(i)
			continue
		var velocity := effect.get_meta(NORMAL_FEEDBACK_VELOCITY_META) as Vector2
		var phase := float(effect.get_meta(NORMAL_FEEDBACK_PHASE_META))
		var phase_speed := float(effect.get_meta(NORMAL_FEEDBACK_PHASE_SPEED_META))
		var life := float(effect.get_meta(NORMAL_FEEDBACK_LIFE_META)) + delta
		var max_life := float(effect.get_meta(NORMAL_FEEDBACK_MAX_LIFE_META))
		phase += delta * phase_speed
		effect.set_meta(NORMAL_FEEDBACK_PHASE_META, phase)
		effect.set_meta(NORMAL_FEEDBACK_LIFE_META, life)
		var wander := sin(phase) * 3.0
		effect.global_position += Vector2(velocity.x + wander, velocity.y) * delta
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		var alpha := clampf(1.0 - progress, 0.0, 1.0)
		var base_scale := float(effect.get_meta(NORMAL_FEEDBACK_BASE_SCALE_META, 0.82))
		effect.modulate.a = minf(0.9, alpha * 1.18)
		effect.scale = Vector2.ONE * base_scale * lerpf(0.92, 1.08, sin(progress * PI))
		if effect.global_position.y <= NORMAL_FEEDBACK_OFFSCREEN_Y or life >= max_life:
			_normal_feedback_effects.remove_at(i)
			effect.queue_free()


func _prune_invalid_normal_brew_feedback() -> void:
	for i in range(_normal_feedback_effects.size() - 1, -1, -1):
		var effect := _normal_feedback_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_normal_feedback_effects.remove_at(i)


func _spawn_good_brew_celebration(origin: Vector2, product_velocity: Vector2) -> void:
	_spawn_good_mouth_flash(origin)
	_spawn_good_ring(origin)
	_spawn_good_beams(origin)
	_spawn_good_sparkles(origin)
	_spawn_good_gold_bubbles(origin)
	_spawn_good_aroma(origin)
	_spawn_good_product_trail(origin, product_velocity)
	_spawn_good_word_burst(origin)
	_spawn_good_stamp(origin)


func _spawn_good_mouth_flash(origin: Vector2) -> void:
	for i in range(3):
		_spawn_good_celebration_effect(
			"mouth_flash",
			origin + Vector2(randf_range(-6.0, 6.0), randf_range(-14.0, -4.0)),
			Vector2(randf_range(-8.0, 8.0), -randf_range(18.0, 36.0)),
			randf_range(0.22, 0.34)
		)


func _spawn_good_ring(origin: Vector2) -> void:
	for i in range(2):
		_spawn_good_celebration_effect(
			"ring",
			origin + Vector2(randf_range(-3.0, 3.0), randf_range(-6.0, 2.0)),
			Vector2(randf_range(-4.0, 4.0), randf_range(-18.0, -8.0)),
			randf_range(0.34, 0.48)
		)


func _spawn_good_beams(origin: Vector2) -> void:
	for i in range(7):
		var x := lerpf(-16.0, 16.0, (float(i) + randf_range(0.2, 0.8)) / 7.0)
		_spawn_good_celebration_effect(
			"beam",
			origin + Vector2(x, -16.0 - i * 7.0 + randf_range(-4.0, 4.0)),
			Vector2(randf_range(-8.0, 8.0), randf_range(-30.0, -58.0)),
			randf_range(0.36, 0.62)
		)


func _spawn_good_sparkles(origin: Vector2) -> void:
	for i in range(22):
		var angle := randf_range(-PI * 0.92, -PI * 0.08)
		var distance := randf_range(18.0, 68.0)
		var offset := Vector2(cos(angle), sin(angle)) * distance + Vector2(randf_range(-12.0, 12.0), -10.0)
		_spawn_good_celebration_effect(
			"star",
			origin + offset,
			Vector2(offset.x * randf_range(0.82, 1.48), -randf_range(42.0, 102.0)),
			randf_range(0.58, 1.02)
		)


func _spawn_good_gold_bubbles(origin: Vector2) -> void:
	for i in range(14):
		var slot_fraction := (float(i) + randf_range(0.15, 0.85)) / 14.0
		var x := lerpf(-42.0, 42.0, slot_fraction) + randf_range(-6.0, 6.0)
		_spawn_good_celebration_effect(
			"gold_bubble",
			origin + Vector2(x, randf_range(-12.0, 4.0)),
			Vector2(randf_range(-36.0, 36.0), -randf_range(104.0, 178.0)),
			randf_range(0.92, 1.44)
		)


func _spawn_good_aroma(origin: Vector2) -> void:
	for i in range(7):
		var x := lerpf(-30.0, 30.0, (float(i) + randf_range(0.2, 0.8)) / 7.0)
		_spawn_good_celebration_effect(
			"aroma",
			origin + Vector2(x, randf_range(-18.0, -4.0)),
			Vector2(randf_range(-22.0, 22.0), -randf_range(62.0, 106.0)),
			randf_range(1.0, 1.56)
		)


func _spawn_good_product_trail(origin: Vector2, product_velocity: Vector2) -> void:
	var direction := product_velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(0.0, -1.0)
	var behind := -direction
	for i in range(8):
		var offset := behind * randf_range(8.0, 58.0) + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 12.0))
		_spawn_good_celebration_effect(
			"trail",
			origin + offset,
			Vector2(randf_range(-24.0, 24.0), -randf_range(32.0, 74.0)),
			randf_range(0.42, 0.76)
		)


func _spawn_good_word_burst(origin: Vector2) -> void:
	for i in range(2):
		var x := -22.0 if i == 0 else 22.0
		x += randf_range(-8.0, 8.0)
		_spawn_good_celebration_word(
			origin + Vector2(x, randf_range(-50.0, -34.0)),
			Vector2(randf_range(-18.0, 18.0), -randf_range(84.0, 126.0)),
			randf_range(0.82, 1.12)
		)


func _spawn_good_stamp(origin: Vector2) -> void:
	_prune_invalid_good_celebration_effects()
	if _good_celebration_effects.size() >= GOOD_CELEBRATION_MAX_ACTIVE:
		return
	var layer := _ensure_good_celebration_layer()
	var effect := Node2D.new()
	effect.name = "QualityStamp"
	effect.z_index = 8
	effect.scale = Vector2.ONE * randf_range(0.96, 1.12)
	var word := GOOD_CELEBRATION_WORDS[randi_range(0, GOOD_CELEBRATION_WORDS.size() - 1)]
	effect.set_meta(GOOD_CELEBRATION_ELEMENT_META, "stamp")
	effect.set_meta(GOOD_CELEBRATION_WORD_META, word)
	effect.set_meta(GOOD_CELEBRATION_VELOCITY_META, Vector2(randf_range(-10.0, 10.0), -randf_range(34.0, 58.0)))
	effect.set_meta(GOOD_CELEBRATION_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(GOOD_CELEBRATION_PHASE_SPEED_META, randf_range(0.9, 1.6))
	effect.set_meta(GOOD_CELEBRATION_LIFE_META, 0.0)
	effect.set_meta(GOOD_CELEBRATION_MAX_LIFE_META, randf_range(1.0, 1.34))
	effect.set_meta(GOOD_CELEBRATION_BASE_SCALE_META, effect.scale.x)
	layer.add_child(effect)
	effect.global_position = origin + Vector2(randf_range(-10.0, 10.0), randf_range(-74.0, -58.0))
	_build_good_stamp_label(effect, word)
	_good_celebration_effects.append(effect)


func _spawn_good_celebration_effect(element: String, origin: Vector2, velocity: Vector2, max_life: float) -> void:
	_prune_invalid_good_celebration_effects()
	if _good_celebration_effects.size() >= GOOD_CELEBRATION_MAX_ACTIVE:
		return
	var layer := _ensure_good_celebration_layer()
	var effect := Node2D.new()
	effect.name = "Celebration"
	effect.z_index = 6 if element == "mouth_flash" else 0
	effect.set_meta(GOOD_CELEBRATION_ELEMENT_META, element)
	effect.set_meta(GOOD_CELEBRATION_VELOCITY_META, velocity)
	effect.set_meta(GOOD_CELEBRATION_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(GOOD_CELEBRATION_PHASE_SPEED_META, randf_range(1.2, 3.2))
	effect.set_meta(GOOD_CELEBRATION_LIFE_META, 0.0)
	effect.set_meta(GOOD_CELEBRATION_MAX_LIFE_META, max_life)
	layer.add_child(effect)
	effect.global_position = origin
	_build_good_celebration_sprite(effect, element)
	_good_celebration_effects.append(effect)


func _spawn_good_celebration_word(origin: Vector2, velocity: Vector2, max_life: float) -> void:
	_prune_invalid_good_celebration_effects()
	if _good_celebration_effects.size() >= GOOD_CELEBRATION_MAX_ACTIVE:
		return
	var layer := _ensure_good_celebration_layer()
	var effect := Node2D.new()
	effect.name = "WordBurst"
	effect.z_index = 4
	effect.scale = Vector2.ONE * randf_range(0.82, 1.08)
	var word := GOOD_CELEBRATION_WORDS[randi_range(0, GOOD_CELEBRATION_WORDS.size() - 1)]
	effect.set_meta(GOOD_CELEBRATION_ELEMENT_META, "word")
	effect.set_meta(GOOD_CELEBRATION_WORD_META, word)
	effect.set_meta(GOOD_CELEBRATION_VELOCITY_META, velocity)
	effect.set_meta(GOOD_CELEBRATION_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(GOOD_CELEBRATION_PHASE_SPEED_META, randf_range(1.4, 2.8))
	effect.set_meta(GOOD_CELEBRATION_LIFE_META, 0.0)
	effect.set_meta(GOOD_CELEBRATION_MAX_LIFE_META, max_life)
	effect.set_meta(GOOD_CELEBRATION_BASE_SCALE_META, effect.scale.x)
	layer.add_child(effect)
	effect.global_position = origin
	_build_good_celebration_word_label(effect, word)
	_good_celebration_effects.append(effect)


func _ensure_good_celebration_layer() -> Node2D:
	if _good_celebration_layer != null and is_instance_valid(_good_celebration_layer):
		return _good_celebration_layer
	_good_celebration_layer = get_node_or_null(GOOD_CELEBRATION_LAYER_NAME) as Node2D
	if _good_celebration_layer == null:
		_good_celebration_layer = Node2D.new()
		_good_celebration_layer.name = GOOD_CELEBRATION_LAYER_NAME
		add_child(_good_celebration_layer)
	_good_celebration_layer.top_level = true
	_good_celebration_layer.global_position = Vector2.ZERO
	_good_celebration_layer.z_as_relative = false
	_good_celebration_layer.z_index = GOOD_CELEBRATION_LAYER_Z_INDEX
	return _good_celebration_layer


func _build_good_celebration_sprite(effect: Node2D, element: String) -> void:
	var texture := _load_good_celebration_texture()
	if texture == null:
		return
	var variant := randi_range(0, GOOD_CELEBRATION_VARIANT_COUNT - 1)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		Vector2(float(variant) * GOOD_CELEBRATION_SLOT_SIZE.x, float(_good_celebration_region_row(element)) * GOOD_CELEBRATION_SLOT_SIZE.y),
		GOOD_CELEBRATION_SLOT_SIZE
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var base_scale := _good_celebration_sprite_scale(element)
	sprite.scale = Vector2.ONE * base_scale
	sprite.flip_h = randf() > 0.5
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
	effect.set_meta(GOOD_CELEBRATION_VARIANT_META, variant)
	effect.set_meta(GOOD_CELEBRATION_BASE_SCALE_META, base_scale)
	effect.add_child(sprite)


func _build_good_celebration_word_label(effect: Node2D, word: String) -> void:
	var label := Label.new()
	label.name = "Label"
	label.text = word
	label.size = Vector2(92.0, 34.0)
	label.position = Vector2(-46.0, -17.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GOOD_CELEBRATION_FONT)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.24, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.15, 0.04, 0.01, 0.9))
	effect.add_child(label)


func _build_good_stamp_label(effect: Node2D, word: String) -> void:
	var label := Label.new()
	label.name = "Label"
	label.text = word
	label.size = Vector2(124.0, 42.0)
	label.position = Vector2(-62.0, -21.0)
	label.rotation = randf_range(-0.10, 0.10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GOOD_CELEBRATION_FONT)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.20, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.13, 0.02, 0.02, 0.94))
	effect.add_child(label)


func _good_celebration_region_row(element: String) -> int:
	if element == "trail":
		return 5
	if element == "aroma":
		return 4
	if element == "gold_bubble":
		return 3
	if element == "star":
		return 2
	if element == "beam":
		return 1
	return 0


func _good_celebration_sprite_scale(element: String) -> float:
	if element == "mouth_flash":
		return randf_range(0.58, 0.72)
	if element == "ring":
		return randf_range(0.42, 0.54)
	if element == "beam":
		return randf_range(0.42, 0.58)
	if element == "star":
		return randf_range(0.24, 0.36)
	if element == "gold_bubble":
		return randf_range(0.20, 0.30)
	if element == "aroma":
		return randf_range(0.24, 0.34)
	return randf_range(0.22, 0.32)


func _load_good_celebration_texture() -> Texture2D:
	if _good_celebration_texture != null:
		return _good_celebration_texture
	var imported := TextureManager.try_load(GOOD_CELEBRATION_TEXTURE_PATH)
	if imported != null:
		_good_celebration_texture = imported
		return _good_celebration_texture
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(GOOD_CELEBRATION_TEXTURE_PATH))
	if err != OK:
		push_warning("[Brewery] missing good celebration texture: " + GOOD_CELEBRATION_TEXTURE_PATH)
		return null
	var image_texture := ImageTexture.create_from_image(image)
	image_texture.resource_path = GOOD_CELEBRATION_TEXTURE_PATH
	_good_celebration_texture = image_texture
	return _good_celebration_texture


func _update_good_celebration_effects(delta: float) -> void:
	if _good_celebration_effects.is_empty():
		return
	for i in range(_good_celebration_effects.size() - 1, -1, -1):
		var effect := _good_celebration_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_good_celebration_effects.remove_at(i)
			continue
		var velocity := effect.get_meta(GOOD_CELEBRATION_VELOCITY_META) as Vector2
		var phase := float(effect.get_meta(GOOD_CELEBRATION_PHASE_META))
		var phase_speed := float(effect.get_meta(GOOD_CELEBRATION_PHASE_SPEED_META))
		var life := float(effect.get_meta(GOOD_CELEBRATION_LIFE_META)) + delta
		var max_life := float(effect.get_meta(GOOD_CELEBRATION_MAX_LIFE_META))
		var element := String(effect.get_meta(GOOD_CELEBRATION_ELEMENT_META, ""))
		phase += delta * phase_speed
		effect.set_meta(GOOD_CELEBRATION_PHASE_META, phase)
		effect.set_meta(GOOD_CELEBRATION_LIFE_META, life)
		var wander := sin(phase) * 5.0
		effect.global_position += Vector2(velocity.x + wander, velocity.y) * delta
		var sprite := effect.get_node_or_null("Sprite") as Sprite2D
		if sprite != null:
			var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
			var alpha := clampf(1.0 - progress, 0.0, 1.0)
			sprite.modulate.a = minf(0.96, alpha * 1.24)
			if element == "ring":
				var base_scale := float(effect.get_meta(GOOD_CELEBRATION_BASE_SCALE_META, 0.48))
				sprite.scale = Vector2.ONE * base_scale * lerpf(0.82, 1.34, progress)
			elif element == "mouth_flash":
				var base_scale := float(effect.get_meta(GOOD_CELEBRATION_BASE_SCALE_META, 0.64))
				sprite.scale = Vector2.ONE * base_scale * lerpf(0.72, 1.72, progress)
		elif element == "word" or element == "stamp":
			var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
			var alpha := clampf(1.0 - progress, 0.0, 1.0)
			var base_scale := float(effect.get_meta(GOOD_CELEBRATION_BASE_SCALE_META, 0.92))
			effect.modulate.a = minf(1.0, alpha * 1.45)
			var scale_peak := 1.32 if element == "stamp" else 1.18
			effect.scale = Vector2.ONE * base_scale * lerpf(0.76, scale_peak, sin(progress * PI))
		if effect.global_position.y <= GOOD_CELEBRATION_OFFSCREEN_Y or life >= max_life:
			_good_celebration_effects.remove_at(i)
			effect.queue_free()


func _prune_invalid_good_celebration_effects() -> void:
	for i in range(_good_celebration_effects.size() - 1, -1, -1):
		var effect := _good_celebration_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_good_celebration_effects.remove_at(i)


func _load_shake_config() -> void:
	var file = FileAccess.open(BARREL_CONFIG, FileAccess.READ)
	if file == null:
		push_warning("[Brewery] barrel.json 未找到，用默认摇晃阈值")
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary and data.has("shake"):
		_shake.load_thresholds(data["shake"])


## 抓起酒桶：唤醒为动态体并开始采样摇晃（保留 codex 调好的手感，不冻结）。
func begin_shake_session() -> void:
	freeze = false
	lock_rotation = false
	sleeping = false
	_session_active = true
	_shake_bubble_spawn_elapsed = SHAKE_BUBBLE_SPAWN_INTERVAL
	GameManager.play_audio_event("barrel_shake")


## 松手结算：停止采样、尝试出酒；桶保持动态由物理自然落定（不强制冻结）。
func end_shake_session() -> void:
	_session_active = false
	lock_rotation = false
	_try_brew()


## 有料 + 摇够 + 命中配方 → 产出(带品质)。摇不够则保留料，可继续摇。
## _shake 跨多次抓握累积，只在成功出酒后 reset，对玩家更宽容。
func _try_brew() -> void:
	if _pending_keys.is_empty():
		return
	if not _shake.has_enough():
		return
	var product_key: String = GameManager.craft.query_recipe(CONTAINER_KEY, _pending_keys)
	var quality: String = _shake.quality_tier()
	var shakes: int = _shake.shake_count
	_pending_keys.clear()
	_shake.reset()
	_shake_bubble_foam_pressure = 0.0
	if product_key == "":
		product_key = GameManager.craft.failure_product_for_container(CONTAINER_KEY)
		_reset_brew_combo_feedback()
		if product_key == "":
			print("[Brewery] 摇够了但配方未命中，料已消耗无产出 (摇晃 %d 次)" % shakes)
			return
		print("[Brewery] 配方未命中，产出失败物 %s (摇晃 %d 次)" % [product_key, shakes])
		_spawn_product(product_key, "failed")
		recipe_consumed.emit(product_key)
		return
	print("[Brewery] 产出 %s  品质=%s  (摇晃 %d 次)" % [product_key, quality, shakes])
	_spawn_product(product_key, quality)
	_reset_brew_combo_feedback()
	recipe_consumed.emit(product_key)


func pop_last_ingredient() -> String:
	if _pending_keys.is_empty():
		return ""
	var item_key: String = _pending_keys.pop_back()
	_shake.reset()
	_shake_bubble_foam_pressure = 0.0
	_reset_brew_combo_feedback()
	return item_key


func ingredient_output_position() -> Vector2:
	return _output_anchor.global_position


func _fit_collision_to_art_bounds() -> void:
	var bounds: Rect2 = TEXTURE_COLLISION_BOUNDS.centered_sprite_alpha_rect(_art)
	if bounds.size == Vector2.ZERO:
		return
	var left := bounds.position.x
	var right := bounds.position.x + bounds.size.x
	var top := bounds.position.y
	var bottom := bounds.position.y + bounds.size.y
	var inset := bounds.size.x * 0.1
	var top_left := Vector2(left + inset, top)
	var top_right := Vector2(right - inset, top)
	var bottom_left := Vector2(left, bottom)
	var bottom_right := Vector2(right, bottom)
	_set_segment_shape("WallLeft", bottom_left, top_left)
	_set_segment_shape("WallRight", bottom_right, top_right)
	_set_segment_shape("WallBottom", bottom_left, bottom_right)
	_set_segment_shape("RimLeft", top_left, Vector2(-MOUTH_INNER_HALF_WIDTH, top))
	_set_segment_shape("RimRight", Vector2(MOUTH_INNER_HALF_WIDTH, top), top_right)
	var pickup := get_node_or_null("PickupArea/Shape") as CollisionPolygon2D
	if pickup != null:
		pickup.polygon = PackedVector2Array([bottom_left, top_left, top_right, bottom_right])


func _set_segment_shape(path: String, a: Vector2, b: Vector2) -> void:
	var node := get_node_or_null(path) as CollisionShape2D
	if node == null:
		return
	var segment := SegmentShape2D.new()
	segment.a = a
	segment.b = b
	node.shape = segment
