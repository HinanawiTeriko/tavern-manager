class_name SeasoningShaker
extends RigidBody2D

const INGREDIENT_INTAKE_VFX := preload("res://scripts/ui/ingredient_intake_vfx.gd")
const BREW_SHAKE_METER := preload("res://scripts/ui/brew_shake_meter.gd")

## 香料罐：常驻吧台工具。
##   装填：拖香料 DeskItem 从上方丢进罐口 → Mouth Area2D 自动吸收（仿 Brewery 吸入式）。
##   使用：抓起摇够次数 → 给罐正下方成品写 L1 属性（覆盖式）+ 效果类透传 tag，撒完即空。
## 复用 BrewShakeMeter 计摇晃；只跟 GameManager 说话（仿 Brewery 直接调 GameManager.*）。

const SHAKER_MASS := 1.2
const SHAKER_LINEAR_DAMP := 0.8
const SHAKER_ANGULAR_DAMP := 4.0
const PROBE_DOWN := 56.0
const PROBE_SIZE := Vector2(48, 48)
const PROBE_QUERY_COUNT := 8
const EMPTY_COLOR := Color(0.55, 0.55, 0.6)
const OUTPUT_LOCAL_POS := Vector2(0.0, -42.0)
const EJECT_LOCAL_VELOCITY := Vector2(280.0, -380.0)
const EJECT_IGNORE_MSEC := 900
const EJECT_IGNORE_UNTIL_META := "seasoning_shaker_ignore_until_msec"
const EJECT_IGNORE_SOURCE_META := "seasoning_shaker_ignore_source_id"
const POWDER_LAYER_NAME := "SeasoningPowderLayer"
const POWDER_LAYER_Z_INDEX := 19
const POWDER_SPAWN_INTERVAL := 0.045
const POWDER_MAX_ACTIVE := 120
const POWDER_MOVEMENT_MIN_SPEED := 70.0
const POWDER_FULL_SPEED := 720.0
const POWDER_EMIT_LOCAL_POS := Vector2(0.0, -42.0)
const POWDER_VELOCITY_META := "seasoning_powder_velocity"
const POWDER_PHASE_META := "seasoning_powder_phase"
const POWDER_PHASE_SPEED_META := "seasoning_powder_phase_speed"
const POWDER_LIFE_META := "seasoning_powder_life"
const POWDER_MAX_LIFE_META := "seasoning_powder_max_life"
const POWDER_KEY_META := "seasoning_powder_key"
const POWDER_KIND_META := "seasoning_powder_kind"
const POWDER_ROTATION_SPEED_META := "seasoning_powder_rotation_speed"
const POWDER_BASE_SCALE_META := "seasoning_powder_base_scale"
const SPICE_COMBO_HUD_NAME := "SpiceComboHud"
const SPICE_COMBO_VFX_LAYER_NAME := "SpiceComboVfx"
const SPICE_COMBO_CAMERA_NAME := "SpiceShakeCamera"
const SPICE_COMBO_IDLE_RESET_TIME := 0.92
const SPICE_COMBO_VFX_LAYER_Z_INDEX := 88
const SPICE_COMBO_MAX_ACTIVE_VFX := 96
const SPICE_COMBO_VFX_OFFSCREEN_Y := -280.0
const SPICE_COMBO_SHAKE_MAX := 3.2
const SPICE_COMBO_SHAKE_DECAY := 18.0
const SPICE_COMBO_ELEMENT_META := "spice_combo_element"
const SPICE_COMBO_VELOCITY_META := "spice_combo_velocity"
const SPICE_COMBO_PHASE_META := "spice_combo_phase"
const SPICE_COMBO_PHASE_SPEED_META := "spice_combo_phase_speed"
const SPICE_COMBO_LIFE_META := "spice_combo_life"
const SPICE_COMBO_MAX_LIFE_META := "spice_combo_max_life"
const SPICE_COMBO_BASE_SCALE_META := "spice_combo_base_scale"
const SPICE_COMBO_PRAISE_WORDS: Array[String] = ["入魂", "撒疯了", "香到离谱", "味觉暴击", "手腕封神", "厨神点头"]
const SPICE_SETTLE_WORDS: Array[String] = ["入味", "香爆", "够劲", "绝了", "撒得准", "这一口"]
const SPICE_COMBO_FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const SEASONING_PARTICLE_ATLAS := preload("res://assets/textures/seasoning_particles/seasoning_particles.png")
const SEASONING_PARTICLE_SLOT_SIZE := Vector2(96.0, 96.0)
const SEASONING_PARTICLE_VARIANT_COUNT := 4

# ── 罐口区域（吸入检测，仿 Brewery._is_point_inside_mouth_opening）──
const MOUTH_HALF_WIDTH := 34.0
const MOUTH_TOP_Y := -56.0
const MOUTH_BOTTOM_Y := -14.0

@onready var _visual: Polygon2D = $Visual
@onready var _art: Sprite2D = $Art
@onready var _closed_art: Sprite2D = $ClosedArt
@onready var _fill: Polygon2D = $Fill
@onready var _mouth: Area2D = $Mouth

var loaded_key: String = ""
var _shake := BREW_SHAKE_METER.new()
var _session_active: bool = false
var _powder_layer: Node2D = null
var _powder_particles: Array[Node2D] = []
var _powder_spawn_elapsed: float = 0.0
var _powder_emit_index: int = 0
var _stuck_powder_product: DeskItem = null
var _seasoning_combo: int = 0
var _seasoning_combo_idle_time: float = 0.0
var _seasoning_combo_pulse: float = 0.0
var _spice_combo_peak_rank: int = -1
var _spice_combo_hud: CanvasLayer = null
var _spice_combo_label: Label = null
var _spice_combo_rank_label: Label = null
var _spice_combo_vfx_layer: Node2D = null
var _spice_combo_vfx_effects: Array[Node2D] = []
var _spice_screen_shake_amount: float = 0.0
var _spice_screen_shake_phase: float = 0.0
var _spice_shake_camera: Camera2D = null


