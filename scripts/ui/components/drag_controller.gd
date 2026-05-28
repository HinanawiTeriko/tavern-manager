class_name DragController
extends Node

## 纯视觉拖拽控制器：惯性跟随、下落弹跳、脱靶回弹
##
## 用法：
##   bar_workspace._input → start_drag / update_target / end_drag_to / end_drag_return
##   bar_workspace._process → process_step
##   bar_workspace 连接 animation_finished → 执行游戏逻辑

signal animation_finished(key: String, dest: Vector2, end_type: String)  # end_type: "placed" | "returned"

# —— 可调物理参数 ——
const FOLLOW_WEIGHT: float = 0.15     # lerp 权重（越大越跟手）
const MAX_LAG: float = 15.0           # 最大落后 px
const DROP_TIME: float = 0.12         # 下落时长秒
const BOUNCE_AMP: float = 10.0        # 弹跳过冲 px
const BOUNCE_TIME: float = 0.15       # 弹跳回弹秒
const RETURN_TIME: float = 0.25       # 脱靶回弹总时长秒
const RETURN_ARC: float = -50.0       # 弧线最高点（屏幕 Y 负 = 向上）
const PANEL_SIZE: float = 64.0

# —— 内部状态 ——
var _active: bool = false
var _item_key: String = ""
var _drag_offset: Vector2      # 鼠标相对物品中心的偏移
var _virtual_pos: Vector2      # lerp 平滑位置
var _target_pos: Vector2       # 鼠标目标位置
var _layer: CanvasLayer
var _panel: ColorRect
var _tween: Tween

# 结束回调用
var _end_dest: Vector2
var _end_type: String


# ================================================================
#  初始化
# ================================================================

func _enter_tree() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.name = "DragLayer"
	add_child(_layer)

	_panel = ColorRect.new()
	_panel.size = Vector2(PANEL_SIZE, PANEL_SIZE)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_panel)


func _exit_tree() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null


# ================================================================
#  公开 API
# ================================================================

func is_dragging() -> bool:
	return _active or (_tween != null and _tween.is_valid() and _tween.is_running())


func get_item_key() -> String:
	return _item_key


func get_panel_color() -> Color:
	return _panel.color if _panel else Color.GRAY


func get_visual_pos() -> Vector2:
	## 返回拖拽物品中心的屏幕坐标（lerp 后），用于松手后无缝衔接
	return _virtual_pos + _drag_offset


func start_drag(key: String, start_pos: Vector2, col: Color, off: Vector2 = Vector2.ZERO) -> void:
	_active = true
	_item_key = key
	_drag_offset = off if off != Vector2.ZERO else Vector2(PANEL_SIZE * 0.5, PANEL_SIZE * 0.5)
	_target_pos = start_pos
	_virtual_pos = start_pos

	_panel.color = col
	_panel.visible = true
	_panel.position = start_pos - _drag_offset

	if _tween != null and _tween.is_valid():
		_tween.kill()


func update_target(event: InputEventMouseMotion) -> void:
	if not _active:
		return
	_target_pos = event.position - _drag_offset


func update_target_global(pos: Vector2) -> void:
	## 直接用全局坐标更新目标（当调用方使用 _gui_input 时，
	## event.position 是本地坐标，不能直接给 CanvasLayer 用）
	if not _active:
		return
	_target_pos = pos - _drag_offset


func process_step(delta: float) -> void:
	if not _active:
		return

	# lerp 惯性跟随
	var w: float = FOLLOW_WEIGHT * delta * 60.0
	_virtual_pos = _virtual_pos.lerp(_target_pos, w)

	# 限制最大滞后
	var lag: Vector2 = _target_pos - _virtual_pos
	if lag.length() > MAX_LAG:
		_virtual_pos = _target_pos - lag.normalized() * MAX_LAG

	_panel.position = _virtual_pos


func end_drag_to(target_pos: Vector2) -> void:
	## 落在有效目标 — 下落过冲 + 弹回
	if not _active:
		return
	_active = false
	_end_dest = target_pos
	_end_type = "placed"

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()

	# 下落（过冲到目标下方）
	var overshoot: Vector2 = Vector2(target_pos.x, target_pos.y + BOUNCE_AMP)
	_tween.tween_property(_panel, "position", overshoot, DROP_TIME)
	# 弹回目标位置
	_tween.tween_property(_panel, "position", target_pos, BOUNCE_TIME)
	_tween.tween_callback(_finish)


func end_drag_return(origin_pos: Vector2) -> void:
	## 脱靶 — 弧线飞回 + 小弹跳
	if not _active:
		return
	_active = false
	_end_dest = origin_pos
	_end_type = "returned"

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()

	# 二次贝塞尔弧线
	var mid: Vector2 = (_virtual_pos + origin_pos) * 0.5 + Vector2(0, RETURN_ARC)
	var steps: int = max(1, int(RETURN_TIME / 0.016))
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var pt: Vector2 = (1.0 - t) * (1.0 - t) * _virtual_pos \
		                + 2.0 * (1.0 - t) * t * mid \
		                + t * t * origin_pos
		_tween.tween_property(_panel, "position", pt, 0.016)

	# 落地小弹跳
	_tween.tween_property(_panel, "position", Vector2(origin_pos.x, origin_pos.y - 6), 0.06)
	_tween.tween_property(_panel, "position", origin_pos, 0.06)
	_tween.tween_callback(_finish)


func cancel() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_active = false
	_panel.visible = false
	_item_key = ""


# ================================================================
#  内部
# ================================================================

func _finish() -> void:
	_panel.visible = false
	animation_finished.emit(_item_key, _end_dest, _end_type)
	_item_key = ""
