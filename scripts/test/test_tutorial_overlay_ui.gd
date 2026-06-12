extends Node

const PANEL_TEXTURE := "res://assets/textures/tutorial/ui/tutorial_panel.png"
const HIGHLIGHT_TEXTURE := "res://assets/textures/tutorial/ui/tutorial_highlight_frame.png"

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_overlay_uses_tutorial_ui_assets()
	_finish()


func _test_overlay_uses_tutorial_ui_assets() -> void:
	var overlay := TutorialOverlay.new()
	add_child(overlay)
	await get_tree().process_frame

	overlay.show_step({
		"title": "测试教程",
		"description": "这段文字必须由 Godot 像素字体渲染。",
		"desc_pos_x": 0.5,
		"desc_pos_y": 0.35,
		"desc_width": 420,
		"desc_height": 140,
	}, [200, 160, 260, 120], false, true)

	var panel := overlay.get_node_or_null("DescriptionPanel") as Panel
	_ok(panel != null, "tutorial overlay exposes DescriptionPanel")
	if panel != null:
		var panel_style := panel.get_theme_stylebox("panel") as StyleBoxTexture
		_ok(panel_style != null, "tutorial description panel uses a texture stylebox")
		_ok(panel_style != null and panel_style.texture != null and panel_style.texture.resource_path == PANEL_TEXTURE,
			"tutorial description panel uses pipeline panel art")

	var highlight := overlay.get_node_or_null("HighlightFrame") as TextureRect
	_ok(highlight != null, "tutorial overlay exposes HighlightFrame")
	_ok(highlight != null and highlight.texture != null and highlight.texture.resource_path == HIGHLIGHT_TEXTURE,
		"tutorial highlight uses pipeline frame art")
	_ok(highlight != null and highlight.visible, "tutorial highlight frame becomes visible for a highlighted step")

	var title := overlay.get_node_or_null("TitleLabel") as Label
	_ok(title != null, "tutorial overlay exposes TitleLabel")
	_ok(title != null and title.get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH,
		"tutorial title uses the project pixel font")
	var desc := overlay.get_node_or_null("DescriptionPanel/DescriptionLabel") as RichTextLabel
	_ok(desc != null, "tutorial overlay exposes DescriptionLabel")
	_ok(desc != null and desc.get_theme_font("normal_font").resource_path == ThemeColors.MENU_FONT_PATH,
		"tutorial body uses the project pixel font")
	await _test_tutorial_copy_stays_inside_panel(overlay)

	overlay.queue_free()
	await get_tree().process_frame


func _test_tutorial_copy_stays_inside_panel(overlay: TutorialOverlay) -> void:
	overlay.show_step({
		"title": "很长的教程标题也必须留在木牌里面",
		"description": "这是一段故意写得很长的中文教程说明文字，用来模拟真实教程里没有空格的长句。文字必须在木牌安全区里自动换行，不能撑开控件，也不能横向飞出木牌外面。",
		"desc_pos_x": 0.18,
		"desc_pos_y": 0.12,
		"desc_width": 340,
		"desc_height": 130,
	}, [30, 5, 320, 55], false, true)

	var panel := overlay.get_node_or_null("DescriptionPanel") as Panel
	var title := overlay.get_node_or_null("TitleLabel") as Label
	var desc := overlay.get_node_or_null("DescriptionPanel/DescriptionLabel") as RichTextLabel
	_ok(panel != null and title != null and desc != null, "tutorial layout nodes exist for bounds checks")
	if panel == null or title == null or desc == null:
		return

	var safe_rect := Rect2(panel.position + Vector2(56, 30), panel.size - Vector2(112, 52))
	var title_rect := Rect2(title.position, title.size)
	var desc_rect := Rect2(panel.position + desc.position, desc.size)
	_ok(safe_rect.encloses(title_rect), "tutorial title stays inside the wooden panel safe area")
	_ok(safe_rect.encloses(desc_rect), "tutorial body stays inside the wooden panel safe area")
	_ok(not desc.fit_content, "tutorial body does not resize itself beyond the wooden panel")
	_ok(desc.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY, "tutorial body wraps Chinese copy inside the wooden panel")
	_ok(desc.clip_contents, "tutorial body clips any overflow to the wooden panel content area")
	_ok(title.get_theme_font_size("font_size") <= 20, "tutorial title uses a compact font size")
	_ok(desc.position.y <= 58.0, "tutorial body reclaims vertical room from the compact title")
	await _test_stamina_step_has_room_for_all_copy(overlay)
	await _test_gather_intro_step_has_room_for_all_copy(overlay)


func _test_stamina_step_has_room_for_all_copy(overlay: TutorialOverlay) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	overlay.show_step({
		"title": "行动力",
		"description": "这里显示剩余行动力。访问地点后结果会立即出现；行动力不足时，当天就不能再前往高消耗地点。",
		"desc_pos_x": 0.22,
		"desc_pos_y": 0.15,
		"desc_width": 340,
		"desc_height": 130,
	}, [30, 5, 320, 55], false, true)
	await get_tree().process_frame

	var panel := overlay.get_node_or_null("DescriptionPanel") as Panel
	var desc := overlay.get_node_or_null("DescriptionPanel/DescriptionLabel") as RichTextLabel
	_ok(panel != null and desc != null, "stamina tutorial exposes panel and body text")
	if panel == null or desc == null:
		return

	_ok(panel.size.y >= 180.0, "stamina tutorial panel keeps enough height for the wood art and copy")
	_ok(panel.position.y <= viewport_size.y * 0.15 + 4.0, "stamina tutorial panel respects desc_pos_y after title moved inside")
	_ok(desc.get_content_height() <= desc.size.y, "stamina tutorial body copy fits without vertical clipping")


func _test_gather_intro_step_has_room_for_all_copy(overlay: TutorialOverlay) -> void:
	var step := _tutorial_step("gather", "gather_intro")
	_ok(not step.is_empty(), "gather intro tutorial step exists")
	if step.is_empty():
		return

	overlay.show_step(step, [636, 1, 128, 40], false, true)
	await get_tree().process_frame

	var panel := overlay.get_node_or_null("DescriptionPanel") as Panel
	var desc := overlay.get_node_or_null("DescriptionPanel/DescriptionLabel") as RichTextLabel
	_ok(panel != null and desc != null, "gather intro tutorial exposes panel and body text")
	if panel == null or desc == null:
		return

	_ok(desc.get_content_height() <= desc.size.y, "gather intro tutorial body copy fits without vertical clipping")


func _tutorial_step(group_key: String, step_id: String) -> Dictionary:
	var file := FileAccess.open("res://data/tutorial_steps.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	for step in parsed.get(group_key, []):
		if step is Dictionary and String(step.get("id", "")) == step_id:
			return step
	return {}


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TUTORIAL-OVERLAY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TUTORIAL-OVERLAY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TUTORIAL-OVERLAY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