func _ready() -> void:
	mass = SHAKER_MASS
	freeze = false
	gravity_scale = 1.0
	linear_damp = SHAKER_LINEAR_DAMP
	angular_damp = SHAKER_ANGULAR_DAMP
	lock_rotation = false
	_load_shake_config()
	_refresh_visual()
	_mouth.body_entered.connect(_on_mouth_body_entered)


func _load_shake_config() -> void:
	var file = FileAccess.open("res://data/barrel.json", FileAccess.READ)
	if file == null:
		push_warning("[SeasoningShaker] barrel.json 未找到，用默认摇晃阈值")
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary and data.has("shake"):
		_shake.load_thresholds(data["shake"])


func _physics_process(delta: float) -> void:
	var counted_shake := false
	if _session_active:
		var shake_count_before := _shake.shake_count
		_shake.add_sample(linear_velocity)
		counted_shake = _shake.shake_count > shake_count_before
		_update_seasoning_combo(delta, counted_shake)
		_try_spawn_powder(delta)
	else:
		_update_seasoning_combo(delta, false)
	_update_powder_particles(delta)
	_update_spice_combo_hud(delta)
	_update_spice_combo_vfx(delta)
	_update_spice_screen_shake(delta)
	# 和酒桶一样，每帧检测已重叠的物体（兜底可能丢的 body_entered）
	for body in _mouth.get_overlapping_bodies():
		_try_accept_mouth_body(body)


# ── 罐口吸入（仿 Brewery）──

func _on_mouth_body_entered(body: Node) -> void:
	_try_accept_mouth_body(body)


func _try_accept_mouth_body(body: Node) -> void:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	if not body is DeskItem:
		return
	var item: DeskItem = body
	if item.item_key == "":
		return
	if _is_recently_ejected_item(item):
		return
	# 只接受香料，拒绝成品/普通材料
	if not GameManager.seasoning.is_seasoning(item.item_key):
		return
	if not _is_point_inside_mouth_opening(item.global_position):
		return
	INGREDIENT_INTAKE_VFX.spawn(self, item, item.item_key, _mouth_center_global_position(), _seasoning_intake_color(item.item_key))
	load_seasoning(item.item_key)
	item.queue_free()


func _is_point_inside_mouth_opening(global_pos: Vector2) -> bool:
	var local := to_local(global_pos)
	return absf(local.x) <= MOUTH_HALF_WIDTH \
		and local.y >= MOUTH_TOP_Y \
		and local.y <= MOUTH_BOTTOM_Y


func is_item_inside_mouth(item: Node2D) -> bool:
	return item != null and _is_point_inside_mouth_opening(item.global_position)


func _mouth_center_global_position() -> Vector2:
	return to_global(Vector2(0.0, (MOUTH_TOP_Y + MOUTH_BOTTOM_Y) * 0.5))


func _seasoning_intake_color(key: String) -> Color:
	var data := GameManager.seasoning.get_seasoning(key)
	var raw_color = data.get("color", [])
	if raw_color is Array and raw_color.size() >= 3:
		return Color(float(raw_color[0]), float(raw_color[1]), float(raw_color[2]), 1.0)
	return Color(0.92, 0.76, 0.36, 1.0)


# ── 装填 / 状态 ──

## 装填：消耗调用方已扣库存的香料 DeskItem，罐进入已装填态并染色。已装填时替换（旧料废弃）。
func load_seasoning(key: String) -> void:
	loaded_key = key
	_shake.reset()
	_powder_emit_index = 0
	_stuck_powder_product = null
	_reset_seasoning_combo_feedback()
	_refresh_visual()
	GameManager.play_audio_event("ingredient_drop")


func is_loaded() -> bool:
	return loaded_key != ""


func pop_last_ingredient() -> String:
	if loaded_key == "":
		return ""
	var item_key := loaded_key
	loaded_key = ""
	_shake.reset()
	_stuck_powder_product = null
	_reset_seasoning_combo_feedback()
	_refresh_visual()
	return item_key


func ingredient_output_position() -> Vector2:
	return to_global(OUTPUT_LOCAL_POS)


func ingredient_eject_velocity() -> Vector2:
	return to_global(EJECT_LOCAL_VELOCITY) - global_position


func configure_ejected_item(item: DeskItem) -> void:
	if item == null or not is_instance_valid(item):
		return
	item.set_meta(EJECT_IGNORE_UNTIL_META, Time.get_ticks_msec() + EJECT_IGNORE_MSEC)
	item.set_meta(EJECT_IGNORE_SOURCE_META, get_instance_id())
	item.angular_velocity = randf_range(-12.0, 12.0)


func _is_recently_ejected_item(item: DeskItem) -> bool:
	if not item.has_meta(EJECT_IGNORE_UNTIL_META) or not item.has_meta(EJECT_IGNORE_SOURCE_META):
		return false
	if int(item.get_meta(EJECT_IGNORE_SOURCE_META)) != get_instance_id():
		return false
	var ignore_until := int(item.get_meta(EJECT_IGNORE_UNTIL_META))
	if Time.get_ticks_msec() <= ignore_until:
		return true
	item.remove_meta(EJECT_IGNORE_UNTIL_META)
	item.remove_meta(EJECT_IGNORE_SOURCE_META)
	return false


## 抓起：唤醒并开始采样摇晃。
func begin_shake_session() -> void:
	freeze = false
	lock_rotation = false
	sleeping = false
	_session_active = true
	_powder_spawn_elapsed = POWDER_SPAWN_INTERVAL
	GameManager.play_audio_event("barrel_shake")


