extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var day_map_scene := preload("res://scenes/ui/DayMap.tscn")
	var view = day_map_scene.instantiate()
	add_child(view)
	await get_tree().process_frame
	view._switch_tab(true)
	await get_tree().process_frame
	_test_visible_scrollbars(view)
	view.queue_free()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DAYMAP-SCROLLBARS] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DAYMAP-SCROLLBARS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DAYMAP-SCROLLBARS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_visible_scrollbars(view) -> void:
	var location_scroll = view.get_node_or_null("MapArea/LocationScroll")
	_ok(location_scroll is ScrollContainer, "gathering locations use a scroll container")
	if location_scroll is ScrollContainer:
		_ok(location_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS,
			"gathering scrollbar is always visible")
		_ok(location_scroll.get_node_or_null("LocationList") is VBoxContainer,
			"gathering list belongs to the scrolling viewport")
	var shop_scroll = view._shop_panel
	_ok(shop_scroll is ScrollContainer, "shop uses a scroll container")
	if shop_scroll is ScrollContainer:
		_ok(shop_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS,
			"shop scrollbar is always visible")
		_ok(shop_scroll.get_v_scroll_bar().visible, "shop vertical scrollbar is visibly rendered")
		_ok(shop_scroll.position.x + shop_scroll.size.x <= view.get_node("MapArea").size.x,
			"shop scrollbar stays inside the visible map area")
