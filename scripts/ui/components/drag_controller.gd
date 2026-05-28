class_name DragController
extends Node

## 钉子拖拽：拖拽中物品始终是 RigidBody2D，由 PinJoint2D 钉在跟随鼠标的运动学锚点上。
##
## 用法（在 gravity_test 中）：
##   按下: start_drag(body, mouse_global_pos)
##   移动: update_target_global(pos)
##   松开: end_drag()

signal drag_started(body: DeskItem)
signal drag_ended(body: DeskItem)

# —— 物理参数 ——
const JOINT_SOFTNESS: float = 0.0    # 0 = 刚性钉子；调到 0.01~0.05 可减抖动

# —— 内部状态 ——
var _body: DeskItem = null
var _anchor: AnimatableBody2D = null
var _joint: PinJoint2D = null


# ================================================================
#  公开 API
# ================================================================

func is_dragging() -> bool:
	return _body != null


func get_body() -> DeskItem:
	return _body


func start_drag(body: DeskItem, mouse_global_pos: Vector2) -> void:
	## 在 body 上创建钉子，钉子位置 = mouse_global_pos（即按下时光标在物品上的局部点）。
	if _body != null:
		end_drag()

	_body = body

	# 锚点：不参与碰撞的 AnimatableBody2D，跟随鼠标
	_anchor = AnimatableBody2D.new()
	_anchor.collision_layer = 0
	_anchor.collision_mask = 0
	_anchor.global_position = mouse_global_pos
	body.get_parent().add_child(_anchor)

	# 钉子关节：把锚点和 body 钉在一起，钉点在世界坐标的鼠标按下位置
	_joint = PinJoint2D.new()
	_joint.global_position = mouse_global_pos
	body.get_parent().add_child(_joint)
	_joint.node_a = _anchor.get_path()
	_joint.node_b = body.get_path()
	_joint.softness = JOINT_SOFTNESS

	drag_started.emit(_body)


func update_target_global(pos: Vector2) -> void:
	## 鼠标移动时调用。改锚点位置，物理引擎下一帧自动拖动 body。
	if _anchor != null:
		_anchor.global_position = pos


func end_drag() -> void:
	## 松手：销毁锚点和关节，body 保持 RigidBody2D 状态继续受重力运动。
	if _body == null:
		return

	var body := _body
	_body = null

	if _joint != null:
		_joint.queue_free()
		_joint = null
	if _anchor != null:
		_anchor.queue_free()
		_anchor = null

	drag_ended.emit(body)


# ================================================================
#  生命周期
# ================================================================

func _exit_tree() -> void:
	if _joint != null:
		_joint.queue_free()
		_joint = null
	if _anchor != null:
		_anchor.queue_free()
		_anchor = null
	_body = null