## 松手结算：摇够 + 罐下有成品 → 应用香料；否则保留装填，可继续摇。
func end_shake_session() -> void:
	_session_active = false
	lock_rotation = false
	if loaded_key == "" or not _shake.has_enough():
		return
	var prod := _find_stuck_powder_product()
	if prod == null:
		prod = _find_product_under()
		if prod == null:
			return
	var r: Dictionary = GameManager.resolve_seasoning_application(loaded_key, prod.item_key)
	if not bool(r.get("accepted", false)):
		return
	var applied_attribute := String(r.get("attribute", ""))
	prod.set_attribute(applied_attribute)
	for t in r.get("product_tags", []):
		prod.add_product_tag(String(t))
	_spawn_spice_settle_burst(prod.global_position + Vector2(0.0, -28.0), _seasoning_combo)
	loaded_key = ""
	_shake.reset()
	_stuck_powder_product = null
	_reset_seasoning_combo_feedback(true)
	_refresh_visual()
	GameManager.play_audio_event("product_ready")


func _find_product_under() -> DeskItem:
	var space := get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = PROBE_SIZE
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position + Vector2(0, PROBE_DOWN))
	params.collide_with_bodies = true
	params.exclude = [get_rid()]
	var hits := space.intersect_shape(params, PROBE_QUERY_COUNT)
	for h in hits:
		var c = h.get("collider")
		if c == null or not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		if c is DeskItem and GameManager.craft.is_product(c.item_key):
			return c
	return null


func _find_stuck_powder_product() -> DeskItem:
	if _stuck_powder_product == null:
		return null
	if not is_instance_valid(_stuck_powder_product) or _stuck_powder_product.is_queued_for_deletion():
		_stuck_powder_product = null
		return null
	if not GameManager.craft.is_product(_stuck_powder_product.item_key):
		_stuck_powder_product = null
		return null
	return _stuck_powder_product


func _update_seasoning_combo(delta: float, counted_shake: bool) -> void:
	if counted_shake and loaded_key != "":
		_seasoning_combo += 1
		_seasoning_combo_idle_time = 0.0
		_seasoning_combo_pulse = 0.18
		var rank_index := _spice_combo_rank_index(_seasoning_combo)
		if rank_index > _spice_combo_peak_rank:
			_spice_combo_peak_rank = rank_index
			_spawn_spice_rank_burst(_spice_combo_rank_text(_seasoning_combo), rank_index, to_global(POWDER_EMIT_LOCAL_POS))
		elif _seasoning_combo >= 7:
			_spawn_spice_rank_burst(_random_spice_combo_word(), rank_index, to_global(POWDER_EMIT_LOCAL_POS))
		if _seasoning_combo >= 4:
			_add_spice_screen_shake(_spice_combo_shake_amount(_seasoning_combo))
		if _seasoning_combo >= 7:
			_spawn_spice_spark_burst(_spice_combo_stage())
		_ensure_spice_combo_hud()
		_refresh_spice_combo_hud()
		return
	if _seasoning_combo <= 0:
		return
	_seasoning_combo_idle_time += maxf(delta, 0.0)
	if _seasoning_combo_idle_time >= SPICE_COMBO_IDLE_RESET_TIME:
		_reset_seasoning_combo_feedback()


func _ensure_spice_combo_hud() -> CanvasLayer:
	if _spice_combo_hud != null and is_instance_valid(_spice_combo_hud):
		return _spice_combo_hud
	_spice_combo_hud = get_node_or_null(SPICE_COMBO_HUD_NAME) as CanvasLayer
	if _spice_combo_hud == null:
		_spice_combo_hud = CanvasLayer.new()
		_spice_combo_hud.name = SPICE_COMBO_HUD_NAME
		_spice_combo_hud.layer = 58
		add_child(_spice_combo_hud)
	_build_spice_combo_hud_labels()
	return _spice_combo_hud


func _build_spice_combo_hud_labels() -> void:
	if _spice_combo_hud == null:
		return
	_spice_combo_label = _spice_combo_hud.get_node_or_null("ComboLabel") as Label
	if _spice_combo_label == null:
		_spice_combo_label = Label.new()
		_spice_combo_label.name = "ComboLabel"
		_spice_combo_label.position = Vector2(44.0, 86.0)
		_spice_combo_label.size = Vector2(360.0, 38.0)
		_spice_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spice_combo_hud.add_child(_spice_combo_label)
	_spice_combo_label.add_theme_font_override("font", SPICE_COMBO_FONT)
	_spice_combo_label.add_theme_font_size_override("font_size", 25)
	_spice_combo_label.add_theme_color_override("font_color", Color(0.96, 0.83, 0.38, 1.0))
	_spice_combo_label.add_theme_constant_override("outline_size", 4)
	_spice_combo_label.add_theme_color_override("font_outline_color", Color(0.05, 0.035, 0.015, 0.94))
	_spice_combo_rank_label = _spice_combo_hud.get_node_or_null("RankLabel") as Label
	if _spice_combo_rank_label == null:
		_spice_combo_rank_label = Label.new()
		_spice_combo_rank_label.name = "RankLabel"
		_spice_combo_rank_label.position = Vector2(58.0, 124.0)
		_spice_combo_rank_label.size = Vector2(330.0, 38.0)
		_spice_combo_rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spice_combo_hud.add_child(_spice_combo_rank_label)
	_spice_combo_rank_label.add_theme_font_override("font", SPICE_COMBO_FONT)
	_spice_combo_rank_label.add_theme_font_size_override("font_size", 29)
	_spice_combo_rank_label.add_theme_color_override("font_color", _spice_combo_rank_color(_seasoning_combo))
	_spice_combo_rank_label.add_theme_constant_override("outline_size", 4)
	_spice_combo_rank_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.94))


