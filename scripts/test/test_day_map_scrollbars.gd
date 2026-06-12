extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var gm = get_node("/root/GameManager")
	gm.start_day_map(gm.economy.current_day)
	for loc in gm.day_map.get_locations():
		gm.day_map.mark_revealed(String(loc.get("id", "")))
	var day_map_scene := preload("res://scenes/ui/DayMap.tscn")
	var view = day_map_scene.instantiate()
	add_child(view)
	await get_tree().process_frame
	_test_daymap_art_assets(view)
	_test_marker_labels_use_pixel_font(view)
	_test_topbar_button_layout(view)
	_test_static_text_uses_pixel_font(view)
	_test_pinned_note_contract(view)
	await _test_pinned_note_stays_on_map_after_camera_moves(view)
	await _test_pinned_note_visibility_paths(view)
	_test_tavern_node(view)
	_test_daymap_primary_button_style(view)
	_test_panel_styles(view)
	view._open_shop()
	await get_tree().process_frame
	_test_shop_overlay_integration(view)
	view._close_shop()
	await get_tree().process_frame
	view.queue_free()
	await get_tree().process_frame
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


func _test_daymap_primary_button_style(view) -> void:
	var button := view.get_node_or_null("UILayer/DetailPanel/GoHereBtn") as Button
	_ok(button != null, "detail action button exists")
	if button == null:
		return
	_ok(button.custom_minimum_size == Vector2(280, 72), "detail action button uses native runtime size")
	var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
	_ok(normal != null and normal.texture != null, "detail action button uses texture style")
	if normal != null and normal.texture != null:
		_ok(String(normal.texture.resource_path).ends_with("assets/textures/daymap/ui/button_primary_normal.png"),
			"detail action button uses DayMap primary normal art")
	var font := button.get_theme_font("font")
	_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"),
		"detail action button uses Fusion Pixel font")


func _test_marker_labels_use_pixel_font(view) -> void:
	var points := view.get_node_or_null("MapWorld/Points") as Node
	_ok(points != null, "marker root exists")
	if points == null:
		return
	var label_count := 0
	for marker in points.get_children():
		var label: Label = null
		for child in marker.get_children():
			if child is Label:
				label = child
				break
		_ok(label != null, "%s has a label" % marker.name)
		if label == null:
			continue
		label_count += 1
		var font := label.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"),
			"%s marker label uses Fusion Pixel font" % marker.name)
		if marker is MapPointMarker and marker._icon != null:
			_ok(marker._hover_ring != null and marker._hover_ring.z_index > marker._icon.z_index,
				"%s hover ring renders above the marker icon" % marker.name)
			_ok(marker._selected_ring != null and marker._selected_ring.z_index > marker._icon.z_index,
				"%s selected ring renders above the marker icon" % marker.name)
	_ok(label_count > 0, "DayMap has marker labels")


func _test_panel_styles(view) -> void:
	var detail := view.get_node_or_null("UILayer/DetailPanel") as Panel
	_ok(detail != null, "detail panel exists")
	if detail != null:
		_ok(detail.size == Vector2(320, 480), "detail panel uses native runtime size")
		var style := detail.get_theme_stylebox("panel") as StyleBoxTexture
		_ok(style != null and style.texture != null, "detail panel uses texture style")
		if style != null and style.texture != null:
			_ok(String(style.texture.resource_path).ends_with("assets/textures/daymap/ui/panel_detail.png"),
				"detail panel uses DayMap detail panel art")
	var result := view.get_node_or_null("UILayer/ResultPanel") as Panel
	_ok(result != null, "result panel exists")
	if result != null:
		var style := result.get_theme_stylebox("panel") as StyleBoxTexture
		_ok(style != null and style.texture != null, "result panel uses texture style")
		if style != null and style.texture != null:
			_ok(String(style.texture.resource_path).ends_with("assets/textures/daymap/ui/panel_result.png"),
				"result panel uses DayMap result panel art")
		var result_label := view.get_node_or_null("UILayer/ResultPanel/ResultLabel") as Label
		_ok(result_label != null, "result panel keeps result body text")
		if result_label != null:
			_ok(result_label.position == Vector2(90, 76), "result body text sits lower in the result panel")
			_ok(result_label.size == Vector2(520, 210), "result body text uses a narrower reading width")


