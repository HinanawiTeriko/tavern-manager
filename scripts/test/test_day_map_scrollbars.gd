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
	# 四个区域拼块都摆出来了
	var gm = view.get_node("/root/GameManager")
	var regions: Array = gm.day_map.get_regions()
	_ok(regions.size() == 4, "摆出 4 个区域拼块")
	for r in regions:
		var rid := String(r.get("id", ""))
		var tile = view.get_node_or_null("MapWorld/RegionTile_" + rid)
		_ok(tile is Sprite2D and tile.texture != null,
			"区域 %s 有背景拼块且有纹理" % rid)
	# 相机边界 = 区域并集 (0,0)-(2560,1440)，动态最小缩放=0.5
	_ok(view._camera.map_max == Vector2(2560, 1440),
		"相机 map_max = (2560,1440)")
	_ok(absf(view._camera.min_zoom - 0.5) < 0.01,
		"2×2 下动态最小缩放 = 0.5（缩到看全整图不露灰）")
	# home marker 存在且在地图边界内
	_ok(view._home_marker != null and is_instance_valid(view._home_marker),
		"home marker 存在")
	if view._home_marker != null and is_instance_valid(view._home_marker):
		_ok(view._home_marker.position.x >= 0.0 and view._home_marker.position.x <= 2560.0
				and view._home_marker.position.y >= 0.0 and view._home_marker.position.y <= 1440.0,
			"home marker 在地图边界内")
		if view._home_marker.has_method("has_icon_texture"):
			_ok(view._home_marker.has_icon_texture(), "home marker 有图标纹理")
