extends Node

# 回归：DayMap 偶尔同时出现两个金色选中圈。
# 根因——多处直接把 _selected_id 置空却没撤掉上一个 marker 的金圈；
# 由于 home/已访问/商店 marker 常驻，旧圈残留，下一次选中又叠一个圈。
# 选中清理必须经由 _clear_selection() 统一撤圈。

var _checks := 0
var _failures := 0

const DAYMAP_SCENE := preload("res://scenes/ui/DayMap.tscn")


func _ready() -> void:
	await _test_single_selection_ring()
	await _test_tutorial_highlight_rects_follow_map_area()
	await _test_yield_text_uses_item_display_names()
	_test_clear_selection_is_centralized()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DAYMAP-SEL] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DAYMAP-SEL] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DAYMAP-SEL] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _selected_ring_count(view) -> int:
	var n := 0
	for m in view._markers.values():
		if is_instance_valid(m) and m._selected:
			n += 1
	if view._home_marker != null and is_instance_valid(view._home_marker) and view._home_marker._selected:
		n += 1
	return n


func _control_screen_rect(control: Control) -> Array:
	if control == null:
		return []
	var rect := control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _rect_array_close(actual: Array, expected: Array, tolerance: float = 0.5) -> bool:
	if actual.size() < 4 or expected.size() < 4:
		return false
	for index in range(4):
		if abs(float(actual[index]) - float(expected[index])) > tolerance:
			return false
	return true


func _test_single_selection_ring() -> void:
	var view = DAYMAP_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame
	view._ensure_home_marker()
	view._create_marker({"id": "loc_a", "name": "A", "pos": [100, 100]}, false)
	view._create_marker({"id": "loc_b", "name": "B", "pos": [200, 200]}, false)

	view._select_marker("loc_a")
	_ok(_selected_ring_count(view) == 1, "selecting A shows exactly one ring")

	# 模拟访问/进店/跨天的清空：必须连同金圈一起撤掉，否则下一次选中会叠出第二个圈
	view._clear_selection()
	_ok(_selected_ring_count(view) == 0, "clearing selection removes the golden ring")
	_ok(view._selected_id == "", "clearing resets _selected_id")

	view._select_marker("loc_b")
	_ok(_selected_ring_count(view) == 1, "after clear, selecting B leaves exactly one ring (no lingering A)")

	# 直接换选（不经清空）也只能有一个圈
	view._select_marker("loc_a")
	_ok(_selected_ring_count(view) == 1, "switching selection A↔B never stacks two rings")

	view.queue_free()


func _test_yield_text_uses_item_display_names() -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 2
	gm.start_day_map(2)
	var view = DAYMAP_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame

	var forest := _find_location(gm.day_map.get_locations(), "mushroom_forest")
	var day2_yield := String(view._yield_text(forest))
	_ok(day2_yield.contains("沉睡花粉"), "DayMap day-specific yield uses the item display name")
	_ok(not day2_yield.contains("sleep_powder"), "DayMap day-specific yield does not expose item ids")

	gm.economy.current_day = 3
	gm.start_day_map(3)
	forest = _find_location(gm.day_map.get_locations(), "mushroom_forest")
	var day3_yield := String(view._yield_text(forest))
	_ok(day3_yield.contains("草药"), "DayMap repeatable yield uses the item display name")
	_ok(not day3_yield.contains("herb"), "DayMap repeatable yield does not expose item ids")

	view.queue_free()


func _find_location(locations: Array, location_id: String) -> Dictionary:
	for loc in locations:
		if String(loc.get("id", "")) == location_id:
			return loc
	return {}


func _test_tutorial_highlight_rects_follow_map_area() -> void:
	var view = DAYMAP_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	var map_area := view.get_node_or_null("UILayer/MapArea") as Control
	_ok(map_area != null, "DayMap MapArea remains available for tutorial highlights")
	if map_area != null:
		var expected_rect := _control_screen_rect(map_area)
		var gather_rects: Dictionary = view._gather_tutorial_rects()
		_ok(_rect_array_close(gather_rects.get("MapArea", []) as Array, expected_rect),
			"gather tutorial MapArea highlight follows the live DayMap MapArea rect")
		_ok(view.has_method("_shop_tutorial_rects"), "DayMapView exposes live shop tutorial rects")
		if view.has_method("_shop_tutorial_rects"):
			var shop_rects: Dictionary = view._shop_tutorial_rects()
			_ok(_rect_array_close(shop_rects.get("MapArea", []) as Array, expected_rect),
				"shop tutorial MapArea highlight follows the live DayMap MapArea rect")

	view.queue_free()


func _test_clear_selection_is_centralized() -> void:
	var f := FileAccess.open("res://scripts/ui/day_map_view.gd", FileAccess.READ)
	_ok(f != null, "view script readable")
	if f == null:
		return
	var src := f.get_as_text()
	f.close()
	_ok(src.contains("func _clear_selection"), "view defines a _clear_selection helper")
	# 选中清空的入口（换选 + 访问 + 进店 + 跨天）必须全部走 _clear_selection()
	var calls := src.count("_clear_selection()")
	_ok(calls >= 4, "all selection-reset paths route through _clear_selection (found %d call sites)" % calls)
