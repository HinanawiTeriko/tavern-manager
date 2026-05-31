class_name BarWorkspace
extends Node2D

## 正式吧台物理工作面（从 gravity_test 沙盘移植的胶水）。
## 取材：点 ShortcutBar 槽位 → 在鼠标处生成 DeskItem 物理体并钉住。
## 抓桶：点酒桶 → 唤醒 + 钉住，可移动可摇。
## 上菜：成品拖进 CustomerDropArea 松手 → GameManager.request_serve()。
## 只跟 GameManager 说话，不引用 tavern_view（守 mediator 规则）。

const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const KITCHEN_CONTAINER_SCRIPT := preload("res://scripts/ui/kitchen_container.gd")
const MAX_SLOTS := 10
const KILL_Y := 800.0

@onready var _drag_ctrl: DragController = $DragCtrl
@onready var _items_node: Node2D = $World/Items
@onready var _brewery: Brewery = $World/Brewery
@onready var _grill: KitchenContainer = $World/Grill
@onready var _pot: KitchenContainer = $World/Pot
@onready var _spoon: StirSpoon = $World/Spoon
@onready var _customer_area: Area2D = $CustomerDropArea
@onready var _shortcut_bar: Control = get_node("../ShortcutBar")

var _gm
var _slot_rects: Array[Rect2] = []
var _slot_item_keys: Array[String] = []
@onready var _recycle_anchor: Marker2D = $World/RecycleAnchor
var _docks: Dictionary = {}   # RigidBody2D -> Vector2 初始泊位
@onready var _wash_basin: Area2D = $World/WashBasin
@onready var _ledger: ReadableDeskItem = $World/Ledger
const WASH_DWELL := 0.8
var _wash_dwell: Dictionary = {}   # 容器 -> 已停留秒数


func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_shortcut_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brewery.recipe_consumed.connect(func(k): print("[BarWorkspace] 产出 ", k))
	_drag_ctrl.drag_started.connect(_on_drag_started)
	_drag_ctrl.drag_ended.connect(_on_drag_ended)
	_items_node.child_entered_tree.connect(_on_items_child_added)
	_gm.inventory_changed.connect(_init_material_slots)
	_ledger.open_requested.connect(_gm.request_open_document)
	call_deferred("_capture_docks")
	call_deferred("_init_material_slots")   # 等 HBox 布局完成再读 slot 位置


func _on_drag_started(body: RigidBody2D) -> void:
	if body is DeskItem:
		body.is_held = true


func _on_drag_ended(body: RigidBody2D) -> void:
	if body is DeskItem:
		body.is_held = false


func _init_material_slots() -> void:
	## 从库存把可用材料填进 ShortcutBar 槽位（无限源；库存扣减为后续）。
	_slot_rects.clear()
	_slot_item_keys.clear()
	var keys: Array = []
	for k in _gm.inventory.keys():
		if _gm.inventory_sys.is_material(k):
			keys.append(k)
	keys.sort()
	for i in range(MAX_SLOTS):
		var slot := _shortcut_bar.get_node_or_null("Slot%d" % i) as ColorRect
		if slot == null:
			break
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key: String = keys[i] if i < keys.size() else ""
		_slot_item_keys.append(key)
		_slot_rects.append(Rect2(slot.global_position, slot.size))
		var label := slot.get_node_or_null("Label") as Label
		if label:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if key == "":
			slot.color = Color(0.08, 0.06, 0.04)
			if label: label.text = ""
			continue
		var item_data: Dictionary = _gm.craft.get_item(key)
		var rgb: Array = item_data.get("color", [0.8, 0.8, 0.8])
		slot.color = Color(rgb[0], rgb[1], rgb[2])
		if label: label.text = item_data.get("name", key)


