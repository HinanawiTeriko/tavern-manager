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
	_test_gather_tutorial_targets_stamina_label(view)
	_test_gathering_toast_contract(view)
	_test_static_text_uses_pixel_font(view)
	_test_pinned_note_contract(view)
	await _test_pinned_note_stays_on_map_after_camera_moves(view)
	await _test_pinned_note_visibility_paths(view)
	_test_tavern_node(view)
	_test_daymap_primary_button_style(view)
	_test_panel_styles(view)
	await _test_gathering_toast_replaces_normal_gather_result(view)
	await _test_rumor_visit_shows_top_toast(view)
	view._open_shop()
	await get_tree().process_frame
	_test_shop_overlay_integration(view)
	view._close_shop()
	await get_tree().process_frame
	await _test_fixer_visit_refreshes_gold_label(view)
	view.queue_free()
	await get_tree().process_frame
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DAYMAP-SCROLLBARS] FAIL: " + msg)


func _color_close(actual: Color, expected: Color, epsilon: float = 0.002) -> bool:
	return (
		absf(actual.r - expected.r) <= epsilon
		and absf(actual.g - expected.g) <= epsilon
		and absf(actual.b - expected.b) <= epsilon
		and absf(actual.a - expected.a) <= epsilon
	)


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
	_ok(button.custom_minimum_size == Vector2(224, 56), "detail action button uses pinned-notice runtime size")
	_ok(button.size == Vector2(224, 56), "detail action button does not resize between states")
	_ok(button.position == Vector2(48, 392), "detail action button sits inside the lower paper tag safe area")
	var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
	var hover := button.get_theme_stylebox("hover") as StyleBoxTexture
	var pressed := button.get_theme_stylebox("pressed") as StyleBoxTexture
	_ok(normal != null and normal.texture != null, "detail action button uses texture style")
	if normal != null and normal.texture != null:
		_ok(String(normal.texture.resource_path).ends_with("assets/textures/daymap/ui/button_detail_go_normal.png"),
			"detail action button uses dedicated pinned-notice normal art")
		_ok(is_equal_approx(normal.get_content_margin(SIDE_LEFT), normal.get_content_margin(SIDE_RIGHT)),
			"detail action button keeps text centered with symmetric horizontal margins")
		_ok(is_equal_approx(normal.get_content_margin(SIDE_TOP), normal.get_content_margin(SIDE_BOTTOM)),
			"detail action button keeps text vertically centered with symmetric vertical margins")
	if hover != null and hover.texture != null:
		_ok(String(hover.texture.resource_path).ends_with("assets/textures/daymap/ui/button_detail_go_hover.png"),
			"detail action button uses dedicated pinned-notice hover art")
	if pressed != null and pressed.texture != null:
		_ok(String(pressed.texture.resource_path).ends_with("assets/textures/daymap/ui/button_detail_go_pressed.png"),
			"detail action button uses dedicated pinned-notice pressed art")
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
			_ok(result_label.position == Vector2(96, 88), "result body text sits inside the special result notice safe area")
			_ok(result_label.size == Vector2(508, 184), "result body text leaves room for the bottom button seat")
		var continue_btn := view.get_node_or_null("UILayer/ResultPanel/ContinueBtn") as Button
		_ok(continue_btn != null, "result panel keeps continue button")
		if continue_btn != null:
			_ok(continue_btn.position == Vector2(210, 304), "continue button sits on the bottom button seat")
			_ok(continue_btn.size == Vector2(280, 72), "continue button keeps the DayMap primary button size")


