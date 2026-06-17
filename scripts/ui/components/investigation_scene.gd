class_name InvestigationScene
extends Node2D

## 物理调查英雄场景基类（管道层）。子类覆盖钩子注入各自内容。
## 复用 DragController 钉子拖拽 + MineItem 占位件；进场被 day_map_view instance，发 finished。
## 节点骨架（子类 .tscn 须提供）：$World、$DragCtrl、$UI/ObservationLabel、$UI/HintLabel、$UI/LeaveButton。

signal finished()

const ITEM_SCENE := preload("res://scenes/ui/components/MineItem.tscn")
const RECOVERY_MIN_X: float = -160.0
const RECOVERY_MAX_X: float = 1440.0
const RECOVERY_MIN_Y: float = -180.0
const RECOVERY_MAX_Y: float = 900.0
const SAFE_MIN_X: float = 0.0
const SAFE_MAX_X: float = 1280.0
const SAFE_MIN_Y: float = 0.0
const SAFE_MAX_Y: float = 720.0

@onready var _world: Node2D = $World
@onready var _drag_ctrl: DragController = $DragCtrl
@onready var _obs_label: Label = $UI/ObservationLabel
@onready var _hint_label: Label = $UI/HintLabel
@onready var _leave_btn: Button = $UI/LeaveButton

var _leave_hint_shown: bool = false
var _item_recovery_positions: Dictionary = {}


func _ready() -> void:
	_obs_label.text = ""
	_hint_label.text = ""
	_leave_btn.pressed.connect(_on_leave_pressed)
	_drag_ctrl.drag_ended.connect(_on_drag_ended)
	_setup_scene()


# ============================================================
#  子类钩子（默认实现；子类按需覆盖）
# ============================================================

func _setup_scene() -> void:
	pass

func _can_pickup(_item: MineItem) -> bool:
	return true

func _on_special_pickup(_item: MineItem) -> bool:
	## 返回 true 表示该拾取已被特殊处理（不进入拖拽）。
	return false

func _priority_kinds() -> Array:
	## 命中测试优先返回这些 kind（避免小线索被杂物挡住）。
	return []

func _investigation_physics(_delta: float) -> void:
	pass

func _has_deep_progress() -> bool:
	## 是否已深入调查；false 时首次点离开给软提示。
	return true

func _leave_hint_text() -> String:
	return ""


# ============================================================
#  生成
# ============================================================

func _spawn_item(p_tag: String, p_kind: String, p_size: Vector2, p_color: Color, p_label: String, p_obs: String, p_pos: Vector2) -> MineItem:
	var item: MineItem = ITEM_SCENE.instantiate()
	_world.add_child(item)
	item.setup(p_tag, p_kind, p_size, p_color, p_label, p_obs)
	item.global_position = p_pos
	_set_item_recovery_position(item, p_pos)
	return item


# ============================================================
#  输入 / 拾取（钉子拖拽）
# ============================================================

func _input(event: InputEvent) -> void:
	## _input（非 _unhandled_input）确保有 CanvasLayer/Control 的场景里也能收到鼠标事件。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.global_position
		if event.pressed and not _drag_ctrl.is_dragging():
			if _try_pickup(pos):
				get_viewport().set_input_as_handled()
		elif not event.pressed and _drag_ctrl.is_dragging():
			_drag_ctrl.end_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag_ctrl.is_dragging():
		_drag_ctrl.update_target_global(event.global_position)
		get_viewport().set_input_as_handled()


func _try_pickup(pos: Vector2) -> bool:
	var hit := _hit_test_item(pos)
	if hit == null:
		return false
	if not _can_pickup(hit):
		return false
	if _on_special_pickup(hit):
		return true
	if hit.freeze:
		hit.freeze = false   # 冻结体的钉子拖不动，抓取时解冻
	_drag_ctrl.start_drag(hit, pos)
	_on_item_grabbed(hit)
	return true


func _hit_test_item(pos: Vector2) -> MineItem:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 8)
	var any_hit: MineItem = null
	var priority := _priority_kinds()
	for h in hits:
		var collider = h.get("collider")
		if collider is MineItem and collider.visible:
			if priority.has(collider.kind):
				return collider
			any_hit = collider
	return any_hit


func _on_item_grabbed(item: MineItem) -> void:
	if item.kind == "observation" and item.observation != "":
		_obs_label.text = item.observation


func _on_drag_ended(body: RigidBody2D) -> void:
	if not body is MineItem:
		return
	var item := body as MineItem
	if _is_inside_safe_view(item.global_position):
		_set_item_recovery_position(item, item.global_position)


# ============================================================
#  物理帧 / 授予 / 离开
# ============================================================

func _physics_process(delta: float) -> void:
	_recover_out_of_bounds_items()
	_investigation_physics(delta)


func _recover_out_of_bounds_items() -> void:
	var dragged := _drag_ctrl.get_body() if _drag_ctrl.is_dragging() else null
	for child in _world.get_children():
		if not child is MineItem:
			continue
		var item := child as MineItem
		if item == dragged or not item.visible or item.is_queued_for_deletion():
			continue
		if _is_inside_recovery_bounds(item.global_position):
			continue
		_recover_item_to_safe_position(item)
	_prune_invalid_recovery_positions()


func _recover_item_to_safe_position(item: MineItem) -> void:
	var target: Vector2 = _item_recovery_positions.get(item, Vector2(640.0, 420.0))
	item.linear_velocity = Vector2.ZERO
	item.angular_velocity = 0.0
	item.global_position = target
	item.global_rotation = 0.0
	item.freeze = true
	item.sleeping = true


func _set_item_recovery_position(item: MineItem, position: Vector2) -> void:
	if item == null or not is_instance_valid(item):
		return
	_item_recovery_positions[item] = position


func _is_inside_recovery_bounds(position: Vector2) -> bool:
	return position.x >= RECOVERY_MIN_X \
		and position.x <= RECOVERY_MAX_X \
		and position.y >= RECOVERY_MIN_Y \
		and position.y <= RECOVERY_MAX_Y


func _is_inside_safe_view(position: Vector2) -> bool:
	return position.x >= SAFE_MIN_X \
		and position.x <= SAFE_MAX_X \
		and position.y >= SAFE_MIN_Y \
		and position.y <= SAFE_MAX_Y


func _prune_invalid_recovery_positions() -> void:
	for item in _item_recovery_positions.keys():
		if not is_instance_valid(item) or item.is_queued_for_deletion():
			_item_recovery_positions.erase(item)


func _grant_document(document_id: String) -> void:
	var gm = get_node("/root/GameManager")
	gm.grant_investigation_document(document_id)


func _on_leave_pressed() -> void:
	# 没深挖就想走 → 先耳语一句、可坚持再点离开。
	if not _has_deep_progress() and not _leave_hint_shown:
		_leave_hint_shown = true
		_hint_label.text = _leave_hint_text()
		return
	finished.emit()
