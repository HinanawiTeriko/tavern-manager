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
	# 采集区已从滚动列表改为交互地图：验证地图结构而非旧的 LocationScroll
	_ok(view.get_node_or_null("MapWorld/Points") is Node2D,
		"gathering uses an interactive map (MapWorld/Points)")
	_ok(view.get_node_or_null("UILayer/DetailPanel") is Panel,
		"map has a right-side detail panel")
	# 回归：覆盖在地图上的容器 Control 必须放行点击，否则盖住的点点不了
	_ok(view.get_node("UILayer/MapArea").mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"MapArea does not eat clicks on map points")
	_ok(view.get_node("UILayer/TopBar").mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"TopBar does not eat clicks on map points")
	var shop_scroll = view._shop_panel
	_ok(shop_scroll is ScrollContainer, "shop uses a scroll container")
	if shop_scroll is ScrollContainer:
		_ok(shop_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS,
			"shop scrollbar is always visible")
		_ok(shop_scroll.get_v_scroll_bar().visible, "shop vertical scrollbar is visibly rendered")
		_ok(shop_scroll.position.x + shop_scroll.size.x <= view.get_node("UILayer/MapArea").size.x,
			"shop scrollbar stays inside the visible map area")
