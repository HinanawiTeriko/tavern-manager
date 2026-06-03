class_name SeasoningShaker
extends RigidBody2D

## 香料罐：常驻吧台工具。装填一种香料（拖香料 DeskItem 砸到罐上，由 BarWorkspace 调 load_seasoning），
## 抓起摇够次数 → 给罐正下方成品写 L1 属性（覆盖式）+ 效果类透传 tag，撒完即空。
## 复用 BrewShakeMeter 计摇晃；只跟 GameManager 说话（仿 Brewery 直接调 GameManager.*）。

const SHAKER_MASS := 1.2
const SHAKER_LINEAR_DAMP := 0.8
const SHAKER_ANGULAR_DAMP := 4.0
const PROBE_DOWN := 56.0   # 罐口朝下探测成品的偏移
const PROBE_QUERY_COUNT := 8
const EMPTY_COLOR := Color(0.55, 0.55, 0.6)

@onready var _visual: Polygon2D = $Visual

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


func _load_shake_config() -> void:
	# 复用酒桶摇晃阈值（同一手感语言）。
	var file = FileAccess.open("res://data/barrel.json", FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary and data.has("shake"):
		_shake.load_thresholds(data["shake"])


func _physics_process(_delta: float) -> void:
	if _session_active:
		_shake.add_sample(linear_velocity)


## 装填：消耗调用方已扣库存的香料 DeskItem，罐进入已装填态并染色。已装填时替换（旧料废弃）。
func load_seasoning(key: String) -> void:
	loaded_key = key
	_shake.reset()
	_refresh_visual()
	GameManager.play_audio_event("ingredient_drop")


func is_loaded() -> bool:
	return loaded_key != ""


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
		return   # 罐下无成品：不浪费，装填保留
	var r: Dictionary = GameManager.resolve_seasoning_application(loaded_key, prod.item_key)
	if not bool(r.get("accepted", false)):
		return   # 软拒（如花粉撒到非麦芽酒）：保留装填，反馈已弹
	prod.set_attribute(String(r.get("attribute", "")))
	for t in r.get("product_tags", []):
		prod.add_product_tag(String(t))
	loaded_key = ""
	_shake.reset()
	_refresh_visual()
	GameManager.play_audio_event("product_ready")


## 罐口朝下探测一个成品 DeskItem。
func _find_product_under() -> DeskItem:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = global_position + Vector2(0, PROBE_DOWN)
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, PROBE_QUERY_COUNT)
	for h in hits:
		var c = h.get("collider")
		if c is DeskItem and c != self and GameManager.craft.is_product(c.item_key):
			return c
	return null


func _refresh_visual() -> void:
	if _visual == null:
		return
	if loaded_key == "":
		_visual.color = EMPTY_COLOR
		return
	var rgb: Array = GameManager.craft.get_item(loaded_key).get("color", [0.8, 0.8, 0.8])
	_visual.color = Color(rgb[0], rgb[1], rgb[2])