func _refresh_spice_combo_hud() -> void:
	_ensure_spice_combo_hud()
	if _spice_combo_label == null or _spice_combo_rank_label == null:
		return
	_spice_combo_label.visible = _seasoning_combo > 0
	_spice_combo_rank_label.visible = _seasoning_combo > 0
	_spice_combo_label.text = "SPICE COMBO x%d" % _seasoning_combo
	_spice_combo_rank_label.text = _spice_combo_rank_text(_seasoning_combo)
	_spice_combo_rank_label.add_theme_color_override("font_color", _spice_combo_rank_color(_seasoning_combo))


func _update_spice_combo_hud(delta: float) -> void:
	if _spice_combo_label == null or _spice_combo_rank_label == null:
		return
	_seasoning_combo_pulse = maxf(0.0, _seasoning_combo_pulse - delta)
	var pulse := 1.0 + minf(1.0, _seasoning_combo_pulse / 0.18) * 0.16
	_spice_combo_label.scale = Vector2.ONE * pulse
	_spice_combo_rank_label.scale = Vector2.ONE * (1.0 + (pulse - 1.0) * 1.35)


func _spice_combo_rank_text(combo: int) -> String:
	if combo >= 30:
		return "香料暴君 +%d" % int(floor(float(combo - 30) / 8.0) + 1.0)
	if combo >= 20:
		return "厨神手腕"
	if combo >= 12:
		return "撒疯了"
	if combo >= 7:
		return "点睛"
	if combo >= 3:
		return "入味"
	return "均匀"

func _spice_combo_rank_index(combo: int) -> int:
	if combo >= 30:
		return 5 + int(floor(float(combo - 30) / 8.0))
	if combo >= 20:
		return 4
	if combo >= 12:
		return 3
	if combo >= 7:
		return 2
	if combo >= 3:
		return 1
	return 0


func _spice_combo_rank_color(combo: int) -> Color:
	if combo >= 30:
		return Color(1.0, 0.42, 0.24, 1.0)
	if combo >= 20:
		return Color(1.0, 0.62, 0.28, 1.0)
	if combo >= 12:
		return Color(0.94, 0.82, 0.34, 1.0)
	if combo >= 7:
		return Color(0.74, 0.95, 0.46, 1.0)
	if combo >= 3:
		return Color(0.84, 0.92, 0.62, 1.0)
	return Color(0.92, 0.88, 0.68, 1.0)

func _random_spice_combo_word() -> String:
	return SPICE_COMBO_PRAISE_WORDS[randi_range(0, SPICE_COMBO_PRAISE_WORDS.size() - 1)]


func _spice_combo_stage() -> int:
	if _seasoning_combo >= 24:
		return 5
	if _seasoning_combo >= 18:
		return 4
	if _seasoning_combo >= 12:
		return 3
	if _seasoning_combo >= 7:
		return 2
	if _seasoning_combo >= 4:
		return 1
	return 0


func _spice_combo_shake_amount(combo: int) -> float:
	if combo < 4:
		return 0.0
	if combo < 7:
		return 0.85
	if combo < 12:
		return 1.55
	if combo < 20:
		return 2.25
	return minf(SPICE_COMBO_SHAKE_MAX, 2.65 + float(combo - 20) * 0.045)


func _ensure_spice_combo_vfx_layer() -> Node2D:
	if _spice_combo_vfx_layer != null and is_instance_valid(_spice_combo_vfx_layer):
		return _spice_combo_vfx_layer
	_spice_combo_vfx_layer = get_node_or_null(SPICE_COMBO_VFX_LAYER_NAME) as Node2D
	if _spice_combo_vfx_layer == null:
		_spice_combo_vfx_layer = Node2D.new()
		_spice_combo_vfx_layer.name = SPICE_COMBO_VFX_LAYER_NAME
		add_child(_spice_combo_vfx_layer)
	_spice_combo_vfx_layer.top_level = true
	_spice_combo_vfx_layer.global_position = Vector2.ZERO
	_spice_combo_vfx_layer.z_as_relative = false
	_spice_combo_vfx_layer.z_index = SPICE_COMBO_VFX_LAYER_Z_INDEX
	return _spice_combo_vfx_layer


func _spawn_spice_rank_burst(text: String, rank_index: int, origin: Vector2) -> void:
	_prune_invalid_spice_combo_vfx()
	if _spice_combo_vfx_effects.size() >= SPICE_COMBO_MAX_ACTIVE_VFX:
		return
	var layer := _ensure_spice_combo_vfx_layer()
	var effect := Node2D.new()
	effect.name = "SpiceRankBurst"
	effect.z_index = 12
	effect.scale = Vector2.ONE * randf_range(0.9, 1.12)
	effect.set_meta(SPICE_COMBO_ELEMENT_META, "rank")
	effect.set_meta(SPICE_COMBO_VELOCITY_META, Vector2(randf_range(-28.0, 28.0), -randf_range(72.0, 118.0)))
	effect.set_meta(SPICE_COMBO_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(SPICE_COMBO_PHASE_SPEED_META, randf_range(1.4, 2.8))
	effect.set_meta(SPICE_COMBO_LIFE_META, 0.0)
	effect.set_meta(SPICE_COMBO_MAX_LIFE_META, randf_range(1.0, 1.36))
	effect.set_meta(SPICE_COMBO_BASE_SCALE_META, effect.scale.x)
	layer.add_child(effect)
	effect.global_position = origin + Vector2(randf_range(-36.0, 36.0), randf_range(-76.0, -48.0))

	var label := Label.new()
	label.name = "Label"
	label.text = text
	label.size = Vector2(210.0, 46.0)
	label.position = Vector2(-105.0, -23.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", SPICE_COMBO_FONT)
	label.add_theme_font_size_override("font_size", 27 + clampi(rank_index, 0, 4))
	label.add_theme_color_override("font_color", _spice_effect_color(rank_index))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.005, 0.95))
	effect.add_child(label)
	_spice_combo_vfx_effects.append(effect)


