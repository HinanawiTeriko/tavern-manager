class_name KitchenContainer
extends RigidBody2D

signal recipe_consumed(product_key: String)

const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const COOK_STATION_STATE := preload("res://scripts/systems/cook_station_state.gd")

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
@export var heat_rate: float = 1.0   # 朝下面每秒累积的熟度

@onready var _intake: Area2D = $Intake
@onready var _output_anchor: Marker2D = $OutputAnchor
@onready var _sear_zone: Area2D = get_node_or_null("SearZone")

var _items_parent: Node2D = null
var _state = COOK_STATION_STATE.new()
var _stir_tracking: bool = false
var _prev_tip_pos: Vector2 = Vector2.ZERO
var _searing_bodies: Array = []   # 上一帧在烤区内的肉,用于检测离开


func _ready() -> void:
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
	_intake.body_entered.connect(_on_intake_body_entered)


func _physics_process(delta: float) -> void:
	if container_key == "pot":
		for body in _intake.get_overlapping_bodies():
			if body is StirSpoon:
				_accumulate_stir(body, delta)
			else:
				_try_accept_body(body)
		if _state.is_ready():
			_finish_current(GameManager.craft.query_recipe(container_key, _state.ingredients()))
		return

	# grill: 按压煎制
	_process_grill_sear(delta)


## 灶台抓取唤醒。锅已冻结成静态（不可移动），故只为非锅容器解冻。
func begin_action_session() -> void:
	sleeping = false
	if container_key != "pot":
		freeze = false


func end_action_session() -> void:
	pass


## 勺尖在锅内时，按勺尖的"移动距离"累积搅拌进度——比读物理速度稳，
## 不受勺子被锅壁约束影响（料为空时 add_stir 自动忽略）。
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
	if moved > 60.0:   # 防瞬移/抓取跳变造成的尖峰
		return
	_state.add_stir(moved * stir_scale)


## 烤架:被抓着且贴在 SearZone 内的肉,朝下面累积熟度;离开烤区时定稿。
func _process_grill_sear(delta: float) -> void:
	if _sear_zone == null:
		return
	var now_inside: Array = []
	for body in _sear_zone.get_overlapping_bodies():
		if not body is DeskItem:
			continue
		var item: DeskItem = body
		if item.item_key == "" or GameManager.craft.is_product(item.item_key):
			continue
		now_inside.append(item)
		if item.is_held:
			item.add_heat(item.down_face_index(), heat_rate * delta)
	# 离开烤区(上一帧在、这一帧不在)→ 定稿
	for prev in _searing_bodies:
		if is_instance_valid(prev) and not now_inside.has(prev):
			_finalize_grill_item(prev)
	_searing_bodies = now_inside


## 肉离开烤架时按两面颜色定稿:熟→配方产物;焦→焦糊;生→保持原样(留作剧情)。
func _finalize_grill_item(item: DeskItem) -> void:
	var verdict := item.grill_result()
	if verdict == "raw":
		return
	var product_key := ""
	if verdict == "burnt":
		product_key = _burnt_key_for(item.item_key)
	else:
		product_key = GameManager.craft.query_recipe("grill", [item.item_key])
	if product_key == "":
		return
	var data: Dictionary = GameManager.craft.get_item(product_key)
	item.set_item(product_key, data)   # 改 key + 重置颜色基线为产物色
	recipe_consumed.emit(product_key)


func _is_point_inside_stir_zone(global_pos: Vector2) -> bool:
	var local_pos: Vector2 = to_local(global_pos)
	return absf(local_pos.x) <= stir_zone_half_width \
		and local_pos.y >= stir_zone_top_y \
		and local_pos.y <= stir_zone_bottom_y


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
	_state.add_item(item.item_key)
	item.queue_free()
	print("[KitchenContainer] ", container_key, " accepted ", item.item_key)


func is_item_inside_intake(item: Node2D) -> bool:
	return _is_point_inside_intake(item.global_position)


func _is_point_inside_intake(global_pos: Vector2) -> bool:
	var local_pos: Vector2 = to_local(global_pos)
	return absf(local_pos.x) <= intake_inner_half_width \
		and local_pos.y >= intake_top_y \
		and local_pos.y <= intake_bottom_y


func _finish_current(product_key: String) -> void:
	var ingredients := _state.ingredients()
	_state.clear()
	_configure_state()
	if product_key == "":
		print("[KitchenContainer] ", container_key, " no recipe for ", ingredients)
		return
	_spawn_product(product_key)
	recipe_consumed.emit(product_key)


func _burnt_key_for(raw_key: String) -> String:
	if raw_key.begins_with("meat"):
		return "meat_burnt"
	return "bread_burnt"


func _spawn_product(product_key: String) -> void:
	var product: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_parent.add_child(product)
	product.global_position = _output_anchor.global_position
	var item_data: Dictionary = GameManager.craft.get_item(product_key)
	product.set_item(product_key, item_data)
	product.linear_velocity = Vector2(randf_range(-70.0, 70.0), -180.0)