func _input(event: InputEvent) -> void:
	if not _drag_ctrl.is_dragging():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_dragged_body()
	elif event is InputEventMouseMotion:
		_drag_ctrl.update_target_global(event.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.global_position
		if event.pressed and not _drag_ctrl.is_dragging():
			_try_pickup(pos)
		elif not event.pressed and _drag_ctrl.is_dragging():
			var dragged := _drag_ctrl.get_body()
			_drag_ctrl.end_drag()
			if dragged == _brewery:
				_brewery.end_shake_session()
			elif _is_kitchen_container(dragged):
				dragged.end_action_session()
			elif dragged is DeskItem:
				_try_serve(dragged)
	elif event is InputEventMouseMotion and _drag_ctrl.is_dragging():
		_drag_ctrl.update_target_global(event.global_position)


func _release_dragged_body() -> void:
	var dragged := _drag_ctrl.get_body()
	_drag_ctrl.end_drag()
	if dragged == _brewery:
		_brewery.end_shake_session()
	elif dragged is DeskItem:
		_try_serve(dragged)


func _try_pickup(pos: Vector2) -> void:
	var hit_item: DeskItem = _hit_test_item(pos)
	if hit_item != null:
		_drag_ctrl.start_drag(hit_item, pos)
		return
	if _hit_test_brewery(pos):
		_brewery.begin_shake_session()
		_drag_ctrl.start_drag(_brewery, pos)
		return
	var spoon := _hit_test_spoon(pos)
	if spoon != null:
		spoon.sleeping = false
		_drag_ctrl.start_drag(spoon, pos)
		return
	var kitchen = _hit_test_kitchen_container(pos)
	if kitchen != null:
		kitchen.begin_action_session()
		_drag_ctrl.start_drag(kitchen, pos)
		return
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos) and _slot_item_keys[i] != "":
			var body := spawn_inventory_item_at(_slot_item_keys[i], pos)
			if body != null:
				_drag_ctrl.start_drag(body, pos)
			return


func _try_serve(item: DeskItem) -> void:
	if item.item_key == "" or not _gm.craft.is_product(item.item_key):
		return
	if not _customer_area.get_overlapping_bodies().has(item):
		return
	var speed: float = _drag_ctrl.get_serve_speed()
	_gm.request_serve(item.item_key, {"serve_drop_speed": speed, "quality": item.quality})
	item.queue_free()


func _hit_test_item(pos: Vector2) -> DeskItem:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 8)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is DeskItem:
			return collider
	return null


func _hit_test_brewery(pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var hits := space.intersect_point(params, 8)
	for h in hits:
		var collider = h.get("collider")
		if collider == _brewery:
			return true
		if collider is Area2D and collider.get_parent() == _brewery:
			return true
	return false


func _hit_test_spoon(pos: Vector2) -> StirSpoon:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 4)
	for h in hits:
		if h.get("collider") is StirSpoon:
			return h.get("collider")
	return null


func _hit_test_kitchen_container(pos: Vector2):
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var hits := space.intersect_point(params, 8)
	for h in hits:
		var collider = h.get("collider")
		if _is_kitchen_container(collider):
			return collider
		if collider is Area2D and _is_kitchen_container(collider.get_parent()):
			return collider.get_parent()
	return null


func _is_kitchen_container(node: Node) -> bool:
	return node != null and node.get_script() == KITCHEN_CONTAINER_SCRIPT


func _spawn_desk_item_at(pos: Vector2, item_key: String) -> DeskItem:
	var item: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_node.add_child(item)
	var item_data: Dictionary = _gm.craft.get_item(item_key)
	item.set_item(item_key, item_data, _gm.craft.get_item_physics_profiles())
	item.global_position = pos
	return item


## 从背包/快捷栏拖出物品的统一入口：先扣库存，再生成桌面物理体。
func spawn_inventory_item_at(item_key: String, pos: Vector2) -> DeskItem:
	if not _gm.remove_from_inventory(item_key, 1):
		return null
	return _spawn_desk_item_at(pos, item_key)


## 记录容器/勺子的初始位置作为泊位（越界/整理时归位）。延迟到布局稳定后调用。
func _capture_docks() -> void:
	_docks[_brewery] = _brewery.global_position
	for child in _items_node.get_parent().get_children():
		if _is_kitchen_container(child) or child is StirSpoon:
			_docks[child] = child.global_position