func _test_gathering_toast_contract(view) -> void:
	var toast := view.get_node_or_null("UILayer/GatheringToast") as GatheringToast
	_ok(toast != null, "DayMap has a top gathering toast")
	if toast == null:
		return
	_ok(toast.position == Vector2(430, 68), "gathering toast sits at the top center of the screen")
	_ok(toast.size == Vector2(480, 78), "gathering toast uses the DayMap art panel size")
	_ok(toast.mouse_filter == Control.MOUSE_FILTER_IGNORE, "gathering toast never blocks map clicks")
	var content := toast.get_node_or_null("Content") as Label
	_ok(content != null, "gathering toast keeps a content label")
	if content != null:
		var font := content.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"),
			"gathering toast content uses Fusion Pixel font")
		toast.show_rewards({"herb": 1}, "风声 · 今晚菜单有新线索")
		_ok(content.text.contains("风声"),
			"gathering toast can mention compact wind alongside gathered rewards")
		_ok(content.text.split("\n").size() <= 2,
			"gathering toast keeps rewards and wind within two compact lines")
		toast.visible = false
	var style := toast.get_theme_stylebox("panel") as StyleBoxTexture
	_ok(style != null and style.texture != null, "gathering toast uses texture panel art")
	if style != null and style.texture != null:
		_ok(String(style.texture.resource_path).ends_with("assets/textures/daymap/ui/gathering_toast_panel.png"),
			"gathering toast uses DayMap gathering toast art")


func _test_gathering_toast_replaces_normal_gather_result(view) -> void:
	var gm = get_node("/root/GameManager")
	if gm.rumors != null:
		gm.rumors.restore_state({
			"current_day": int(gm.economy.current_day),
			"heard_ids": ["mushroom_forest_clear_scent"],
			"today_ids": [],
		})
	view._visit_location("mushroom_forest")
	await get_tree().process_frame
	var result := view.get_node_or_null("UILayer/ResultPanel") as Panel
	_ok(result != null and not result.visible,
		"normal gathering reward does not open the blocking result panel")
	var toast := view.get_node_or_null("UILayer/GatheringToast") as GatheringToast
	_ok(toast != null and toast.visible,
		"normal gathering reward shows the top gathering toast")
	if toast == null:
		return
	var content := toast.get_node_or_null("Content") as Label
	_ok(content != null and content.text.begins_with("采集获得："),
		"gathering toast announces collected rewards")
	_ok(content != null and content.text.contains("×"),
		"gathering toast includes the collected item count")


func _test_rumor_visit_shows_top_toast(view) -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 2
	gm.narrative.set_var("ryan_warhammer_lead", true)
	gm.start_day_map(2)
	view.show_day(2, EconomySystem.MAX_DAYS)
	await get_tree().process_frame
	view._visit_location("mercenary_board")
	await get_tree().process_frame
	var result := view.get_node_or_null("UILayer/ResultPanel") as Panel
	_ok(result != null and not result.visible,
		"rumor visit does not rely on the blocking result panel for feedback")
	var toast := view.get_node_or_null("UILayer/GatheringToast") as GatheringToast
	_ok(toast != null and not toast.visible,
		"rumor visit hides the compact gathering toast")
	var notice := view.get_node_or_null("UILayer/WindNotice") as Control
	_ok(notice != null and notice.visible,
		"rumor visit shows the wind notice")
	if notice == null:
		return
	var body := notice.get_node_or_null("Body") as Label
	_ok(body != null and body.text.strip_edges() != "",
		"wind notice shows the heard rumor text")
	var rewards := notice.get_node_or_null("Rewards") as Label
	_ok(rewards != null,
		"wind notice keeps a rewards label for gathered reward locations")


