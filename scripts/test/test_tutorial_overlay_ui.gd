extends Node

const PANEL_TEXTURE := "res://assets/textures/tutorial/ui/tutorial_panel.png"
const DIALOGUE_PANEL_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_panel.png"
const NARRATOR_NEUTRAL := "res://assets/textures/characters/vera/vera_neutral.png"
const NARRATOR_CONCERNED := "res://assets/textures/characters/vera/vera_concerned.png"
const NARRATOR_LEDGE := "res://assets/textures/characters/vera/vera_ledge.png"
const NARRATOR_NORMAL_SIZE := Vector2(256.0, 320.0)
const NARRATOR_LEDGE_SIZE := Vector2(256.0, 640.0)
const NARRATOR_LEDGE_GRIP_OFFSET := 56.0

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
	_ok(highlight != null, "tutorial overlay keeps HighlightFrame compatibility node")
	_ok(highlight != null and highlight.texture == null,
		"tutorial highlight frame art is disabled to avoid stretched frame distortion")
	_ok(highlight != null and not highlight.visible,
		"tutorial leaves only the mask cutout highlight visible")
	var catcher := overlay.get_node_or_null("HighlightClickCatcher") as Control
	_ok(catcher != null and catcher.position == Vector2(200, 160) and catcher.size == Vector2(260, 120),
		"tutorial highlight click area remains aligned with the cutout")

	var title := overlay.get_node_or_null("TitleLabel") as Label
	_ok(title != null, "tutorial overlay exposes TitleLabel")
	_ok(title != null and title.get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH,
		"tutorial title uses the project pixel font")
	var desc := overlay.get_node_or_null("DescriptionPanel/DescriptionLabel") as RichTextLabel
	_ok(desc != null, "tutorial overlay exposes DescriptionLabel")
	_ok(desc != null and desc.get_theme_font("normal_font").resource_path == ThemeColors.MENU_FONT_PATH,
		"tutorial body uses the project pixel font")
	await _test_narrator_lines_use_portrait_and_advance(overlay)
	await _test_narrator_layout_avoids_bottom_highlight(overlay)
	await _test_narrator_layout_uses_bottom_for_central_highlight(overlay)
	await _test_tutorial_copy_stays_inside_panel(overlay)

	overlay.queue_free()
	await get_tree().process_frame


func _test_narrator_lines_use_portrait_and_advance(overlay: TutorialOverlay) -> void:
	overlay.show_step({
		"title": "Narrator test",
		"description": "Legacy fallback text",
		"narrator_lines": [
			{"expression": "neutral", "text": "第一句旁白。"},
			{"expression": "concerned", "text": "第二句旁白。"},
		],
	}, [200, 160, 260, 120], false, false)
	await get_tree().process_frame

	var panel := overlay.get_node_or_null("DescriptionPanel") as Panel
	_ok(panel != null and not panel.visible,
		"legacy tutorial plaque hides when narrator lines are available")
	var narrator_panel := overlay.get_node_or_null("NarratorPanel") as Panel
	_ok(narrator_panel != null and narrator_panel.visible,
		"tutorial overlay exposes a narrator text panel")
	_ok(narrator_panel != null and _style_texture_path(narrator_panel.get_theme_stylebox("panel")) == DIALOGUE_PANEL_TEXTURE,
		"tutorial narrator reuses the shipped dialogue panel art")
	_assert_narrator_panel_uses_runtime_texture_size(narrator_panel)
	var name_label := overlay.get_node_or_null("NarratorPanel/NarratorNameLabel") as RichTextLabel
	_ok(name_label != null and name_label.text.contains("薇拉"),
		"tutorial narrator renders the speaker name")
	_ok(name_label != null and _style_texture_path(name_label.get_theme_stylebox("normal")) == "",
		"tutorial narrator speaker name renders without nameplate art")
	var progress_art := overlay.get_node_or_null("NarratorPanel/NarratorProgressArt") as TextureRect
	_ok(progress_art != null and progress_art.texture == null,
		"tutorial narrator keeps progress node without arrow art")
	_ok(progress_art != null and not progress_art.visible,
		"tutorial narrator progress art stays hidden after arrow removal")
	var portrait := overlay.get_node_or_null("NarratorPortrait") as TextureRect
	_ok(portrait != null and portrait.visible,
		"tutorial overlay exposes a narrator portrait")
	_ok(portrait != null and portrait.texture != null and portrait.texture.resource_path == NARRATOR_NEUTRAL,
		"first narrator line uses the requested expression portrait")
	var line := overlay.get_node_or_null("NarratorPanel/NarratorLineLabel") as RichTextLabel
	_ok(line != null and line.text.contains("第一句旁白"),
		"first narrator line is rendered by Godot text")

	var next := overlay.get_node_or_null("NextButton") as Button
	_ok(next != null, "tutorial overlay keeps NextButton for narrator mode")
	if next != null:
		next.pressed.emit()
		await get_tree().process_frame
	_ok(line != null and line.text.contains("第二句旁白"),
		"NextButton advances narrator lines before completing the tutorial step")
	_ok(portrait != null and portrait.texture != null and portrait.texture.resource_path == NARRATOR_CONCERNED,
		"advanced narrator line swaps to its expression portrait")