## 任何加进 Items 的 DeskItem（取材/容器产出）都连越界信号；is_connected 守卫避免重复。
func _on_items_child_added(child: Node) -> void:
	if child is DeskItem and not child.fell_out_of_bounds.is_connected(_on_desk_item_fell):
		child.fell_out_of_bounds.connect(_on_desk_item_fell)


## 应急整理（spec §6.5）：散落桌面物品按分类恢复，容器/勺子归泊位，
## 容器内部料状态保留（不清空）。
func tidy_desk() -> void:
	for child in _items_node.get_children():
		if child is DeskItem:
			_on_desk_item_fell(child)
	for body in _docks:
		if not is_instance_valid(body):
			continue
		_dock_body(body)


## 桌面物品越界：材料/剧情物品回背包（释放物体），成品移回回收锚点。
func _on_desk_item_fell(item: DeskItem) -> void:
	if not is_instance_valid(item):
		return
	var target: String = _gm.recover_desk_item_key(item.item_key)
	if target == "recycle":
		item.linear_velocity = Vector2.ZERO
		item.angular_velocity = 0.0
		item.global_position = _recycle_anchor.global_position
		item.reset_fall_state()
	else:
		item.queue_free()


func _physics_process(delta: float) -> void:
	_recover_docked_bodies()
	_update_spoon_depth()
	_update_wash_basin(delta)


func _update_spoon_depth() -> void:
	_spoon.set_submerged(
		_brewery.is_spoon_inside(_spoon)
		or _grill.is_spoon_inside(_spoon)
		or _pot.is_spoon_inside(_spoon)
		or _area_contains_spoon_tip(_wash_basin)
	)


func _area_contains_spoon_tip(area: Area2D) -> bool:
	var collision_shape := area.get_node_or_null("Shape") as CollisionShape2D
	if collision_shape == null:
		return false
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return false
	var local_tip := collision_shape.to_local(_spoon.tip_global_position())
	var half_size := rectangle.size * 0.5
	return absf(local_tip.x) <= half_size.x and absf(local_tip.y) <= half_size.y


## 容器/工具越界时自动回泊位，避免关键工作台对象永久丢失。
func _recover_docked_bodies() -> void:
	for body in _docks:
		if is_instance_valid(body) and body.global_position.y > KILL_Y:
			_dock_body(body)


func _dock_body(body: RigidBody2D) -> void:
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.global_position = _docks[body]
	body.sleeping = true


## 容器停在清洗盆内 0.8s → 清空内部料回库存（一次进入只清一次；
## 离开后重新进入才会再次清洗，避免坐在盆里把后投的料静默清掉）。
func _update_wash_basin(delta: float) -> void:
	var inside := {}
	for body in _wash_basin.get_overlapping_bodies():
		if body == _brewery or _is_kitchen_container(body):
			inside[body] = true
			var dwell := float(_wash_dwell.get(body, 0.0))
			if is_inf(dwell):
				continue   # 本次停留已清洗过，等离开再重置
			dwell += delta
			if dwell >= WASH_DWELL:
				_wash_dwell[body] = INF
				_do_wash(body)
			else:
				_wash_dwell[body] = dwell
	for body in _wash_dwell.keys():
		if not inside.has(body):
			_wash_dwell.erase(body)


func _do_wash(container) -> void:
	assert(container == _brewery or _is_kitchen_container(container),
		"_do_wash called on unexpected type: %s" % container)
	var drained: Array = container.drain_contents()
	if drained.is_empty():
		return
	for key in drained:
		_gm.add_to_inventory(key, 1)
	print("[BarWorkspace] 清洗盆清空 ", container, " 退回 ", drained)


func _exit_tree() -> void:
	if _gm != null and _gm.inventory_changed.is_connected(_init_material_slots):
		_gm.inventory_changed.disconnect(_init_material_slots)
