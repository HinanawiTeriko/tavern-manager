class_name KitchenContainer
extends RigidBody2D

signal recipe_consumed(product_key: String)

const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const COOK_STATION_STATE := preload("res://scripts/systems/cook_station_state.gd")
const TEXTURE_COLLISION_BOUNDS := preload("res://scripts/ui/texture_collision_bounds.gd")

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
@export var heat_rate: float = 1.0   # 每秒累积的单面熟度

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
	_fit_collision_to_art_bounds()
	# Intake「吞料」是炖锅机制；烤架只靠 SearZone 按压煎制，不该吞掉放上去的生料。
	if container_key == "pot":
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


## 抓取时解冻。锅释放后重新冻结，避免搅拌时被勺子推走。
func begin_action_session() -> void:
	sleeping = false
	freeze = false


func end_action_session() -> void:
	if container_key == "pot":
		freeze = true


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
	if moved > 4.0 and Time.get_ticks_msec() - _last_stir_audio_msec >= 180:
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
		if not item.is_held:
			continue
		active_searing.append(item)
		if not _searing_bodies.has(item):
			GameManager.play_audio_event("grill_sizzle")
		_advance_grill_item(item, delta)
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
	var data: Dictionary = GameManager.craft.get_item(product_key)
	item.set_item(product_key, data, GameManager.craft.get_item_physics_profiles())
	GameManager.apply_material_icon_to_desk_item(item)
	recipe_consumed.emit(product_key)


func _prune_grill_elapsed_items() -> void:
	for item in _grill_elapsed_by_item.keys():
		if not is_instance_valid(item) or item.is_queued_for_deletion():
			_grill_elapsed_by_item.erase(item)


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
	_state.add_item(item.item_key)
	GameManager.play_audio_event("ingredient_drop")
	item.queue_free()
	print("[KitchenContainer] ", container_key, " accepted ", item.item_key)


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
	_set_segment_shape("WallLeft", bottom_left, top_left)
	_set_segment_shape("WallRight", bottom_right, top_right)
	_set_segment_shape("WallBottom", bottom_left, bottom_right)
	_set_segment_shape("RimLeft", top_left, Vector2(-intake_inner_half_width, top))
	_set_segment_shape("RimRight", Vector2(intake_inner_half_width, top), top_right)


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


func pop_last_ingredient() -> String:
	if container_key != "pot":
		return ""
	return _state.pop_last_item()


func ingredient_output_position() -> Vector2:
	return _output_anchor.global_position
