class_name DragController
extends Node

## 钉子拖拽：拖拽中物品始终是 RigidBody2D，由 PinJoint2D 钉在跟随鼠标的运动学锚点上。
##
## 用法（在 gravity_test 中）：
##   按下: start_drag(body, mouse_global_pos)
##   移动: update_target_global(pos)
##   松开: end_drag()

signal drag_started(body: RigidBody2D)
signal drag_ended(body: RigidBody2D)

# —— 物理参数 ——
const JOINT_SOFTNESS: float = 0.0    # 0 = 刚性钉子；增大会使约束更"软"/有弹性（不是减抖动 — 抖动调 angular_damp/linear_damp）
const SERVE_SPEED_SMOOTHING: float = 0.3   # 平滑速度 EMA 系数：每物理帧把瞬时速度混入；越大越跟手、越小越稳

# —— 内部状态 ——
var _body: RigidBody2D = null
var _anchor: AnimatableBody2D = null
var _joint: PinJoint2D = null
var _serve_speed: float = 0.0   # 拖拽期间的平滑速度（EMA），上菜风格判定用；start_drag 清零


# ================================================================
#  公开 API
# ================================================================

func is_dragging() -> bool:
	_cancel_stale_drag()
	return _body != null


func get_body() -> RigidBody2D:
	_cancel_stale_drag()
	return _body


func get_serve_speed() -> float:
	## 上菜风格信号：最近一段拖拽的平滑速度（松手后保持到下次 start_drag）。
	return _serve_speed


func start_drag(body: RigidBody2D, mouse_global_pos: Vector2) -> void:
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	## 在 body 上创建钉子，钉子位置 = mouse_global_pos（即按下时光标在物品上的局部点）。
	if _body != null:
		end_drag()

	_body = body
	_serve_speed = 0.0
	if not body.tree_exiting.is_connected(_on_dragged_body_tree_exiting):
		body.tree_exiting.connect(_on_dragged_body_tree_exiting)

	# 锚点：不参与碰撞的 AnimatableBody2D，跟随鼠标
	_anchor = AnimatableBody2D.new()
	_anchor.collision_layer = 0
	_anchor.collision_mask = 0
	_anchor.global_position = mouse_global_pos
	var anchor_shape := CollisionShape2D.new()
	anchor_shape.shape = RectangleShape2D.new()
	anchor_shape.disabled = true
	_anchor.add_child(anchor_shape)
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
	_cancel_stale_drag()
	## 鼠标移动时调用。改锚点位置，物理引擎下一帧自动拖动 body。
	if _anchor != null:
		_anchor.global_position = pos


func end_drag() -> void:
	## 松手：销毁锚点和关节，body 保持 RigidBody2D 状态继续受重力运动。
	if _body == null:
		return

	_finish_drag(is_instance_valid(_body) and not _body.is_queued_for_deletion())


func _on_dragged_body_tree_exiting() -> void:
	if _body == null:
		return
	_finish_drag(is_instance_valid(_body))


func _cancel_stale_drag() -> void:
	if _body == null:
		return
	if is_instance_valid(_body) and not _body.is_queued_for_deletion():
		return
	_finish_drag(is_instance_valid(_body))


func _finish_drag(emit_ended_for_valid_body: bool) -> void:
	var body := _body
	_body = null
	_disconnect_dragged_body_signal(body)
	_queue_free_drag_handles()
	if emit_ended_for_valid_body and is_instance_valid(body):
		drag_ended.emit(body)


func _disconnect_dragged_body_signal(body: RigidBody2D) -> void:
	if not is_instance_valid(body):
		return
	if body.tree_exiting.is_connected(_on_dragged_body_tree_exiting):
		body.tree_exiting.disconnect(_on_dragged_body_tree_exiting)


func _queue_free_drag_handles() -> void:
	if _joint != null:
		if is_instance_valid(_joint) and not _joint.is_queued_for_deletion():
			_joint.queue_free()
		_joint = null
	if _anchor != null:
		if is_instance_valid(_anchor) and not _anchor.is_queued_for_deletion():
			_anchor.queue_free()
		_anchor = null


# ================================================================
#  生命周期
# ================================================================

func _physics_process(_delta: float) -> void:
	## 拖拽期间每帧把瞬时速度混入平滑速度（EMA）。松手后 _body 置空即停止更新，
	## _serve_speed 保留最后一段拖拽的平滑值供 get_serve_speed() 读取。
	_cancel_stale_drag()
	if _body != null:
		_serve_speed = lerp(_serve_speed, _body.linear_velocity.length(), SERVE_SPEED_SMOOTHING)


func _exit_tree() -> void:
	end_drag()