func _test_pinned_note_contract(view) -> void:
	var legacy := view.get_node_or_null("UILayer/DetailPanel") as Panel
	_ok(legacy != null, "legacy detail panel remains available")
	if legacy != null:
		for child_name in ["Name", "Desc", "Cost", "Yield", "GoHereBtn"]:
			_ok(legacy.get_node_or_null(child_name) != null,
				"legacy detail panel keeps %s" % child_name)

	var note := view.get_node_or_null("MapWorld/PinnedNotePanel") as Control
	_ok(note != null, "pinned note panel exists")
	if note == null:
		return
	_ok(note.get_parent() == view.get_node("MapWorld"), "pinned note is placed on the map world")
	_ok(view.get_node_or_null("UILayer/PinnedNotePanel") == null,
		"pinned note is not a fixed screen-space UI layer")
	_ok(note.size == Vector2(368, 384), "pinned note keeps its fixed map-world size")
	for child_name in ["KnifeArt", "NoteArt", "Name", "Desc", "Cost", "Yield", "GoHereBtn"]:
		_ok(note.get_node_or_null(child_name) != null,
			"pinned note keeps %s" % child_name)
	var name_label := note.get_node_or_null("Name") as Label
	var desc_label := note.get_node_or_null("Desc") as Label
	var cost_label := note.get_node_or_null("Cost") as Label
	var yield_label := note.get_node_or_null("Yield") as Label
	_ok(name_label != null and name_label.position == Vector2(148, 96) and name_label.size == Vector2(172, 34),
		"pinned note title avoids the knife art")
	_ok(desc_label != null and desc_label.position == Vector2(128, 142) and desc_label.size == Vector2(196, 76),
		"pinned note description starts on the clear paper area")
	_ok(cost_label != null and cost_label.position == Vector2(120, 224) and cost_label.size == Vector2(212, 26),
		"pinned note cost row stays clear of the knife")
	_ok(yield_label != null and yield_label.position == Vector2(120, 254) and yield_label.size == Vector2(212, 42),
		"pinned note yield row stays clear of the knife")
	var note_art := note.get_node_or_null("NoteArt") as TextureRect
	_ok(note_art != null and note_art.texture != null,
		"pinned note has paper art")
	if note_art != null and note_art.texture != null:
		_ok(String(note_art.texture.resource_path).ends_with("assets/textures/daymap/ui/pinned_note_panel.png"),
			"pinned note uses DayMap note paper art")
	var knife_art := note.get_node_or_null("KnifeArt") as TextureRect
	_ok(knife_art != null and knife_art.texture != null,
		"pinned note has knife art")
	if knife_art != null and knife_art.texture != null:
		_ok(String(knife_art.texture.resource_path).ends_with("assets/textures/daymap/ui/pinned_note_knife.png"),
			"pinned note uses DayMap knife art")
	var action := note.get_node_or_null("GoHereBtn") as Button
	_ok(action != null and action.size == Vector2(224, 56),
		"pinned note action button uses smaller note action size")
	if action != null:
		_ok(action.position == Vector2(72, 304),
			"pinned note action button sits centered below the note copy")
		var normal := action.get_theme_stylebox("normal") as StyleBoxTexture
		var hover := action.get_theme_stylebox("hover") as StyleBoxTexture
		var pressed := action.get_theme_stylebox("pressed") as StyleBoxTexture
		_ok(normal != null and normal.texture != null,
			"pinned note action button uses texture style")
		if normal != null and normal.texture != null:
			_ok(String(normal.texture.resource_path).ends_with("assets/textures/daymap/ui/button_note_action_normal.png"),
				"pinned note action button uses wax-seal normal art")
		if hover != null and hover.texture != null:
			_ok(String(hover.texture.resource_path).ends_with("assets/textures/daymap/ui/button_note_action_hover.png"),
				"pinned note action button uses wax-seal hover art")
		if pressed != null and pressed.texture != null:
			_ok(String(pressed.texture.resource_path).ends_with("assets/textures/daymap/ui/button_note_action_pressed.png"),
				"pinned note action button uses wax-seal pressed art")
		_ok(action.pressed.is_connected(Callable(view, "_on_go_here_pressed")),
			"pinned note action routes through the existing DayMap action handler")


func _test_pinned_note_stays_on_map_after_camera_moves(view) -> void:
	view._ensure_home_marker()
	view._select_marker("__home__")
	await get_tree().process_frame
	var note := view.get_node_or_null("MapWorld/PinnedNotePanel") as Control
	_ok(note != null, "pinned note exists before tracking test")
	if note == null:
		return
	_ok(note.visible, "selecting a marker shows the pinned note")
	var initial_size := note.size
	var initial_position := note.position
	var initial_screen_position: Vector2 = note.get_global_transform_with_canvas().origin
	var initial_screen_scale: Vector2 = note.get_global_transform_with_canvas().get_scale()
	var original_camera_position: Vector2 = view._camera.position
	var original_camera_zoom: Vector2 = view._camera.zoom
	var expected_position: Vector2 = view._home_marker.position + Vector2(44, -132)
	_ok(note.position == expected_position,
		"pinned note is pasted beside the marker in map coordinates")

	view._camera.zoom = Vector2(1.35, 1.35)
	view._camera.position = view._home_marker.global_position + Vector2(140, 0)
	await get_tree().process_frame

	_ok(note.size == initial_size, "pinned note map-world size does not change with camera zoom")
	_ok(note.position == initial_position,
		"pinned note map-world position does not change after camera movement")
	_ok(note.get_global_transform_with_canvas().origin != initial_screen_position,
		"pinned note screen position changes with the map camera")
	_ok(note.get_global_transform_with_canvas().get_scale() != initial_screen_scale,
		"pinned note scales on screen with the map camera")
	view._show_detail("__home__")
	await get_tree().process_frame
	_ok(note.position == initial_position,
		"refreshing selected marker detail does not move the map-pasted note")
	view._camera.position = original_camera_position
	view._camera.zoom = original_camera_zoom


