class_name GravityTest
extends Node2D

## RigidBody2D 物理沙盘。
## 拖拽流程：DragController 显示幽灵面板；物理体只在物品停在桌面上时存在。

# —— 常量 ——
const DESK_RECT := Rect2(80, 60, 1120, 396)
const SLOT_COLORS: Array[Color] = [
	Color(0.862745, 0.078431, 0.235294, 1),  # CRIMSON
	Color(1, 0.843137, 0, 1),                # GOLD
	Color(0.18, 0.55, 0.34, 1),              # 海绿
	Color(0.254902, 0.411765, 0.882353, 1),  # ROYAL_BLUE
	Color(0.6, 0.196078, 0.8, 1),            # DARK_ORCHID
]
const DESK_ITEM_SCENE := preload("res://scenes/test/desk_item.tscn")

# —— 子节点引用 ——
@onready var _drag_ctrl: DragController = $DragCtrl
@onready var _items_node: Node2D = $World/Items
@onready var _hotbar_root: Control = $HotbarUI/HotbarRoot

# —— 运行时状态 ——
var _slot_rects: Array[Rect2] = []


func _ready() -> void:
	for i in range(SLOT_COLORS.size()):
		var slot := _hotbar_root.get_node("Slot%d" % i) as ColorRect
		_slot_rects.append(Rect2(slot.global_position, slot.size))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.global_position
		if event.pressed and not _drag_ctrl.is_dragging():
			_try_pickup(pos)
		elif not event.pressed and _drag_ctrl.is_dragging():
			_on_release(pos)
	elif event is InputEventMouseMotion and _drag_ctrl.is_dragging():
		_drag_ctrl.update_target_global(event.global_position)


func _process(delta: float) -> void:
	if _drag_ctrl.is_dragging():
		_drag_ctrl.process_step(delta)


# —— 拾取 ——

func _try_pickup(pos: Vector2) -> void:
	# 1. 命中桌面上已有物品？
	var hit_body: DeskItem = _hit_test_item(pos)
	if hit_body != null:
		var visual := hit_body.get_node("Visual") as Polygon2D
		var color: Color = visual.color
		hit_body.queue_free()
		_drag_ctrl.start_drag("desk", pos, color)
		return

	# 2. 命中快捷栏槽位？
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			_drag_ctrl.start_drag("bar", pos, SLOT_COLORS[i])
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


# —— 释放 ——

func _on_release(pos: Vector2) -> void:
	var spawn_pos: Vector2 = _drag_ctrl.get_visual_pos()
	if DESK_RECT.has_point(pos):
		_spawn_desk_item(_drag_ctrl.get_panel_color(), spawn_pos)
		_drag_ctrl.cancel()
	else:
		var slot_origin: Vector2 = _nearest_slot_origin(pos)
		_drag_ctrl.end_drag_return(slot_origin)


func _spawn_desk_item(color: Color, pos: Vector2) -> void:
	# 防止 spawn 在墙体里：x 钳到墙内 30 px 安全区
	var clamped_x: float = clampf(pos.x, DESK_RECT.position.x + 30.0, DESK_RECT.end.x - 30.0)
	var item: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_node.add_child(item)
	item.set_color(color)
	item.global_position = Vector2(clamped_x, pos.y)


func _nearest_slot_origin(pos: Vector2) -> Vector2:
	var best: Vector2 = _slot_rects[0].position
	var best_d: float = INF
	for r in _slot_rects:
		var d: float = r.get_center().distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = r.position
	return best
