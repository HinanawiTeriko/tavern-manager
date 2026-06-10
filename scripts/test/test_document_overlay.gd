extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var day_map_scene := preload("res://scenes/ui/DayMap.tscn")
	var view = day_map_scene.instantiate()
	add_child(view)
	await get_tree().process_frame
	_test_overlay_uses_ledger_art(view.get_node("UILayer/DocumentOverlay"))
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
	_ok(left_body.position == Vector2(216, 120) and left_body.size == Vector2(388, 420),
		"ledger left page uses a wide clean text-safe column")
	_ok(right_body.position == Vector2(684, 120) and right_body.size == Vector2(388, 420),
		"ledger right page uses a wide clean text-safe column")
	_ok(left_body.get_theme_color("font_color") == Color(0.16, 0.105, 0.062, 1),
		"ledger body text uses dark ink on parchment")
	var expected_button_art := {
		"Panel/PreviousBtn": "assets/textures/ledger/ui/button_nav_left_normal.png",
		"Panel/NextBtn": "assets/textures/ledger/ui/button_nav_right_normal.png",
		"Panel/CloseBtn": "assets/textures/ledger/ui/button_close_normal.png",
	}
	for path in expected_button_art.keys():
		var button := overlay.get_node(path) as Button
		var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
		_ok(normal != null and normal.texture != null, "%s uses texture art" % path)
		if normal != null and normal.texture != null:
			_ok(String(normal.texture.resource_path).ends_with(expected_button_art[path]),
				"%s uses ledger button art" % path)
		var font: Font = button.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"),
			"%s uses Fusion Pixel font" % path)


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