func _test_pinned_note_visibility_paths(view) -> void:
	view._ensure_home_marker()
	view._select_marker("__home__")
	await get_tree().process_frame
	var note := view.get_node_or_null("MapWorld/PinnedNotePanel") as Control
	_ok(note != null and note.visible, "pinned note is visible after selecting home")
	if note == null:
		return

	view._clear_selection()
	await get_tree().process_frame
	_ok(not note.visible, "clearing selection hides the pinned note")

	view._select_marker("__home__")
	await get_tree().process_frame
	view._open_shop()
	await get_tree().process_frame
	_ok(not note.visible, "opening shop hides the pinned note")
	view._close_shop()
	await get_tree().process_frame


func _test_shop_overlay_integration(view) -> void:
	var overlay := view.get_node_or_null("UILayer/ShopOverlay") as ShopOverlay
	_ok(overlay != null, "DayMap uses ShopOverlay scene")
	if overlay == null:
		return
	_ok(overlay.visible, "ShopOverlay is visible while shop is open")
	_ok(not view.get_node("MapWorld").visible, "map world hides while shop overlay is open")
	_ok(overlay.get_node_or_null("ItemList") is Control, "ShopOverlay exposes item list")
	_ok(overlay.get_node_or_null("DetailPanel/Title") is Label, "ShopOverlay exposes selected item detail")
	_ok(overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") is Button, "ShopOverlay exposes purchase input zone")
	_ok(overlay.get_node_or_null("CategoryTabs/MaterialsZone") is Button, "ShopOverlay exposes materials tab input zone")


func _test_topbar_button_layout(view) -> void:
	var strip := view.get_node_or_null("UILayer/TopBar/TopStrip") as TextureRect
	_ok(strip != null, "topbar has DayMap material strip")
	if strip != null:
		_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "topbar material strip does not eat map clicks")
		_ok(strip.position == Vector2.ZERO and strip.size == Vector2(1280, 60), "topbar material strip covers the status row")
		_ok(strip.texture != null and String(strip.texture.resource_path).ends_with("assets/textures/daymap/ui/topbar_strip.png"),
			"topbar material strip uses DayMap native texture")
	var day_label := view.get_node_or_null("UILayer/TopBar/DayLabel") as Label
	_ok(day_label != null, "topbar keeps day label")
	if day_label != null:
		_ok(day_label.position == Vector2(72, 10), "day label clears the left corner ornament")
		_ok(day_label.size == Vector2(300, 40), "day label keeps enough room after moving inward")
	var stamina_label := view.get_node_or_null("UILayer/TopBar/StaminaLabel") as Label
	_ok(stamina_label != null, "topbar keeps stamina label")
	if stamina_label != null:
		_ok(stamina_label.position == Vector2(420, 10), "stamina label follows the safer topbar text lane")
	var gold_label := view.get_node_or_null("UILayer/TopBar/GoldLabel") as Label
	_ok(gold_label != null, "topbar keeps gold label")
	if gold_label != null:
		_ok(gold_label.position == Vector2(610, 10), "gold label follows the safer topbar text lane")
	var documents := view.get_node_or_null("UILayer/TopBar/DocumentsBtn") as Button
	_ok(documents != null, "topbar keeps ledger button")
	if documents != null:
		_ok(documents.position == Vector2(1060, 8), "ledger button clears the right corner ornament")
		_ok(documents.size == Vector2(132, 44), "ledger button uses the former experimental button size")
		var normal := documents.get_theme_stylebox("normal") as StyleBoxTexture
		_ok(normal != null and normal.texture != null, "ledger button uses texture style")
		if normal != null and normal.texture != null:
			_ok(String(normal.texture.resource_path).ends_with("assets/textures/daymap/ui/button_ledger_normal.png"),
				"ledger button uses DayMap ledger art")
		var font := documents.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"),
			"ledger button uses Fusion Pixel font")
	_ok(view.get_node_or_null("UILayer/TopBar/ExpTavernBtn") == null,
		"experimental tavern button is removed from DayMap topbar")
	var detail_name := view.get_node_or_null("UILayer/DetailPanel/Name") as Label
	_ok(detail_name != null, "detail panel keeps location title")
	if detail_name != null:
		_ok(detail_name.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"detail panel title is centered")
		_ok(detail_name.position.x == 36.0 and detail_name.size.x == 248.0,
			"detail panel title keeps clear ornament padding")
	var detail_desc := view.get_node_or_null("UILayer/DetailPanel/Desc") as Label
	_ok(detail_desc != null, "detail panel keeps location body")
	if detail_desc != null:
		_ok(detail_desc.position.x == 58.0 and detail_desc.size.x == 204.0,
			"detail panel body uses a narrower reading column")
	var detail_yield := view.get_node_or_null("UILayer/DetailPanel/Yield") as Label
	_ok(detail_yield != null, "detail panel keeps yield body")
	if detail_yield != null:
		_ok(detail_yield.position.x == 58.0 and detail_yield.size.x == 204.0,
			"detail panel yield text matches the narrower reading column")


