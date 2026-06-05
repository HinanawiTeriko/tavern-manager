extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var day_map_scene := preload("res://scenes/ui/DayMap.tscn")
	var view = day_map_scene.instantiate()
	add_child(view)
	await get_tree().process_frame
	_test_daymap_art_assets(view)
	_test_tavern_node(view)
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


func _test_tavern_node(view) -> void:
	# 酒馆/家节点存在、用哨兵 id、且不再有 GoButton
	_ok(view._home_marker != null and is_instance_valid(view._home_marker),
		"tavern home marker exists")
	_ok(view._home_marker.location_id == "__home__",
		"home marker uses sentinel id")
	_ok(view.get_node_or_null("UILayer/GoButton") == null,
		"GoButton removed in favor of tavern node")
	# 选中家 → 详情按钮变「开门营业」
	view._select_marker("__home__")
	_ok(view._detail_panel.get_node("GoHereBtn").text == "开门营业",
		"selecting tavern shows 开门营业 button")


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


func _test_daymap_art_assets(view) -> void:
	var background := view.get_node("MapWorld/Background") as Sprite2D
	_ok(background.texture != null, "daymap background has a runtime texture")
	if background.texture != null:
		_ok(background.texture.resource_path.ends_with("assets/textures/daymap/daymap_bg.png"),
			"daymap background uses the native-pipeline runtime art")
	_ok(view._home_marker != null and is_instance_valid(view._home_marker),
		"home marker exists before checking art")
	if view._home_marker != null and is_instance_valid(view._home_marker):
		_ok(view._home_marker.has_method("has_icon_texture"),
			"marker exposes icon texture state for tests")
		if view._home_marker.has_method("has_icon_texture"):
			_ok(view._home_marker.has_icon_texture(), "home marker has an icon texture")
