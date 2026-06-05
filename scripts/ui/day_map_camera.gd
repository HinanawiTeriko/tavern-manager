class_name DayMapCamera
extends Camera2D

## DayMap 地图相机：滚轮缩放、拖拽平移、钳制在地图范围内、fly_to 平滑移动。
## 输入仅在 active 时响应（切到商店标签 / 矿道全屏时由 view 置 false）。

const MIN_ZOOM := 0.5
const MAX_ZOOM := 1.6
const ZOOM_STEP := 0.1

# 地图逻辑范围（与 locations.json pos 同坐标系）
var map_min := Vector2(0, 0)
var map_max := Vector2(1280, 720)

var active: bool = true

var _dragging: bool = false
var _fly_tween: Tween = null


func _ready() -> void:
	position_smoothing_enabled = false
	_clamp_position()


func set_active(value: bool) -> void:
	active = value
	if not active:
		_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(-ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		# 屏幕位移换算到世界位移（除以 zoom）；zoom 越小看得越广，位移越大
		var delta: Vector2 = event.relative / zoom
		position -= delta
		_clamp_position()


func _apply_zoom(step: float) -> void:
	var z: float = clampf(zoom.x + step, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	_clamp_position()


func _clamp_position() -> void:
	position.x = clampf(position.x, map_min.x, map_max.x)
	position.y = clampf(position.y, map_min.y, map_max.y)


## 平滑飞到目标点（用于新地点亮相）。返回 tween 以便调用方 await 其完成。
func fly_to(world_pos: Vector2, target_zoom: float = 1.0, duration: float = 0.6) -> Tween:
	if _fly_tween != null and _fly_tween.is_valid():
		_fly_tween.kill()
	var tz: float = clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	var dest := Vector2(
		clampf(world_pos.x, map_min.x, map_max.x),
		clampf(world_pos.y, map_min.y, map_max.y)
	)
	_fly_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fly_tween.tween_property(self, "position", dest, duration)
	_fly_tween.tween_property(self, "zoom", Vector2(tz, tz), duration)
	return _fly_tween
