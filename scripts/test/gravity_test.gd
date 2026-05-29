class_name GravityTest
extends Node2D

## RigidBody2D 物理沙盘。拖拽采用 DragController 的钉子模式 —
## 拖拽中物品全程是物理体，能与其他物品双向碰撞。

# —— 常量 ——
const DESK_RECT := Rect2(80, 60, 1120, 396)
const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")

# —— 子节点引用 ——
@onready var _drag_ctrl: DragController = $DragCtrl
@onready var _items_node: Node2D = $World/Items
@onready var _hotbar_root: Control = $HotbarUI/HotbarRoot
@onready var _brewery: Brewery = $World/Brewery

# —— 运行时状态 ——
var _slot_rects: Array[Rect2] = []
var _slot_item_keys: Array[String] = []


func _ready() -> void:
	for i in range(5):
		var slot := _hotbar_root.get_node("Slot%d" % i) as ColorRect
		_slot_rects.append(Rect2(slot.global_position, slot.size))
		var item_key: String = slot.get_meta("item_key", "")
		_slot_item_keys.append(item_key)
		if item_key != "":
			var item_data: Dictionary = GameManager.craft.get_item(item_key)
			var rgb: Array = item_data.get("color", [0.8, 0.8, 0.8])
			slot.color = Color(rgb[0], rgb[1], rgb[2])
	_brewery.recipe_consumed.connect(func(k): print("[Brewery] 产出 ", k))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.global_position
		if event.pressed and not _drag_ctrl.is_dragging():
			_try_pickup(pos)
		elif not event.pressed and _drag_ctrl.is_dragging():
			_drag_ctrl.end_drag()
	elif event is InputEventMouseMotion and _drag_ctrl.is_dragging():
		_drag_ctrl.update_target_global(event.global_position)


# —— 拾取 ——

func _try_pickup(pos: Vector2) -> void:
	# 1. 命中桌面上已有物品？→ 直接钉住（不销毁）
	var hit_body: DeskItem = _hit_test_item(pos)
	if hit_body != null:
		_drag_ctrl.start_drag(hit_body, pos)
		return

	# 2. 命中快捷栏槽位？→ 在鼠标位置生成新物品再钉住
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			var item_key: String = _slot_item_keys[i]
			if item_key == "":
				return
			var body := _spawn_desk_item_at(pos, item_key)
			_drag_ctrl.start_drag(body, pos)
			return


func _hit_test_item(pos: Vector2) -> DeskItem:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 1)
	if hits.size() > 0:
		var collider = hits[0].get("collider")
		if collider is DeskItem:
			return collider
	return null


func _spawn_desk_item_at(pos: Vector2, item_key: String) -> DeskItem:
	var item: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_node.add_child(item)
	var item_data: Dictionary = GameManager.craft.get_item(item_key)
	item.set_item(item_key, item_data)
	item.global_position = pos
	return item
