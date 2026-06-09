class_name DayMapCamera
extends Camera2D

## DayMap 地图相机：滚轮缩放、拖拽平移、钳制在地图范围内、fly_to 平滑移动。
## 输入仅在 active 时响应（切到商店标签 / 矿道全屏时由 view 置 false）。

const MAX_ZOOM := 1.6
const ZOOM_STEP := 0.1
const USER_ZOOM_ENABLED := true

## 动态最小缩放：=max(viewport.x/map_w, viewport.y/map_h)，由 set_bounds 算出。
## 这是"可视矩形恰好不超出地图"的临界缩放——任何缩放都不露灰，且能缩到看全整图。
var min_zoom: float = 0.5

# 地图逻辑范围（与 locations.json pos 同坐标系）
var map_min := Vector2(0, 0)
var map_max := Vector2(1280, 720)

var active: bool = true

var _dragging: bool = false
var _fly_tween: Tween = null


func _ready() -> void:
	position_smoothing_enabled = false
	_clamp_position()


## 由 DayMapView 注入地图边界（区域并集），据此算动态最小缩放并立即钳制。
func set_bounds(min_v: Vector2, max_v: Vector2) -> void:
	map_min = min_v
	map_max = max_v
	var vp := _viewport_size()
	var w := maxf(max_v.x - min_v.x, 1.0)
	var h := maxf(max_v.y - min_v.y, 1.0)
	min_zoom = minf(maxf(vp.x / w, vp.y / h), MAX_ZOOM)
	var z: float = clampf(zoom.x, min_zoom, MAX_ZOOM)
	zoom = Vector2(z, z)
	_clamp_position()


func _viewport_size() -> Vector2:
	return get_viewport_rect().size


func set_active(value: bool) -> void:
	active = value
	if not active:
		_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if USER_ZOOM_ENABLED:
				_apply_zoom(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if USER_ZOOM_ENABLED:
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
	var z: float = clampf(zoom.x + step, min_zoom, MAX_ZOOM)
	zoom = Vector2(z, z)
	_clamp_position()


func _clamp_position() -> void:
	var half := _viewport_size() * 0.5 / zoom
	var min_x := map_min.x + half.x
	var max_x := map_max.x - half.x
	var min_y := map_min.y + half.y
	var max_y := map_max.y - half.y
	# 某轴地图比视口还小 → 钳到该轴中心，避免 min>max 抖动
	if min_x > max_x:
		min_x = (map_min.x + map_max.x) * 0.5
		max_x = min_x
	if min_y > max_y:
		min_y = (map_min.y + map_max.y) * 0.5
		max_y = min_y
	position.x = clampf(position.x, min_x, max_x)
	position.y = clampf(position.y, min_y, max_y)


## 平滑飞到目标点（用于新地点亮相）。返回 tween 以便调用方 await 其完成。
func fly_to(world_pos: Vector2, target_zoom: float = 1.0, duration: float = 0.6) -> Tween:
	if _fly_tween != null and _fly_tween.is_valid():
		_fly_tween.kill()
	var tz: float = clampf(target_zoom, min_zoom, MAX_ZOOM)
	var dest := Vector2(
		clampf(world_pos.x, map_min.x, map_max.x),
		clampf(world_pos.y, map_min.y, map_max.y)
	)
	_fly_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fly_tween.tween_property(self, "position", dest, duration)
	_fly_tween.tween_property(self, "zoom", Vector2(tz, tz), duration)
	return _fly_tween