func _spawn_spice_spark_burst(stage: int) -> void:
	_prune_invalid_spice_combo_vfx()
	var spawn_count := clampi(2 + stage + int(float(_seasoning_combo) / 10.0), 4, 12)
	for i in range(spawn_count):
		if _spice_combo_vfx_effects.size() >= SPICE_COMBO_MAX_ACTIVE_VFX:
			return
		_spawn_spice_spark(stage, i, spawn_count, to_global(POWDER_EMIT_LOCAL_POS))


func _spawn_spice_spark(stage: int, index: int, count: int, origin: Vector2) -> void:
	var layer := _ensure_spice_combo_vfx_layer()
	var effect := Node2D.new()
	effect.name = "SpiceComboSpark"
	effect.z_index = 4
	effect.set_meta(SPICE_COMBO_ELEMENT_META, "spark")
	var angle := lerpf(-PI * 0.86, -PI * 0.14, (float(index) + randf_range(0.12, 0.88)) / float(maxi(count, 1)))
	var distance := randf_range(18.0, 42.0 + float(stage) * 7.0)
	var offset := Vector2(cos(angle), sin(angle)) * distance
	effect.set_meta(SPICE_COMBO_VELOCITY_META, Vector2(offset.x * randf_range(0.85, 1.45), -randf_range(82.0, 132.0 + stage * 16.0)))
	effect.set_meta(SPICE_COMBO_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(SPICE_COMBO_PHASE_SPEED_META, randf_range(2.2, 4.6))
	effect.set_meta(SPICE_COMBO_LIFE_META, 0.0)
	effect.set_meta(SPICE_COMBO_MAX_LIFE_META, randf_range(0.62, 0.98))
	layer.add_child(effect)
	effect.global_position = origin + offset + Vector2(randf_range(-4.0, 4.0), randf_range(-8.0, 6.0))
	_build_spice_spark_pixel(effect, stage)
	_spice_combo_vfx_effects.append(effect)


func _new_seasoning_particle_sprite(element: String, variant: int) -> Sprite2D:
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


func _build_spice_spark_pixel(effect: Node2D, stage: int) -> void:
	var sprite := _new_seasoning_particle_sprite("spark", randi_range(0, SEASONING_PARTICLE_VARIANT_COUNT - 1))
	sprite.name = "Sprite"
	sprite.modulate = _spice_effect_color(_spice_combo_rank_index(maxi(_seasoning_combo, 1)))
	effect.rotation = randf_range(-0.6, 0.6)
	effect.set_meta(SPICE_COMBO_BASE_SCALE_META, randf_range(0.14, 0.23 + float(stage) * 0.012))
	effect.add_child(sprite)


func _spawn_spice_settle_burst(origin: Vector2, combo: int) -> void:
	_prune_invalid_spice_combo_vfx()
	var rank_index := _spice_combo_rank_index(maxi(combo, 1))
	var cloud_count := clampi(8 + int(floor(float(combo) / 2.0)), 8, 22)
	for i in range(cloud_count):
		if _spice_combo_vfx_effects.size() >= SPICE_COMBO_MAX_ACTIVE_VFX:
			break
		_spawn_spice_settle_cloud(origin, rank_index, i, cloud_count)
	_spawn_spice_settle_word(origin + Vector2(0.0, -42.0), rank_index)
	_add_spice_screen_shake(maxf(1.1, _spice_combo_shake_amount(combo) + 0.4))


func _spawn_spice_settle_cloud(origin: Vector2, rank_index: int, index: int, count: int) -> void:
	var layer := _ensure_spice_combo_vfx_layer()
	var effect := Node2D.new()
	effect.name = "SpiceSettleCloud"
	effect.z_index = 3
	effect.set_meta(SPICE_COMBO_ELEMENT_META, "settle_cloud")
	var angle := TAU * (float(index) + randf_range(0.15, 0.85)) / float(maxi(count, 1))
	var speed := randf_range(36.0, 92.0 + float(rank_index) * 7.0)
	effect.set_meta(SPICE_COMBO_VELOCITY_META, Vector2(cos(angle), sin(angle) * 0.7 - 0.18) * speed)
	effect.set_meta(SPICE_COMBO_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(SPICE_COMBO_PHASE_SPEED_META, randf_range(1.8, 3.8))
	effect.set_meta(SPICE_COMBO_LIFE_META, 0.0)
	effect.set_meta(SPICE_COMBO_MAX_LIFE_META, randf_range(0.62, 0.98))
	effect.set_meta(SPICE_COMBO_BASE_SCALE_META, randf_range(0.12, 0.22 + float(rank_index) * 0.008))
	layer.add_child(effect)
	effect.global_position = origin + Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 10.0))

	var sprite := _new_seasoning_particle_sprite("settle_cloud", index % SEASONING_PARTICLE_VARIANT_COUNT)
	sprite.name = "Sprite"
	var color := _spice_effect_color(rank_index)
	color.a = 0.55
	sprite.modulate = color
	effect.add_child(sprite)
	_spice_combo_vfx_effects.append(effect)