func _test_fixer_visit_refreshes_gold_label(view) -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 6
	gm.economy.add_gold(50)
	gm.narrative.set_var("toby_identity_known", true)
	gm.narrative.set_var("toby_danger_known", true)
	gm.narrative.set_var("toby_commission_lead", true)
	gm.start_day_map(6)
	view.show_day(6, EconomySystem.MAX_DAYS)
	await get_tree().process_frame
	var gold_label := view.get_node_or_null("UILayer/TopBar/GoldLabel") as Label
	_ok(gold_label != null and gold_label.text.contains("50"), "DayMap gold label starts from current economy gold")
	view._visit_location("fixer_den")
	await get_tree().process_frame
	_ok(gm.economy.gold == 10, "fixer visit spends 40 gold through GameManager")
	_ok(gold_label != null and gold_label.text.contains("10") and not gold_label.text.contains("50"),
		"DayMap gold label refreshes after fixer spending")


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
	_ok(note.size == Vector2(368, 384), "pinned note uses the map-pinned notice size")
	for child_name in ["KnifeArt", "NoteArt", "Name", "Desc", "Cost", "Yield", "GoHereBtn"]:
		_ok(note.get_node_or_null(child_name) != null,
			"pinned note keeps %s" % child_name)
	var name_label := note.get_node_or_null("Name") as Label
	var desc_label := note.get_node_or_null("Desc") as Label
	var cost_label := note.get_node_or_null("Cost") as Label
	var yield_label := note.get_node_or_null("Yield") as Label
	_ok(name_label != null and name_label.position == Vector2(76, 72) and name_label.size == Vector2(220, 34),
		"pinned note title is shifted two title characters left inside the top title safe area")
	_ok(desc_label != null and desc_label.position == Vector2(92, 126) and desc_label.size == Vector2(224, 88),
		"pinned note description uses the central paper text safe area")
	_ok(cost_label != null and cost_label.position == Vector2(92, 224) and cost_label.size == Vector2(224, 26),
		"pinned note cost row leaves air below the description")
	_ok(yield_label != null and yield_label.position == Vector2(92, 254) and yield_label.size == Vector2(224, 40),
		"pinned note yield text ends above the lower action button")
	if name_label != null:
		_ok(is_equal_approx(name_label.position.x + name_label.size.x * 0.5, 186.0),
			"pinned note title center is shifted two title characters left of the old centerline")
	if name_label != null:
		_ok(_color_close(name_label.get_theme_color("font_color"), Color(0.36, 0.20, 0.10)),
			"pinned note title uses dark paper-ink color instead of bright UI amber")
		_ok(name_label.get_theme_font_size("font_size") == 18,
			"pinned note title uses a quieter handwritten-paper size")
		_ok(name_label.get_theme_constant("outline_size") == 1,
			"pinned note title keeps only a weak ink edge")
		_ok(_color_close(name_label.get_theme_color("font_outline_color"), Color(0.05, 0.03, 0.02, 0.16)),
			"pinned note title outline is a faint ink bleed, not black UI stroke")
	for body_label in [desc_label, cost_label, yield_label]:
		if body_label != null:
			_ok(_color_close(body_label.get_theme_color("font_color"), Color(0.27, 0.19, 0.12)),
				"pinned note body text uses paper-ink color")
			_ok(body_label.get_theme_font_size("font_size") == 14,
				"pinned note body text is slightly smaller than panel UI text")
			_ok(body_label.get_theme_constant("outline_size") == 0,
				"pinned note body text does not use black UI outline")
	var note_art := note.get_node_or_null("NoteArt") as TextureRect
	_ok(note_art != null and note_art.texture != null,
		"pinned note has paper art")
	if note_art != null and note_art.texture != null:
		_ok(String(note_art.texture.resource_path).ends_with("assets/textures/daymap/ui/pinned_note_detail_panel.png"),
			"pinned note uses DayMap pinned location detail art")
	var knife_art := note.get_node_or_null("KnifeArt") as TextureRect
	_ok(knife_art != null and knife_art.texture != null,
		"pinned note has knife art")
	if knife_art != null and knife_art.texture != null:
		_ok(String(knife_art.texture.resource_path).ends_with("assets/textures/daymap/ui/pinned_note_knife.png"),
			"pinned note uses DayMap knife art")
	var action := note.get_node_or_null("GoHereBtn") as Button
	_ok(action != null and action.size == Vector2(224, 56),
		"pinned note action button uses detail go action size")
	if action != null:
		_ok(action.position == Vector2(72, 284),
			"pinned note action button sits slightly higher in the lower paper tag safe area")
		_ok(action.alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"pinned note action button centers its text horizontally")
		var normal := action.get_theme_stylebox("normal") as StyleBoxTexture
		var hover := action.get_theme_stylebox("hover") as StyleBoxTexture
		var pressed := action.get_theme_stylebox("pressed") as StyleBoxTexture
		_ok(normal != null and normal.texture != null,
			"pinned note action button uses texture style")
		if normal != null and normal.texture != null:
			_ok(String(normal.texture.resource_path).ends_with("assets/textures/daymap/ui/button_detail_go_normal.png"),
				"pinned note action button uses pinned-notice normal art")
			_ok(is_equal_approx(normal.get_content_margin(SIDE_LEFT), normal.get_content_margin(SIDE_RIGHT)),
				"pinned note action button keeps text centered with symmetric horizontal margins")
			_ok(is_equal_approx(normal.get_content_margin(SIDE_TOP), normal.get_content_margin(SIDE_BOTTOM)),
				"pinned note action button keeps text vertically centered with symmetric vertical margins")
		if hover != null and hover.texture != null:
			_ok(String(hover.texture.resource_path).ends_with("assets/textures/daymap/ui/button_detail_go_hover.png"),
				"pinned note action button uses pinned-notice hover art")
		if pressed != null and pressed.texture != null:
			_ok(String(pressed.texture.resource_path).ends_with("assets/textures/daymap/ui/button_detail_go_pressed.png"),
				"pinned note action button uses pinned-notice pressed art")
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
		_ok(day_label.position == Vector2(132, 1), "day label is balanced inside the left parchment field")
		_ok(day_label.size == Vector2(320, 40), "day label stays inside the left parchment field")
		_ok(day_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "day label is centered on its parchment field")
	var stamina_label := view.get_node_or_null("UILayer/TopBar/StaminaLabel") as Label
	_ok(stamina_label != null, "topbar keeps stamina label")
	if stamina_label != null:
		_ok(stamina_label.position == Vector2(636, 1), "stamina label is balanced inside the center parchment field")
		_ok(stamina_label.size == Vector2(128, 40), "stamina label fits the center parchment field")
		_ok(stamina_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "stamina label is centered on its parchment field")
	var gold_label := view.get_node_or_null("UILayer/TopBar/GoldLabel") as Label
	_ok(gold_label != null, "topbar keeps gold label")
	if gold_label != null:
		_ok(gold_label.position == Vector2(904, 1), "gold label is balanced inside the right parchment field")
		_ok(gold_label.size == Vector2(116, 40), "gold label fits the right parchment field")
		_ok(gold_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "gold label is centered on its parchment field")
	var documents := view.get_node_or_null("UILayer/TopBar/DocumentsBtn") as Button
	_ok(documents != null, "topbar exposes the ledger button node")
	if documents != null:
		_ok(documents.visible, "ledger button is visible on the DayMap topbar")
		_ok(not documents.disabled, "ledger button can be activated from DayMap")
		_ok(documents.mouse_filter == Control.MOUSE_FILTER_STOP, "ledger button receives click input")
		_ok(documents.text == "", "ledger button is icon-only without the text label")
		_ok(documents.position == Vector2(1092, 8) and documents.size == Vector2(132, 44),
			"ledger button sits in the topbar right action slot")
		var normal := documents.get_theme_stylebox("normal") as StyleBoxTexture
		_ok(normal != null and normal.texture != null, "ledger button keeps texture style")
		if normal != null and normal.texture != null:
			_ok(String(normal.texture.resource_path).ends_with("assets/textures/daymap/ui/button_ledger_normal.png"),
				"ledger button uses DayMap ledger art")
		var font := documents.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"),
			"ledger button uses Fusion Pixel font")
		_ok(view.has_method("_refresh_ledger_hint"), "DayMap can refresh the ledger unread prompt")
		var gm = get_node("/root/GameManager")
		_ok(gm.documents.has_method("has_unread_ledger_entries"), "DocumentSystem exposes unread ledger state to DayMap")
		if view.has_method("_refresh_ledger_hint") and gm.documents.has_method("has_unread_ledger_entries"):
			gm.documents.add_ledger_entry_once("测试宿命：账本新页。")
			view._refresh_ledger_hint()
			var unread_normal := documents.get_theme_stylebox("normal") as StyleBoxTexture
			var unread_hover := documents.get_theme_stylebox("hover") as StyleBoxTexture
			var unread_pressed := documents.get_theme_stylebox("pressed") as StyleBoxTexture
			_ok(unread_normal != null and unread_normal.texture != null
					and String(unread_normal.texture.resource_path).ends_with("assets/textures/daymap/ui/button_ledger_unread_normal.png"),
				"unread DayMap ledger button uses the prompt-state normal art")
			_ok(unread_hover != null and unread_hover.texture != null
					and String(unread_hover.texture.resource_path).ends_with("assets/textures/daymap/ui/button_ledger_unread_hover.png"),
				"unread DayMap ledger button uses the prompt-state hover art")
			_ok(unread_pressed != null and unread_pressed.texture != null
					and String(unread_pressed.texture.resource_path).ends_with("assets/textures/daymap/ui/button_ledger_unread_pressed.png"),
				"unread DayMap ledger button uses the prompt-state pressed art")
			_ok(view.get_node_or_null("UILayer/TopBar/LedgerUnreadHint") == null,
				"DayMap ledger prompt is authored into the button art instead of a text label")
		documents.pressed.emit()
		var document_overlay := view.get_node_or_null("UILayer/DocumentOverlay") as DocumentOverlay
		_ok(document_overlay != null and document_overlay.visible,
			"pressing DayMap ledger button opens the ledger overlay")
		if document_overlay != null:
			_ok(document_overlay.get_current_page_text() != "",
				"DayMap ledger button opens the actual ledger document")
			var read_normal := documents.get_theme_stylebox("normal") as StyleBoxTexture
			_ok(read_normal != null and read_normal.texture != null
					and String(read_normal.texture.resource_path).ends_with("assets/textures/daymap/ui/button_ledger_normal.png"),
				"opening the DayMap ledger restores the normal ledger button art")
			document_overlay.close()
	_ok(view.get_node_or_null("UILayer/TopBar/ExpTavernBtn") == null,
		"experimental tavern button is removed from DayMap topbar")
	var detail_name := view.get_node_or_null("UILayer/DetailPanel/Name") as Label
	_ok(detail_name != null, "detail panel keeps location title")
	if detail_name != null:
		_ok(detail_name.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"detail panel title is centered")
		_ok(detail_name.position == Vector2(72, 42) and detail_name.size == Vector2(196, 38),
			"detail panel title avoids the knife and stays inside the top title safe area")
	var detail_desc := view.get_node_or_null("UILayer/DetailPanel/Desc") as Label
	_ok(detail_desc != null, "detail panel keeps location body")
	if detail_desc != null:
		_ok(detail_desc.position == Vector2(58, 112) and detail_desc.size == Vector2(204, 132),
			"detail panel body uses the central paper text safe area")
	var detail_cost := view.get_node_or_null("UILayer/DetailPanel/Cost") as Label
	_ok(detail_cost != null, "detail panel keeps travel cost")
	if detail_cost != null:
		_ok(detail_cost.position == Vector2(58, 272) and detail_cost.size == Vector2(204, 32),
			"detail panel cost row leaves air below the description")
	var detail_yield := view.get_node_or_null("UILayer/DetailPanel/Yield") as Label
	_ok(detail_yield != null, "detail panel keeps yield body")
	if detail_yield != null:
		_ok(detail_yield.position == Vector2(58, 316) and detail_yield.size == Vector2(204, 56),
			"detail panel yield text ends above the lower action button")


