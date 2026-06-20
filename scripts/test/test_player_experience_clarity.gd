extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_daymap_today_intel_contract()
	await _test_tavern_menu_tag_chips()
	await _test_inventory_drag_handoff()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-PLAYER-EXPERIENCE-CLARITY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-PLAYER-EXPERIENCE-CLARITY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-PLAYER-EXPERIENCE-CLARITY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _button_stylebox_texture_path(button: Button, state: String) -> String:
	var style := button.get_theme_stylebox(state) as StyleBoxTexture
	if style == null or style.texture == null:
		return ""
	return String(style.texture.resource_path)


func _test_daymap_today_intel_contract() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.start_day_map(1)
	if gm.rumors != null:
		gm.rumors.restore_state({
			"current_day": 1,
			"heard_ids": [
				"dark_river_cold_shift",
				"grape_trellis_sour_wine",
				"mill_farm_malt_dust",
				"market_shop_trade_talk",
				"mushroom_forest_clear_scent",
			],
			"today_ids": [
				"dark_river_cold_shift",
				"grape_trellis_sour_wine",
				"mill_farm_malt_dust",
				"market_shop_trade_talk",
				"mushroom_forest_clear_scent",
			],
		})
	var view := preload("res://scenes/ui/DayMap.tscn").instantiate()
	add_child(view)
	await get_tree().process_frame

	var button := view.get_node_or_null("UILayer/TodayIntelBtn") as Button
	_ok(button != null, "DayMap keeps TodayIntelBtn only as a hidden compatibility node")
	if button != null:
		_ok(not button.visible, "TodayIntelBtn is not visible to the player")
		_ok(button.disabled, "TodayIntelBtn is not clickable")
		_ok(button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "TodayIntelBtn does not catch input")
		_ok(button.size == Vector2.ZERO, "TodayIntelBtn keeps no visible hit area")
		_ok(button.text == "", "TodayIntelBtn does not render visible text")
		_ok(_button_stylebox_texture_path(button, "normal") == "", "TodayIntelBtn uses no visible button art")
		_ok(view.get_node_or_null("UILayer/TopBar/TodayIntelBtn") == null,
			"TodayIntelBtn is not embedded in the status topbar")
	var panel := view.get_node_or_null("UILayer/TodayIntelPanel") as Panel
	_ok(panel != null, "DayMap exposes TodayIntelPanel")
	if panel != null:
		_ok(panel.size == Vector2(560, 520), "TodayIntelPanel keeps fixed readable size")
		_ok(not panel.visible, "TodayIntelPanel starts hidden")
		var scroll := panel.get_node_or_null("IntelScroll") as ScrollContainer
		_ok(scroll != null and scroll.clip_contents, "TodayIntelPanel clips text inside IntelScroll")
		_ok(scroll != null and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
			"TodayIntelPanel hides the scrollbar while keeping the scroll area")
	if button != null and panel != null:
		button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_ok(not panel.visible, "hidden TodayIntelBtn does not open TodayIntelPanel")
		view._open_today_intel_panel()
		await get_tree().process_frame
		await get_tree().process_frame
		_ok(panel.visible, "TodayIntelPanel remains available to internal callers")
		var list := panel.get_node_or_null("IntelScroll/IntelList") as VBoxContainer
		_ok(list != null and list.get_child_count() >= 5,
			"TodayIntelPanel can render enough rumor entries to require scrolling")
		if list != null and list.get_child_count() > 0:
			var entry := list.get_child(0) as Control
			_ok(entry != null and entry.clip_contents,
				"TodayIntelPanel rumor entry clips text to the brush safe area")
			var title: Label = null
			if entry != null:
				title = entry.find_child("Title", true, false) as Label
			_ok(title != null and not title.text.contains("dark_river"),
				"TodayIntelPanel hides raw location ids from player text")
			_ok(title != null and title.text.contains("暗河"),
				"TodayIntelPanel shows localized DayMap location names")
		var scroll := panel.get_node_or_null("IntelScroll") as ScrollContainer
		if scroll != null and list != null and list.size.y > scroll.size.y:
			scroll.scroll_vertical = 96
			await get_tree().process_frame
			_ok(scroll.scroll_vertical > 0,
				"TodayIntelPanel remains scrollable with the scrollbar hidden")
	var before: int = gm.inventory_sys.get_count("ale")
	view._on_inventory_item_dropped("ale", Vector2(100, 100))
	_ok(gm.inventory_sys.get_count("ale") == before, "DayMap inventory drop does not duplicate items")

	view.queue_free()
	await get_tree().process_frame