func _spawn_spice_settle_word(origin: Vector2, rank_index: int) -> void:
	if _spice_combo_vfx_effects.size() >= SPICE_COMBO_MAX_ACTIVE_VFX:
		return
	var layer := _ensure_spice_combo_vfx_layer()
	var effect := Node2D.new()
	effect.name = "SpiceSettleWord"
	effect.z_index = 16
	effect.scale = Vector2.ONE * randf_range(1.06, 1.24)
	effect.set_meta(SPICE_COMBO_ELEMENT_META, "settle_word")
	effect.set_meta(SPICE_COMBO_VELOCITY_META, Vector2(randf_range(-14.0, 14.0), -randf_range(62.0, 92.0)))
	effect.set_meta(SPICE_COMBO_PHASE_META, randf_range(0.0, TAU))
	effect.set_meta(SPICE_COMBO_PHASE_SPEED_META, randf_range(1.4, 2.4))
	effect.set_meta(SPICE_COMBO_LIFE_META, 0.0)
	effect.set_meta(SPICE_COMBO_MAX_LIFE_META, randf_range(1.0, 1.3))
	effect.set_meta(SPICE_COMBO_BASE_SCALE_META, effect.scale.x)
	layer.add_child(effect)
	effect.global_position = origin + Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 6.0))

	var label := Label.new()
	label.name = "Label"
	label.text = SPICE_SETTLE_WORDS[randi_range(0, SPICE_SETTLE_WORDS.size() - 1)]
	label.size = Vector2(180.0, 44.0)
	label.position = Vector2(-90.0, -22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", SPICE_COMBO_FONT)
	label.add_theme_font_size_override("font_size", 28 + clampi(rank_index, 0, 4))
	label.add_theme_color_override("font_color", _spice_effect_color(rank_index))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.018, 0.004, 0.95))
	effect.add_child(label)
	_spice_combo_vfx_effects.append(effect)


func _spice_effect_color(rank_index: int) -> Color:
	var base := Color(0.96, 0.78, 0.32, 0.94)
	if loaded_key != "":
		base = _powder_color("dust")
		base.a = 0.94
	if rank_index >= 5:
		return base.lerp(Color(1.0, 0.36, 0.24, 0.98), 0.48)
	if rank_index >= 3:
		return base.lerp(Color(1.0, 0.76, 0.24, 0.98), 0.42)
	if rank_index >= 2:
		return base.lerp(Color(0.82, 1.0, 0.44, 0.96), 0.36)
	if rank_index >= 1:
		return base.lerp(Color(1.0, 0.94, 0.54, 0.96), 0.28)
	return base


func _update_spice_combo_vfx(delta: float) -> void:
	if _spice_combo_vfx_effects.is_empty():
		return
	for i in range(_spice_combo_vfx_effects.size() - 1, -1, -1):
		var effect := _spice_combo_vfx_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_spice_combo_vfx_effects.remove_at(i)
			continue
		var velocity := effect.get_meta(SPICE_COMBO_VELOCITY_META, Vector2.ZERO) as Vector2
		var phase := float(effect.get_meta(SPICE_COMBO_PHASE_META, 0.0))
		var phase_speed := float(effect.get_meta(SPICE_COMBO_PHASE_SPEED_META, 1.0))
		var life := float(effect.get_meta(SPICE_COMBO_LIFE_META, 0.0)) + maxf(delta, 0.0)
		var max_life := float(effect.get_meta(SPICE_COMBO_MAX_LIFE_META, 0.8))
		var element := String(effect.get_meta(SPICE_COMBO_ELEMENT_META, ""))
		phase += delta * phase_speed
		effect.set_meta(SPICE_COMBO_PHASE_META, phase)
		effect.set_meta(SPICE_COMBO_LIFE_META, life)
		effect.global_position += Vector2(velocity.x + sin(phase) * 7.0, velocity.y) * delta
		if element == "spark":
			effect.rotation += delta * (4.2 + phase_speed)
		var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
		effect.modulate.a = clampf(1.0 - progress, 0.0, 1.0)
		var base_scale := float(effect.get_meta(SPICE_COMBO_BASE_SCALE_META, 1.0))
		if element == "rank" or element == "settle_word":
			effect.scale = Vector2.ONE * base_scale * lerpf(0.82, 1.22, sin(progress * PI))
		elif element == "settle_cloud":
			effect.scale = Vector2.ONE * base_scale * lerpf(0.72, 1.65, progress)
		elif element == "spark":
			effect.scale = Vector2.ONE * base_scale * lerpf(0.78, 1.12, sin(progress * PI))
		if effect.global_position.y <= SPICE_COMBO_VFX_OFFSCREEN_Y or life >= max_life:
			_spice_combo_vfx_effects.remove_at(i)
			effect.queue_free()


func _prune_invalid_spice_combo_vfx() -> void:
	for i in range(_spice_combo_vfx_effects.size() - 1, -1, -1):
		var effect := _spice_combo_vfx_effects[i]
		if effect == null or not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_spice_combo_vfx_effects.remove_at(i)


func _add_spice_screen_shake(amount: float) -> void:
	if amount <= 0.0:
		return
	_spice_screen_shake_amount = minf(SPICE_COMBO_SHAKE_MAX, maxf(_spice_screen_shake_amount, amount))
	_ensure_spice_shake_camera()


func _ensure_spice_shake_camera() -> Camera2D:
	if _spice_shake_camera != null and is_instance_valid(_spice_shake_camera):
		return _spice_shake_camera
	_spice_shake_camera = get_node_or_null(SPICE_COMBO_CAMERA_NAME) as Camera2D
	if _spice_shake_camera == null:
		_spice_shake_camera = Camera2D.new()
		_spice_shake_camera.name = SPICE_COMBO_CAMERA_NAME
		_spice_shake_camera.top_level = true
		add_child(_spice_shake_camera)
	_spice_shake_camera.global_position = get_viewport_rect().size * 0.5
	_spice_shake_camera.zoom = Vector2.ONE
	_spice_shake_camera.make_current()
	return _spice_shake_camera


