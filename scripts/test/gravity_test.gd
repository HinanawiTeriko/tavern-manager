class_name GravityTest
extends Node2D

## RigidBody2D 物理沙盘。拖拽采用 DragController 的钉子模式 —
## 拖拽中物品全程是物理体，能与其他物品双向碰撞。

# —— 常量 ——
const DESK_RECT := Rect2(80, 60, 1120, 396)
const HOTBAR_SPAWN_Y: float = 250.0    # 从快捷栏拖出时物品诞生 y（桌面顶部、地面碰撞器上方）
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

	# 2. 命中快捷栏槽位？→ 在桌面顶部生成新物品（避开地面碰撞器），再用鼠标位置作为钉子点
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			var spawn_pos := Vector2(pos.x, HOTBAR_SPAWN_Y)
			var body := _spawn_desk_item_at(spawn_pos, SLOT_COLORS[i])
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


func _spawn_desk_item_at(pos: Vector2, color: Color) -> DeskItem:
	var item: DeskItem = DESK_ITEM_SCENE.instantiate()
	_items_node.add_child(item)
	item.set_color(color)
	item.global_position = pos
	return item
