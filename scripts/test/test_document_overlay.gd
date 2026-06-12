extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var day_map_scene := preload("res://scenes/ui/DayMap.tscn")
	var view = day_map_scene.instantiate()
	add_child(view)
	await get_tree().process_frame
	_test_overlay_uses_ledger_art(view.get_node("UILayer/DocumentOverlay"))
	_test_toby_contract_document_art(view.get_node("UILayer/DocumentOverlay"))
	_test_document_buttons(view.get_node("UILayer/DocumentOverlay"))
	_test_ledger_buttons(view.get_node("UILayer/DocumentOverlay"))
	view.queue_free()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DOCUMENT-OVERLAY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DOCUMENT-OVERLAY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DOCUMENT-OVERLAY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_overlay_uses_ledger_art(overlay: DocumentOverlay) -> void:
	var backdrop := overlay.get_node_or_null("LedgerBackdrop") as TextureRect
	_ok(backdrop != null, "document overlay has a ledger backdrop texture")
	if backdrop != null:
		_ok(backdrop.position == Vector2.ZERO and backdrop.size == Vector2(1280, 720),
			"ledger backdrop covers the full document overlay")
		_ok(backdrop.texture != null and String(backdrop.texture.resource_path).ends_with("assets/textures/ledger/ui/ledger_overlay_backdrop.png"),
			"document overlay uses the ledger close-up backdrop art")
	var panel := overlay.get_node("Panel") as Panel
	var panel_style := panel.get_theme_stylebox("panel")
	_ok(panel.position == Vector2.ZERO and panel.size == Vector2(1280, 720),
		"document overlay controls are laid out over the full ledger art")
	_ok(panel_style == null or panel_style is StyleBoxEmpty,
		"document overlay does not layer the old DayMap document panel over ledger art")
	var labels := [
		overlay.get_node("Panel/Title") as Label,
		overlay.get_node("Panel/LeftBody") as Label,
		overlay.get_node("Panel/RightBody") as Label,
		overlay.get_node("Panel/PageLabel") as Label,
	]
	for label in labels:
		var font: Font = label.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"),
			"%s uses Fusion Pixel font" % label.name)
	var left_body := overlay.get_node("Panel/LeftBody") as Label
	var right_body := overlay.get_node("Panel/RightBody") as Label
	_ok(left_body.position == Vector2(280, 120) and left_body.size == Vector2(256, 368),
		"ledger left page text is inset by two more characters from the page edges")
	_ok(right_body.position == Vector2(744, 120) and right_body.size == Vector2(256, 368),
		"ledger right page text is inset by two more characters from the page edges")
	_ok(left_body.get_theme_color("font_color") == Color(0.16, 0.105, 0.062, 1),
		"ledger body text uses dark ink on parchment")
	var expected_button_art := {
		"Panel/PreviousBtn": {
			"normal": "assets/textures/ledger/ui/button_nav_left_normal.png",
			"hover": "assets/textures/ledger/ui/button_nav_left_hover.png",
			"pressed": "assets/textures/ledger/ui/button_nav_left_pressed.png",
		},
		"Panel/NextBtn": {
			"normal": "assets/textures/ledger/ui/button_nav_right_normal.png",
			"hover": "assets/textures/ledger/ui/button_nav_right_hover.png",
			"pressed": "assets/textures/ledger/ui/button_nav_right_pressed.png",
		},
		"Panel/CloseBtn": {
			"normal": "assets/textures/ledger/ui/button_close_normal.png",
			"hover": "assets/textures/ledger/ui/button_close_hover.png",
			"pressed": "assets/textures/ledger/ui/button_close_pressed.png",
		},
	}
	for path in expected_button_art.keys():
		var button := overlay.get_node(path) as Button
		for state in ["normal", "hover", "pressed"]:
			var style := button.get_theme_stylebox(state) as StyleBoxTexture
			_ok(style != null and style.texture != null, "%s uses %s texture art" % [path, state])
			if style != null and style.texture != null:
				_ok(String(style.texture.resource_path).ends_with(expected_button_art[path][state]),
					"%s uses ledger %s button art" % [path, state])
		var font: Font = button.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"),
			"%s uses Fusion Pixel font" % path)
	var title := overlay.get_node("Panel/Title") as Label
	var page_label := overlay.get_node("Panel/PageLabel") as Label
	var previous := overlay.get_node("Panel/PreviousBtn") as Button
	var next := overlay.get_node("Panel/NextBtn") as Button
	var close := overlay.get_node("Panel/CloseBtn") as Button
	_ok(title.position == Vector2(520, 608) and title.size == Vector2(240, 36),
		"ledger title sits on the bottom name plate instead of the book spine")
	_ok(page_label.position == Vector2(560, 552) and page_label.size == Vector2(160, 28),
		"ledger page label sits in the lower center gutter without covering body text")
	_ok(previous.position == Vector2(96, 300) and previous.size == Vector2(112, 120),
		"ledger previous control is a left page tab")
	_ok(next.position == Vector2(1072, 300) and next.size == Vector2(112, 120),
		"ledger next control is a right page tab")
	_ok(close.position == Vector2(1100, 62) and close.size == Vector2(96, 96),
		"ledger close control is an upper wax-seal button")
	_ok(close.text == "", "ledger close control is icon-only; no baked or mojibake label")