func _update_spice_screen_shake(delta: float) -> void:
	if _spice_screen_shake_amount <= 0.0:
		if _spice_shake_camera != null and is_instance_valid(_spice_shake_camera):
			_spice_shake_camera.offset = Vector2.ZERO
		return
	var camera := _ensure_spice_shake_camera()
	if camera == null:
		return
	camera.global_position = get_viewport_rect().size * 0.5
	_spice_screen_shake_phase += delta * 46.0
	camera.offset = Vector2(
		sin(_spice_screen_shake_phase * 1.91),
		cos(_spice_screen_shake_phase * 2.27)
	) * _spice_screen_shake_amount
	_spice_screen_shake_amount = maxf(0.0, _spice_screen_shake_amount - SPICE_COMBO_SHAKE_DECAY * delta)


func _clear_spice_combo_vfx() -> void:
	if _spice_combo_vfx_layer != null and is_instance_valid(_spice_combo_vfx_layer):
		for child in _spice_combo_vfx_layer.get_children():
			child.queue_free()
	_spice_combo_vfx_effects.clear()


func _reset_seasoning_combo_feedback(keep_active_vfx: bool = false) -> void:
	_seasoning_combo = 0
	_seasoning_combo_idle_time = 0.0
	_seasoning_combo_pulse = 0.0
	_spice_combo_peak_rank = -1
	if _spice_combo_label != null and is_instance_valid(_spice_combo_label):
		_spice_combo_label.visible = false
	if _spice_combo_rank_label != null and is_instance_valid(_spice_combo_rank_label):
		_spice_combo_rank_label.visible = false
	if not keep_active_vfx:
		_spice_screen_shake_amount = 0.0
		if _spice_shake_camera != null and is_instance_valid(_spice_shake_camera):
			_spice_shake_camera.offset = Vector2.ZERO
		_clear_spice_combo_vfx()


func _try_spawn_powder(delta: float) -> void:
	if loaded_key == "":
		return
	if linear_velocity.length() < POWDER_MOVEMENT_MIN_SPEED:
		return
	_powder_spawn_elapsed += maxf(delta, 0.0)
	if _powder_spawn_elapsed < POWDER_SPAWN_INTERVAL:
		return
	_powder_spawn_elapsed = 0.0
	_prune_invalid_powder()
	if _powder_particles.size() >= POWDER_MAX_ACTIVE:
		return
	var burst_count := _powder_burst_count()
	for i in range(burst_count):
		if _powder_particles.size() >= POWDER_MAX_ACTIVE:
			return
		_spawn_powder_particle(i, burst_count)


func _powder_burst_count() -> int:
	var speed := linear_velocity.length()
	var t := inverse_lerp(POWDER_MOVEMENT_MIN_SPEED, POWDER_FULL_SPEED, speed)
	var base_count := 1 + int(floor(clampf(t, 0.0, 1.0) * 3.0))
	var combo_bonus := clampi(int(floor(float(_seasoning_combo) / 3.0)), 0, 4)
	return clampi(base_count + combo_bonus, 1, 8)


func _spawn_powder_particle(burst_index: int, burst_count: int) -> void:
	var layer := _ensure_powder_layer()
	var powder := Node2D.new()
	powder.name = "Powder"
	powder.z_index = 0
	powder.set_meta(POWDER_KEY_META, loaded_key)
	var kind := _powder_kind_for_next_particle()
	powder.set_meta(POWDER_KIND_META, kind)
	var slot_fraction := (float(burst_index) + randf_range(0.2, 0.8)) / float(maxi(burst_count, 1))
	var emit_local := POWDER_EMIT_LOCAL_POS + Vector2(
		lerpf(-11.0, 11.0, slot_fraction) + randf_range(-2.0, 2.0),
		randf_range(-2.0, 2.0)
	)
	layer.add_child(powder)
	powder.global_position = to_global(emit_local)
	var speed_scale := clampf(inverse_lerp(POWDER_MOVEMENT_MIN_SPEED, POWDER_FULL_SPEED, linear_velocity.length()), 0.0, 1.0)
	var side_speed := lerpf(4.0, 14.0, speed_scale)
	var fall_speed := lerpf(34.0, 72.0, speed_scale)
	var fan_x := lerpf(-side_speed, side_speed, slot_fraction) + randf_range(-side_speed * 0.45, side_speed * 0.45)
	if kind == "mist":
		fan_x *= 1.35
		fall_speed *= 0.72
	elif kind == "flake":
		fall_speed *= 1.12
	powder.set_meta(POWDER_VELOCITY_META, Vector2(fan_x, randf_range(fall_speed * 0.82, fall_speed * 1.18)))
	powder.set_meta(POWDER_PHASE_META, randf_range(0.0, TAU))
	powder.set_meta(POWDER_PHASE_SPEED_META, randf_range(2.8, 5.8))
	powder.set_meta(POWDER_LIFE_META, 0.0)
	var max_life := randf_range(1.45, 1.85)
	if kind == "mist":
		max_life = randf_range(1.5, 2.05)
	elif kind == "flake":
		max_life = randf_range(1.5, 2.0)
	powder.set_meta(POWDER_MAX_LIFE_META, max_life)
	var rotation_speed := randf_range(-1.2, 1.2)
	if kind == "flake":
		rotation_speed = randf_range(-5.4, 5.4)
	elif kind == "mist":
		rotation_speed = randf_range(-2.2, 2.2)
	powder.rotation = randf_range(-0.55, 0.55)
	powder.set_meta(POWDER_ROTATION_SPEED_META, rotation_speed)
	_build_powder_pixel(powder, kind)
	_powder_particles.append(powder)


func _powder_kind_for_next_particle() -> String:
	var pattern := ["dust", "flake", "dust", "mist", "dust", "flake"]
	if _seasoning_combo >= 6:
		pattern = ["dust", "flake", "mist", "dust", "mist", "flake"]
	elif _seasoning_combo >= 3:
		pattern = ["dust", "flake", "dust", "mist", "flake", "dust"]
	var kind := String(pattern[_powder_emit_index % pattern.size()])
	_powder_emit_index += 1
	return kind


