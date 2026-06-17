extends Node

## DayMapCamera：可视矩形钳进边界（不露灰）+ 动态最小缩放=max(vw/w, vh/h)。

var _checks := 0
var _failures := 0

func _ready() -> void:
	var cam := DayMapCamera.new()
	add_child(cam)
	await get_tree().process_frame

	var vp := get_viewport().get_visible_rect().size
	cam.set_bounds(Vector2(0, 0), Vector2(2560, 1440))

	# 动态最小缩放 = max(vw/w, vh/h)
	var expected_min := maxf(vp.x / 2560.0, vp.y / 1440.0)
	_ok(absf(cam.min_zoom - expected_min) < 0.001, "min_zoom = max(vw/w,vh/h)")

	# 各缩放档把镜头推向四角，断言可视矩形不越界
	for z in [cam.min_zoom, 1.0, cam.MAX_ZOOM]:
		cam.zoom = Vector2(z, z)
		for corner in [Vector2(-9999,-9999), Vector2(9999,9999), Vector2(-9999,9999), Vector2(9999,-9999)]:
			cam.position = corner
			cam._clamp_position()
			_assert_view_in_bounds(cam, vp, z)

	await _test_fly_to_edge_locations_stays_inside_map(cam, vp)
	_test_mouse_wheel_zoom_controls(cam)
	_test_tutorial_blocks_mouse_wheel_zoom(cam)
	_finish()


func _test_fly_to_edge_locations_stays_inside_map(cam: DayMapCamera, vp: Vector2) -> void:
	for target in [Vector2(250, 620), Vector2(2250, 1160), Vector2(0, 0), Vector2(2560, 1440)]:
		cam.zoom = Vector2(cam.min_zoom, cam.min_zoom)
		cam.position = (cam.map_min + cam.map_max) * 0.5
		await cam.fly_to(target, 1.0, 0.01).finished
		_assert_view_in_bounds(cam, vp, cam.zoom.x)


func _test_mouse_wheel_zoom_controls(cam: DayMapCamera) -> void:
	cam.active = true
	cam.zoom = Vector2(1.0, 1.0)
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	cam._unhandled_input(wheel_up)
	_ok(cam.zoom.x > 1.0, "mouse wheel zooms in so markers can be inspected")

	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	cam._unhandled_input(wheel_down)
	_ok(absf(cam.zoom.x - 1.0) < 0.001, "mouse wheel zooms back out one step")


func _test_tutorial_blocks_mouse_wheel_zoom(cam: DayMapCamera) -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return
	var old_active := bool(tm._is_active)
	tm._is_active = true
	cam.active = true
	cam.zoom = Vector2(1.0, 1.0)
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	cam._unhandled_input(wheel_up)
	_ok(absf(cam.zoom.x - 1.0) < 0.001, "active tutorial blocks DayMap mouse wheel zoom")
	tm._is_active = old_active

func _assert_view_in_bounds(cam: DayMapCamera, vp: Vector2, z: float) -> void:
	var half := vp * 0.5 / z
	var left := cam.position.x - half.x
	var right := cam.position.x + half.x
	var top := cam.position.y - half.y
	var bottom := cam.position.y + half.y
	var eps := 0.5
	_ok(left >= cam.map_min.x - eps and right <= cam.map_max.x + eps \
		and top >= cam.map_min.y - eps and bottom <= cam.map_max.y + eps,
		"zoom %.2f：可视矩形在边界内（不露灰）" % z)

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-CAMERA] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-CAMERA] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-CAMERA] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