func _test_toby_contract_document_art(overlay: DocumentOverlay) -> void:
	overlay.open_document({
		"id": "toby_contract",
		"kind": "evidence",
		"title": "Toby Contract",
		"pages": ["completed contract page"],
	})
	var art := overlay.get_node_or_null("DocumentArt") as TextureRect
	_ok(art != null, "Toby contract overlay creates a dedicated document art layer")
	if art != null:
		_ok(art.visible, "Toby contract document art is visible for the completed contract")
		_ok(art.position == Vector2(240, 70) and art.size == Vector2(800, 560),
			"Toby contract document art is centered as an 800x560 runtime sheet")
		_ok(art.texture != null and String(art.texture.resource_path).ends_with("assets/textures/tavern/documents/toby_contract_document.png"),
			"Toby contract document art uses the pixel-pipeline runtime texture")
		_ok(art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Toby contract document art renders with nearest filtering")
		_ok(art.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Toby contract document art does not block overlay controls")

	var left_body := overlay.get_node("Panel/LeftBody") as Label
	var right_body := overlay.get_node("Panel/RightBody") as Label
	var page_label := overlay.get_node("Panel/PageLabel") as Label
	_ok(left_body.position == Vector2(432, 172) and left_body.size == Vector2(416, 288),
		"Toby contract text is inset into the authored paper safe area")
	_ok(not right_body.visible, "Toby contract stays a single-page document")
	_ok(not page_label.visible, "Toby contract hides the ledger spread counter")

	overlay.open_document({
		"id": "bloodied_contract",
		"kind": "evidence",
		"title": "Bloodied Contract",
		"pages": ["generic evidence page"],
	})
	if art != null:
		_ok(not art.visible, "generic evidence documents do not show Toby contract art")
	_ok(left_body.position == Vector2(280, 120) and left_body.size == Vector2(256, 368),
		"generic document layout restores the ledger body position")
	_ok(page_label.visible, "generic document layout restores the page counter")


func _test_document_buttons(overlay: DocumentOverlay) -> void:
	overlay.open_document({"kind": "evidence", "pages": ["document page 1", "document page 2"]})
	var previous_button: Button = overlay.get_node("Panel/PreviousBtn")
	var next_button: Button = overlay.get_node("Panel/NextBtn")
	_ok(previous_button.disabled, "document previous button starts disabled")
	_ok(not next_button.disabled, "document next button is enabled with a second page")
	next_button.pressed.emit()
	_ok(overlay.get_current_page_text() == "document page 2", "document next button opens the second page")
	_ok(next_button.disabled, "document next button disables on the last page")
	_ok(not previous_button.disabled, "document previous button enables after advancing")
	previous_button.pressed.emit()
	_ok(overlay.get_current_page_text() == "document page 1", "document previous button returns to the first page")


func _test_ledger_buttons(overlay: DocumentOverlay) -> void:
	overlay.open_document({"kind": "ledger", "pages": ["ledger page 1", "ledger page 2", "ledger page 3"]})
	var previous_button: Button = overlay.get_node("Panel/PreviousBtn")
	var next_button: Button = overlay.get_node("Panel/NextBtn")
	_ok(overlay.get_current_page_text() == "ledger page 1", "ledger opens the left page")
	_ok(overlay.get_right_page_text() == "ledger page 2", "ledger opens the right page")
	_ok(not next_button.disabled, "ledger next button is enabled with a third page")
	next_button.pressed.emit()
	_ok(overlay.get_current_page_text() == "ledger page 3", "ledger next button advances by one spread")
	_ok(overlay.get_right_page_text() == "", "ledger leaves the final right page blank")
	_ok(not previous_button.disabled, "ledger previous button enables after advancing")
	previous_button.pressed.emit()
	_ok(overlay.get_current_page_text() == "ledger page 1", "ledger previous button returns to the first spread")
