class_name SeasoningShaker
extends RigidBody2D

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
var _shake := BrewShakeMeter.new()
var _session_active: bool = false


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


func _physics_process(_delta: float) -> void:
	if _session_active:
		_shake.add_sample(linear_velocity)
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
	load_seasoning(item.item_key)
	item.queue_free()


func _is_point_inside_mouth_opening(global_pos: Vector2) -> bool:
	var local := to_local(global_pos)
	return absf(local.x) <= MOUTH_HALF_WIDTH \
		and local.y >= MOUTH_TOP_Y \
		and local.y <= MOUTH_BOTTOM_Y


# ── 装填 / 状态 ──

## 装填：消耗调用方已扣库存的香料 DeskItem，罐进入已装填态并染色。已装填时替换（旧料废弃）。
func load_seasoning(key: String) -> void:
	loaded_key = key
	_shake.reset()
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
	GameManager.play_audio_event("barrel_shake")


## 松手结算：摇够 + 罐下有成品 → 应用香料；否则保留装填，可继续摇。
func end_shake_session() -> void:
	_session_active = false
	lock_rotation = false
	if loaded_key == "" or not _shake.has_enough():
		return
	var prod := _find_product_under()
	if prod == null:
		return
	var r: Dictionary = GameManager.resolve_seasoning_application(loaded_key, prod.item_key)
	if not bool(r.get("accepted", false)):
		return
	prod.set_attribute(String(r.get("attribute", "")))
	for t in r.get("product_tags", []):
		prod.add_product_tag(String(t))
	loaded_key = ""
	_shake.reset()
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