func _test_narrator_layout_avoids_bottom_highlight(overlay: TutorialOverlay) -> void:
	var highlight := [140, 675, 1000, 40]
	overlay.show_step({
		"title": "Bottom highlight",
		"description": "Legacy fallback text",
		"narrator_lines": [
			{"expression": "neutral", "text": "底部高亮时，我应该站到上方。"},
		],
	}, highlight, false, true)
	await get_tree().process_frame

	var narrator_panel := overlay.get_node_or_null("NarratorPanel") as Panel
	var portrait := overlay.get_node_or_null("NarratorPortrait") as TextureRect
	_assert_narrator_panel_uses_runtime_texture_size(narrator_panel)
	_ok(narrator_panel != null and narrator_panel.position.y == 0.0,
		"bottom highlight moves the full narrator dialogue bar to the top")
	_ok(narrator_panel != null and narrator_panel.position.y + narrator_panel.size.y < float(highlight[1]),
		"top narrator dialogue bar leaves the shortcut highlight visible")
	_ok(portrait != null and portrait.size == NARRATOR_LEDGE_SIZE,
		"raised narrator layout uses the double-height full-body ledge display size")
	_ok(portrait != null and portrait.size.y >= NARRATOR_NORMAL_SIZE.y * 2.0,
		"raised narrator ledge pose keeps the upper-body scale and extends downward")
	_ok(portrait != null and narrator_panel != null and absf((portrait.position.y + NARRATOR_LEDGE_GRIP_OFFSET) - (narrator_panel.position.y + narrator_panel.size.y)) <= 1.0,
		"raised ledge pose hides the source wood bar behind the top narrator bar edge")
	_ok(portrait != null and narrator_panel != null and portrait.z_index < narrator_panel.z_index,
		"raised ledge pose is drawn behind the narrator bar so the frame can cover her hands")
	_ok(portrait != null and portrait.texture != null and portrait.texture.resource_path == NARRATOR_LEDGE,
		"raised narrator layout uses the ledge-grip Vera pose")


func _test_narrator_layout_uses_bottom_for_central_highlight(overlay: TutorialOverlay) -> void:
	var highlight := [140, 80, 1000, 420]
	overlay.show_step({
		"title": "Central highlight",
		"description": "Legacy fallback text",
		"narrator_lines": [
			{"expression": "neutral", "text": "地图高亮时，文字面板不要压住地图。"},
		],
	}, highlight, false, true)
	await get_tree().process_frame

	var narrator_panel := overlay.get_node_or_null("NarratorPanel") as Panel
	var viewport_size := get_viewport().get_visible_rect().size
	_assert_narrator_panel_uses_runtime_texture_size(narrator_panel)
	_ok(narrator_panel != null and narrator_panel.position.y == viewport_size.y - narrator_panel.size.y,
		"central highlight keeps the full narrator dialogue bar at the bottom")
	_ok(narrator_panel != null and narrator_panel.position.y > float(highlight[1] + highlight[3]),
		"bottom narrator dialogue bar stays below a central map highlight")
	var portrait := overlay.get_node_or_null("NarratorPortrait") as TextureRect
	_ok(portrait != null and portrait.size == NARRATOR_NORMAL_SIZE,
		"bottom narrator layout uses the normal close-camera portrait size")


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


func _style_texture_path(style: StyleBox) -> String:
	var texture_style := style as StyleBoxTexture
	if texture_style == null or texture_style.texture == null:
		return ""
	return String(texture_style.texture.resource_path)


func _assert_narrator_panel_uses_runtime_texture_size(panel: Panel) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_ok(panel != null, "narrator dialogue panel exists for texture-size check")
	if panel == null:
		return
	var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	_ok(style != null and style.texture != null, "narrator dialogue panel has texture art for size check")
	if style == null or style.texture == null:
		return
	var texture_size := Vector2(style.texture.get_width(), style.texture.get_height())
	_ok(_size_matches(panel.size, texture_size),
		"narrator dialogue panel renders at exact runtime texture size without stretching")
	_ok(is_equal_approx(panel.position.x, floorf((viewport_size.x - texture_size.x) * 0.5)),
		"narrator dialogue panel is centered after preserving texture size")


func _size_matches(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TUTORIAL-OVERLAY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TUTORIAL-OVERLAY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
