class_name Brewery
extends RigidBody2D

## Barrel container body. It keeps normal gravity, can be grabbed/shaken,
## and continues as a physics body after release.
signal recipe_consumed(product_key: String)

const CONTAINER_KEY := "barrel"
const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const BARREL_MASS := 2.5
const BARREL_LINEAR_DAMP := 0.8
const BARREL_ANGULAR_DAMP := 4.0
const MOUTH_INNER_HALF_WIDTH := 24.0
const MOUTH_TOP_Y := -64.0
const MOUTH_BOTTOM_Y := -34.0
const SPOON_ZONE_INNER_HALF_WIDTH := 40.0
const SPOON_ZONE_TOP_Y := MOUTH_TOP_Y
const SPOON_ZONE_BOTTOM_Y := 40.0
const BARREL_CONFIG := "res://data/barrel.json"

@onready var _mouth: Area2D = $Mouth
@onready var _output_anchor: Marker2D = $OutputAnchor

var _items_parent: Node2D = null
var _pending_keys: Array[String] = []
var _shake := BrewShakeMeter.new()
var _session_active: bool = false


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
	_mouth.body_entered.connect(_on_mouth_body_entered)
	_load_shake_config()


func _physics_process(_delta: float) -> void:
	if _session_active:
		_shake.add_sample(linear_velocity)
	for body in _mouth.get_overlapping_bodies():
		_try_accept_mouth_body(body)


func _on_mouth_body_entered(body: Node) -> void:
	_try_accept_mouth_body(body)


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
	_pending_keys.append(item.item_key)
	item.queue_free()


func _is_item_inside_mouth_opening(item: DeskItem) -> bool:
	return _is_point_inside_mouth_opening(item.global_position)


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
	product.quality = quality
	# 冒桶口：向上 + 轻微偏外的初速度，重力把它带成弧线落桌。
	# 朝上离开桶口，且产出物是成品（_try_accept 的 is_product 守卫会拦它），不会被自己收回。
	var out_dir := 1.0 if randf() > 0.5 else -1.0
	product.linear_velocity = Vector2(out_dir * 90.0, -260.0)


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
	if product_key == "":
		print("[Brewery] 摇够了但配方未命中，料已消耗无产出 (摇晃 %d 次)" % shakes)
		return   # 软兜底：料已消耗、无产出
	print("[Brewery] 产出 %s  品质=%s  (摇晃 %d 次)" % [product_key, quality, shakes])
	_spawn_product(product_key, quality)
	recipe_consumed.emit(product_key)


## 清洗盆清空：返回未结算的投料 key 列表并清空摇晃进度。料未出酒，全部退回。
func drain_contents() -> Array[String]:
	var drained := _pending_keys.duplicate()
	_pending_keys.clear()
	_shake.reset()
	return drained