func _ensure_powder_layer() -> Node2D:
	if _powder_layer != null and is_instance_valid(_powder_layer):
		return _powder_layer
	_powder_layer = get_node_or_null(POWDER_LAYER_NAME) as Node2D
	if _powder_layer == null:
		_powder_layer = Node2D.new()
		_powder_layer.name = POWDER_LAYER_NAME
		add_child(_powder_layer)
	_powder_layer.top_level = true
	_powder_layer.global_position = Vector2.ZERO
	_powder_layer.z_as_relative = false
	_powder_layer.z_index = POWDER_LAYER_Z_INDEX
	return _powder_layer


func _build_powder_pixel(powder: Node2D, kind: String) -> void:
	var sprite := _new_seasoning_particle_sprite(kind, _powder_emit_index % SEASONING_PARTICLE_VARIANT_COUNT)
	sprite.name = "Sprite"
	var base_scale := randf_range(0.075, 0.105)
	if kind == "flake":
		base_scale = randf_range(0.095, 0.14)
	elif kind == "mist":
		base_scale = randf_range(0.11, 0.17)
	sprite.modulate = _powder_color(kind)
	powder.set_meta(POWDER_BASE_SCALE_META, base_scale)
	powder.scale = Vector2.ONE * base_scale
	powder.add_child(sprite)


func _powder_color(kind: String) -> Color:
	var data := GameManager.seasoning.get_seasoning(loaded_key)
	var rgb: Array = data.get("color", GameManager.craft.get_item(loaded_key).get("color", [0.8, 0.8, 0.8]))
	if rgb.size() < 3:
		return Color(0.8, 0.8, 0.8, 0.9)
	var color := Color(float(rgb[0]), float(rgb[1]), float(rgb[2]), 0.9)
	if kind == "flake":
		color = color.darkened(0.16)
	elif kind == "mist":
		color = color.lightened(0.26)
		color.a = 0.46
	else:
		color = color.lightened(0.08)
	return color


func _update_powder_particles(delta: float) -> void:
	if _powder_particles.is_empty():
		return
	for i in range(_powder_particles.size() - 1, -1, -1):
		var powder := _powder_particles[i]
		if powder == null or not is_instance_valid(powder) or powder.is_queued_for_deletion():
			_powder_particles.remove_at(i)
			continue
		var velocity := powder.get_meta(POWDER_VELOCITY_META) as Vector2
		var phase := float(powder.get_meta(POWDER_PHASE_META))
		var phase_speed := float(powder.get_meta(POWDER_PHASE_SPEED_META))
		var life := float(powder.get_meta(POWDER_LIFE_META)) + delta
		var max_life := float(powder.get_meta(POWDER_MAX_LIFE_META))
		phase += delta * phase_speed
		powder.set_meta(POWDER_PHASE_META, phase)
		powder.set_meta(POWDER_LIFE_META, life)
		var drift := sin(phase) * 2.5
		powder.global_position += Vector2(velocity.x + drift, velocity.y) * delta
		powder.rotation += float(powder.get_meta(POWDER_ROTATION_SPEED_META, 0.0)) * delta
		var visual := powder.get_node_or_null("Sprite") as CanvasItem
		if visual == null:
			visual = powder.get_node_or_null("Pixel") as CanvasItem
		if visual != null:
			var alpha := clampf(1.0 - life / maxf(max_life, 0.01), 0.0, 1.0)
			var kind := String(powder.get_meta(POWDER_KIND_META, "dust"))
			var max_alpha := 0.46 if kind == "mist" else 0.9
			var visual_color := visual.modulate
			visual_color.a = minf(max_alpha, alpha * max_alpha)
			visual.modulate = visual_color
			if kind == "mist":
				var base_scale := float(powder.get_meta(POWDER_BASE_SCALE_META, 1.0))
				var progress := clampf(life / maxf(max_life, 0.01), 0.0, 1.0)
				powder.scale = Vector2.ONE * base_scale * lerpf(0.75, 1.35, progress)
		if _try_stick_powder_to_product(powder):
			_powder_particles.remove_at(i)
			powder.queue_free()
			continue
		if life >= max_life:
			_powder_particles.remove_at(i)
			powder.queue_free()


func _try_stick_powder_to_product(powder: Node2D) -> bool:
	var product := _find_product_under()
	if product == null or not product.can_accept_seasoning_particle(powder.global_position):
		return false
	var sprite := powder.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return false
	var seasoning_key := String(powder.get_meta(POWDER_KEY_META, loaded_key))
	var kind := String(powder.get_meta(POWDER_KIND_META, "dust"))
	var stuck := product.stick_seasoning_particle(
		powder.global_position,
		seasoning_key,
		kind,
		sprite.region_rect,
		sprite.modulate,
		powder.scale,
		powder.rotation
	)
	if stuck:
		_stuck_powder_product = product
	return stuck


func _prune_invalid_powder() -> void:
	for i in range(_powder_particles.size() - 1, -1, -1):
		var powder := _powder_particles[i]
		if powder == null or not is_instance_valid(powder) or powder.is_queued_for_deletion():
			_powder_particles.remove_at(i)


func _refresh_visual() -> void:
	if _visual == null:
		return
	var loaded := loaded_key != ""
	if _art != null:
		_art.visible = not loaded
		_art.modulate = Color(1, 1, 1, 1)
	if _closed_art != null:
		_closed_art.visible = loaded
		_closed_art.modulate = Color(1, 1, 1, 1)
	if _fill != null:
		_fill.visible = false
	if loaded_key == "":
		_visual.color = EMPTY_COLOR
		return
	var rgb: Array = GameManager.craft.get_item(loaded_key).get("color", [0.8, 0.8, 0.8])
	if rgb.size() >= 3:
		var tint := Color(rgb[0], rgb[1], rgb[2])
		_visual.color = tint
