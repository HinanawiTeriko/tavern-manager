class_name MineInvestigation
extends Node2D

## 废弃矿道物理调查场景。复用 DragController 钉子拖拽 + 占位 MineItem。
## 作为全屏子节点被 day_map_view instance；挖完/离开发 finished 信号。

signal finished()

const MINE_ITEM_SCENE := preload("res://scenes/ui/components/MineItem.tscn")
const RUBBLE_REVEAL_DIST := 120.0   # 碎石被拖离原位多远算「扒开」
const SPILL_TILT := 2.0             # 背包倾斜超过此弧度算「倾倒」

@onready var _world: Node2D = $World
@onready var _drag_ctrl: DragController = $DragCtrl
@onready var _obs_label: Label = $UI/ObservationLabel
@onready var _hint_label: Label = $UI/HintLabel
@onready var _leave_btn: Button = $UI/LeaveButton

var _rubble: MineItem = null
var _rubble_origin: Vector2 = Vector2.ZERO
var _backpack: MineItem = null
var _rubble_cleared: bool = false
var _backpack_spilled: bool = false
var _contract_taken: bool = false
var _leave_hint_shown: bool = false


func _ready() -> void:
	_obs_label.text = ""
	_hint_label.text = ""
	_leave_btn.pressed.connect(_on_leave_pressed)
	_spawn_shallow_items()
	_spawn_deep_layer()   # Task 5 实现碎石+背包；初版先空过


# ============================================================
#  生成
# ============================================================

func _spawn_shallow_items() -> void:
	# 浅层散落物：断箭 / 凹盾 / 破靴，捡起=一句观察台词，不授予。
	_spawn_item("broken_arrow", "observation", Vector2(48, 16), Color(0.55, 0.4, 0.25),
		"断箭", "箭杆从中折断——这里被打崩过。", Vector2(260, 470))
	_spawn_item("dented_shield", "observation", Vector2(64, 64), Color(0.45, 0.45, 0.5),
		"凹盾", "盾面一个深陷的凹痕，挡下过重重一击。", Vector2(380, 460))
	_spawn_item("lost_boot", "observation", Vector2(56, 36), Color(0.35, 0.25, 0.2),
		"破靴", "一只孤零零的靴子，主人走得很急——或者没走成。", Vector2(500, 475))


func _spawn_deep_layer() -> void:
	pass  # === Task 5 === 碎石 + 埋藏背包


func _spawn_item(p_tag: String, p_kind: String, p_size: Vector2, p_color: Color, p_label: String, p_obs: String, p_pos: Vector2) -> MineItem:
	var item: MineItem = MINE_ITEM_SCENE.instantiate()
	_world.add_child(item)
	item.setup(p_tag, p_kind, p_size, p_color, p_label, p_obs)
	item.global_position = p_pos
	return item


# ============================================================
#  输入 / 拾取（钉子拖拽，参考 gravity_test）
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.global_position
		if event.pressed and not _drag_ctrl.is_dragging():
			_try_pickup(pos)
		elif not event.pressed and _drag_ctrl.is_dragging():
			_drag_ctrl.end_drag()
	elif event is InputEventMouseMotion and _drag_ctrl.is_dragging():
		_drag_ctrl.update_target_global(event.global_position)


func _try_pickup(pos: Vector2) -> void:
	var hit := _hit_test_item(pos)
	if hit == null:
		return
	if hit.kind == "backpack" and not _rubble_cleared:
		return  # 背包还埋着，扒开前抓不到
	_drag_ctrl.start_drag(hit, pos)
	_on_item_grabbed(hit)


func _hit_test_item(pos: Vector2) -> MineItem:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_bodies = true
	var hits := space.intersect_point(params, 8)
	for h in hits:
		var collider = h.get("collider")
		if collider is MineItem and collider.visible:
			return collider
	return null


func _on_item_grabbed(item: MineItem) -> void:
	match item.kind:
		"observation":
			if item.observation != "":
				_obs_label.text = item.observation
		"contract":
			_take_contract()   # === Task 7 ===


# ============================================================
#  物理帧：扒开判定 / 倾倒判定（Task 5 / 6 填）
# ============================================================

func _physics_process(_delta: float) -> void:
	_check_rubble_cleared()   # === Task 5 ===
	_check_backpack_spill()   # === Task 6 ===


func _check_rubble_cleared() -> void:
	pass  # === Task 5 ===


func _check_backpack_spill() -> void:
	pass  # === Task 6 ===


# ============================================================
#  授予委托书（Task 7 填）
# ============================================================

func _take_contract() -> void:
	pass  # === Task 7 ===


# ============================================================
#  离开 + 软提示
# ============================================================

func _on_leave_pressed() -> void:
	# 未扒碎石（=没深挖）就想走 → 先耳语一句、可坚持再点离开。
	if not _rubble_cleared and not _contract_taken and not _leave_hint_shown:
		_leave_hint_shown = true
		_hint_label.text = "血迹仍延向未翻处……总觉得还藏着什么。"
		return
	finished.emit()