func _test_tavern_menu_tag_chips() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	if gm.rumors != null:
		gm.rumors.restore_state({
			"current_day": 1,
			"heard_ids": ["dark_river_cold_shift"],
			"today_ids": ["dark_river_cold_shift"],
		})
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame
	if tavern.has_method("configure_menu_preparation"):
		tavern.configure_menu_preparation(gm.get_today_rumors(), gm.get_menu_preparation_echoes())
		await get_tree().process_frame

	var product_list := tavern.get_node_or_null("MenuPrepPanel/ProductScroll/ProductList") as VBoxContainer
	_ok(product_list != null, "menu preparation renders a ProductList")
	var product_button: Button = null
	if product_list != null:
		for child in product_list.get_children():
			if child is Button:
				product_button = child
				break
	_ok(product_button != null, "menu preparation renders product buttons")
	if product_button != null:
		_ok(product_button.custom_minimum_size.y <= 74.0, "menu product buttons keep stable compact height")
		var name_price := product_button.get_node_or_null("NamePrice") as Label
		_ok(name_price != null, "menu product button exposes bounded NamePrice label")
		var tag_row := product_button.get_node_or_null("TagRow") as HBoxContainer
		_ok(tag_row != null, "menu product button exposes colored TagRow")
		if tag_row != null:
			var tag_label := tag_row.get_node_or_null("TagText_0") as Label
			_ok(tag_label != null, "TagRow exposes first colored text tag")
			if tag_label != null:
				var color := tag_label.get_theme_color("font_color")
				_ok(color != ThemeColors.TEXT_LIGHT and color != Color.WHITE,
					"food tag uses semantic text color instead of plain white")
				_ok(tag_label.get_node_or_null("Swatch") == null,
					"food tag avoids boxed color swatches")
		if name_price != null:
			var normal_color := name_price.get_theme_color("font_color")
			product_button.pressed.emit()
			await get_tree().process_frame
			var selected_color := name_price.get_theme_color("font_color")
			_ok(selected_color == ThemeColors.AMBER_PRIMARY,
				"selected menu product highlights the dish name")
			product_button.pressed.emit()
			await get_tree().process_frame
			var deselected_color := name_price.get_theme_color("font_color")
			_ok(deselected_color == normal_color,
				"deselected menu product restores the dish name color")
		var matching_button := _first_menu_product_button_matching_tags(tavern, gm, ["热食", "酒水", "顶饿"])
		_ok(matching_button != null, "menu preparation exposes a product matching active wind tags")
		if matching_button != null:
			matching_button.pressed.emit()
			await get_tree().process_frame
			var reason := tavern.get_node_or_null("MenuPrepPanel/MenuPrepReasonLabel") as Label
			_ok(reason != null and reason.text.contains("命中标签"),
				"selected menu product shows wind-matched tags in the fixed detail area")
			_ok(reason != null and reason.text.contains("风声命中"),
				"selected menu product shows the wind recommendation source")

	tavern.queue_free()
	await get_tree().process_frame


func _first_menu_product_button_matching_tags(tavern: Node, gm: Node, expected_tags: Array[String]) -> Button:
	var product_list := tavern.get_node_or_null("MenuPrepPanel/ProductScroll/ProductList") as VBoxContainer
	if product_list == null or gm == null or gm.appetite == null or gm.craft == null:
		return null
	var products: Array[String] = gm.craft.get_orderable_products(gm.economy.current_day)
	for index in range(products.size()):
		if index >= product_list.get_child_count():
			continue
		var product_key := String(products[index])
		var tags: Array = gm.appetite.get_product_tags(product_key)
		for tag in expected_tags:
			if tags.has(tag):
				return product_list.get_child(index) as Button
	return null


func _test_inventory_drag_handoff() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.add_to_inventory("ale", 1)
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var items := tavern.get_node("BarWorkspace/World/Items")
	_ok(bar.has_method("drop_inventory_item_at"), "BarWorkspace exposes release-time inventory drop")
	if bar.has_method("drop_inventory_item_at"):
		var before: int = gm.inventory_sys.get_count("ale")
		var before_items := _desk_item_count(items)
		tavern._on_inventory_item_dropped("ale", Vector2(640, 620))
		await get_tree().process_frame
		_ok(_desk_item_count(items) == before_items + 1, "inventory release creates a DeskItem")
		_ok(gm.inventory_sys.get_count("ale") == before - 1, "inventory release deducts inventory")
		_ok(not bar._drag_ctrl.is_dragging(), "inventory release leaves DragController idle")

	tavern.queue_free()
	await get_tree().process_frame


func _desk_item_count(items: Node) -> int:
	var count := 0
	if items == null:
		return count
	for child in items.get_children():
		if child is DeskItem:
			count += 1
	return count
