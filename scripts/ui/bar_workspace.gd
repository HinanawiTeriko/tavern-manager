class_name BarWorkspace
extends Node2D

## 正式吧台物理工作面（从 gravity_test 沙盘移植的胶水）。
## 取材：点 ShortcutBar 槽位 → 在鼠标处生成 DeskItem 物理体并钉住。
## 抓桶：点酒桶 → 唤醒 + 钉住，可移动可摇。
## 上菜：成品拖进 CustomerDropArea 松手 → GameManager.request_serve()。
## 只跟 GameManager 说话，不引用 tavern_view（守 mediator 规则）。

const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")
const MAX_SLOTS := 10

@onready var _drag_ctrl: DragController = $DragCtrl
@onready var _items_node: Node2D = $World/Items
@onready var _brewery: Brewery = $World/Brewery
@onready var _customer_area: Area2D = $CustomerDropArea
@onready var _shortcut_bar: Control = get_node("../ShortcutBar")

var _gm
var _slot_rects: Array[Rect2] = []
var _slot_item_keys: Array[String] = []


func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_brewery.recipe_consumed.connect(func(k): print("[BarWorkspace] 产出 ", k))
	call_deferred("_init_material_slots")   # 等 HBox 布局完成再读 slot 位置


func _init_material_slots() -> void:
	## 从库存把可用材料填进 ShortcutBar 槽位（无限源；库存扣减为后续）。
	_slot_rects.clear()
	_slot_item_keys.clear()
	var keys: Array = []
	for k in _gm.inventory.keys():
		if not _gm.craft.is_product(k):
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
		if key == "":
			slot.color = Color(0.08, 0.06, 0.04)
			if label: label.text = ""
			continue
		var item_data: Dictionary = _gm.craft.get_item(key)
		var rgb: Array = item_data.get("color", [0.8, 0.8, 0.8])
		slot.color = Color(rgb[0], rgb[1], rgb[2])
		if label: label.text = item_data.get("name", key)


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
			elif dragged is DeskItem:
				_try_serve(dragged)
	elif event is InputEventMouseMotion and _drag_ctrl.is_dragging():
		_drag_ctrl.update_target_global(event.global_position)


func _try_pickup(pos: Vector2) -> void:
	var hit_item: DeskItem = _hit_test_item(pos)
	if hit_item != null:
		_drag_ctrl.start_drag(hit_item, pos)
		return
	if _hit_test_brewery(pos):
		_brewery.begin_shake_session()
		_drag_ctrl.start_drag(_brewery, pos)
		return
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos) and _slot_item_keys[i] != "":
			var body := _spawn_desk_item_at(pos, _slot_item_keys[i])
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
	var hits := space.intersect_point(params, 1)
	if hits.size() > 0 and hits[0].get("collider") is DeskItem:
		return hits[0].get("collider")
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


func _spawn_desk_item_at(pos: Vector2, item_key: String) -> DeskItem:
	var item: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_node.add_child(item)
	var item_data: Dictionary = _gm.craft.get_item(item_key)
	item.set_item(item_key, item_data)
	item.global_position = pos
	return item