func _test_gather_tutorial_targets_stamina_label(view) -> void:
	_ok(view.has_method("_gather_tutorial_rects"), "DayMap exposes gather tutorial rect builder")
	if not view.has_method("_gather_tutorial_rects"):
		return
	var rects: Dictionary = view._gather_tutorial_rects()
	var stamina_label := view.get_node_or_null("UILayer/TopBar/StaminaLabel") as Label
	_ok(stamina_label != null, "stamina label exists for tutorial target")
	_ok(rects.has("TopBar"), "gather tutorial keeps TopBar contract key")
	if stamina_label == null or not rects.has("TopBar"):
		return
	var stamina_rect := stamina_label.get_global_rect()
	var tutorial_rect: Array = rects["TopBar"]
	_ok(tutorial_rect.size() == 4, "TopBar tutorial rect has x/y/w/h")
	if tutorial_rect.size() < 4:
		return
	_ok(is_equal_approx(float(tutorial_rect[0]), stamina_rect.position.x), "gather tutorial highlights stamina label x")
	_ok(is_equal_approx(float(tutorial_rect[1]), stamina_rect.position.y), "gather tutorial highlights stamina label y")
	_ok(is_equal_approx(float(tutorial_rect[2]), stamina_rect.size.x), "gather tutorial highlights stamina label width")
	_ok(is_equal_approx(float(tutorial_rect[3]), stamina_rect.size.y), "gather tutorial highlights stamina label height")


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