func _test_static_text_uses_pixel_font(view) -> void:
	var paths := [
		"UILayer/TopBar/DayLabel",
		"UILayer/TopBar/StaminaLabel",
		"UILayer/TopBar/GoldLabel",
		"UILayer/DetailPanel/Name",
		"UILayer/DetailPanel/Desc",
		"UILayer/DetailPanel/Cost",
		"UILayer/DetailPanel/Yield",
		"MapWorld/PinnedNotePanel/Name",
		"MapWorld/PinnedNotePanel/Desc",
		"MapWorld/PinnedNotePanel/Cost",
		"MapWorld/PinnedNotePanel/Yield",
		"UILayer/ResultPanel/ResultLabel",
	]
	for path in paths:
		var label := view.get_node_or_null(path) as Label
		_ok(label != null, "%s exists" % path)
		if label == null:
			continue
		var font := label.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"),
			"%s uses Fusion Pixel font" % path)


func _test_tavern_node(view) -> void:
	_ok(view._home_marker != null and is_instance_valid(view._home_marker),
		"tavern home marker exists")
	_ok(view._home_marker.location_id == "__home__",
		"home marker uses sentinel id")
	_ok(view.get_node_or_null("UILayer/GoButton") == null,
		"GoButton removed in favor of tavern node")
	view._select_marker("__home__")
	var note := view.get_node_or_null("MapWorld/PinnedNotePanel") as Control
	_ok(note != null and note.visible,
		"selecting tavern shows the pinned note")
	_ok(view._detail_panel != null and not view._detail_panel.visible,
		"legacy detail panel stays hidden while pinned note is the visible detail UI")
	if note != null:
		var action := note.get_node_or_null("GoHereBtn") as Button
		_ok(action != null, "pinned note keeps tavern action button")
		if action != null:
			_ok(action.text != "", "selecting tavern gives the pinned note an action")


func _test_daymap_art_assets(view) -> void:
	var background = view.get_node_or_null("MapWorld/Background")
	_ok(background is Sprite2D and background.texture != null,
		"DayMap uses one full-map background texture")
	if background is Sprite2D and background.texture != null:
		_ok(String(background.texture.resource_path).ends_with("assets/textures/daymap/daymap_full.png"),
			"DayMap background uses daymap_full.png")
		_ok(background.position == Vector2(1280, 720),
			"DayMap full background is centered in the 2560x1440 map world")

	var region_tile_count := 0
	for child in view.get_node("MapWorld").get_children():
		if String(child.name).begins_with("RegionTile_"):
			region_tile_count += 1
	_ok(region_tile_count == 0,
		"DayMap does not spawn region background tiles")

	_ok(view._camera.map_max == Vector2(2560, 1440),
		"camera map_max is the full 2560x1440 map")
	_ok(absf(view._camera.min_zoom - 0.5) < 0.01,
		"camera can zoom out to show the full map")
	_ok(view._home_marker != null and is_instance_valid(view._home_marker),
		"home marker exists")
	if view._home_marker != null and is_instance_valid(view._home_marker):
		_ok(view._home_marker.position == Vector2(760, 845),
			"home marker uses the v2 tavern anchor on the full map")
		_ok(view._home_marker.position.x >= 0.0 and view._home_marker.position.x <= 2560.0
				and view._home_marker.position.y >= 0.0 and view._home_marker.position.y <= 1440.0,
			"home marker is inside the map bounds")
		if view._home_marker.has_method("has_icon_texture"):
			_ok(view._home_marker.has_icon_texture(), "home marker has an icon texture")
