extends Node

const TABLETOP_TEXTURE_PATH := "res://assets/textures/ui/clean_table_inference/clean_table_tabletop.png"
const CLUE_SCRAP_TEXTURE_PATH := "res://assets/textures/ui/clean_table_inference/components/clue_scrap.png"
const INFERENCE_NOTE_TEXTURE_PATH := "res://assets/textures/ui/clean_table_inference/components/inference_note.png"
const INK_RING_SLOT_TEXTURE_PATH := "res://assets/textures/ui/clean_table_inference/components/ink_ring_slot.png"
const KEYWORD_NOTES_PANEL_TEXTURE_PATH := "res://assets/textures/ui/clean_table_inference/components/keyword_notes_panel.png"
const PAPER_TAG_BUTTON_NORMAL_TEXTURE_PATH := "res://assets/textures/ui/clean_table_inference/components/paper_tag_button_normal.png"
const PAPER_TAG_BUTTON_HOVER_TEXTURE_PATH := "res://assets/textures/ui/clean_table_inference/components/paper_tag_button_hover.png"
const PAPER_TAG_BUTTON_PRESSED_TEXTURE_PATH := "res://assets/textures/ui/clean_table_inference/components/paper_tag_button_pressed.png"
const INFERENCE_INK_COLOR := Color(0.18, 0.09, 0.035)

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_clean_table_screen_contract()
	await _test_mira_question_title_contract()
	await _test_public_account_gap_hint_contract()
	_test_game_manager_clean_table_route_contract()
	await _test_inference_tutorial_contract()
	_finish()


func _test_clean_table_screen_contract() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	_suppress_inference_tutorial_auto_start()
	gm.inference.add_clue("toby_name")
	gm.inference.add_clue("blacktooth_escort")
	gm.inference.add_clue("high_pay_trap")
	gm.inference.add_clue("back_alley_boy")
	gm.inference.add_clue("one_person_walk")
	var scene: PackedScene = preload("res://scenes/ui/CleanTableInferenceScreen.tscn")
	var screen = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	_ok(screen.get_node_or_null("Background") != null, "screen keeps a background node")
	_assert_tabletop_background_contract(screen)
	_ok(screen.get_node_or_null("ClueArea") != null, "screen keeps the clue word panel")
	_ok(screen.get_node_or_null("BookArea") != null, "screen keeps the inference book area")
	_assert_table_style_contract(screen)
	_assert_clue_title_position(screen)
	_ok(screen.get_node_or_null("BookArea/QuestionLabel") is RichTextLabel, "screen renders a fill-in sentence")
	_ok(screen.get_node_or_null("BookArea/Blank_name") is Control, "identity name blank is addressable")
	_ok(screen.get_node_or_null("BookArea/Blank_identity") is Control, "identity blank is addressable")
	_assert_sentence_uses_inline_blanks(screen)
	_assert_blank_style(screen, "BookArea/Blank_name", INK_RING_SLOT_TEXTURE_PATH)
	_assert_blank_inside_book(screen, "Blank_name")
	_assert_blank_inside_book(screen, "Blank_identity")
	_ok(screen.get_node_or_null("SolvedList") != null, "screen keeps solved conclusions")
	_ok(screen.get_node_or_null("ExtinguishBtn") is Button, "screen has a continue control")
	_assert_button_style(screen, "ExtinguishBtn")
	_ok(screen.get_node_or_null("ClueArea/Clue_back_alley_boy") is Control, "back-alley clue word is visible")
	_assert_clue_word_style(screen, "ClueArea/Clue_back_alley_boy", "后巷少年")
	_assert_clue_word_can_be_arranged_on_notes_page(screen, "back_alley_boy")
	_ok(screen.get_node_or_null("BookArea/FeedbackLabel") is Label, "screen keeps a feedback label for wrong clues")
	_ok(String(screen.get_current_question_id()) == "toby_identity", "screen starts from the identity question")
	_assert_question_title(screen, "托比身份")
	var wrong: Dictionary = screen.place_clue_for_test("identity", "blacktooth_escort")
	var feedback := screen.get_node_or_null("BookArea/FeedbackLabel") as Label
	_ok(not bool(wrong.get("accepted", true)), "wrong clue is rejected on the current blank")
	_assert_wrong_trial_is_temporarily_filled(screen, "BookArea/Blank_identity")
	_ok(feedback != null and feedback.visible and feedback.text != "",
		"wrong clue placement explains why it bounced back")
	_assert_wrong_drop_feedback_style(screen)
	var empty_name_blank := screen.get_node_or_null("BookArea/Blank_name") as Button
	var near_name_blank := _near_blank_left_edge_global(screen, "BookArea/Blank_name", 14.0)
	_ok(empty_name_blank != null and not empty_name_blank.get_global_rect().has_point(near_name_blank),
		"test drop target sits just outside the visible ink-ring blank")
	var hit_blank := screen.call("_blank_at_global_position", near_name_blank) as Control
	_ok(hit_blank == empty_name_blank,
		"expanded blank hit area resolves the nearby drop to Blank_name")
	_drag_clue_word_to_global(screen, "toby_name", near_name_blank)
	var name_blank := screen.get_node_or_null("BookArea/Blank_name") as Button
	_ok(name_blank != null and name_blank.text != "",
		"dragging a clue word near a sentence blank fills that blank without pixel-perfect aiming")
	_assert_filled_blank_reads_as_inline_ink(screen, "BookArea/Blank_name")
	_assert_sentence_text_uses_black_ink(screen)
	var result: Dictionary = {"accepted": name_blank != null and name_blank.text != "", "solved": false}
	_ok(bool(result.get("accepted", false)) and not bool(result.get("solved", false)),
		"placing Toby fills the name blank without solving the whole identity sentence")
	result = screen.place_clue_for_test("identity", "back_alley_boy")
	_ok(bool(result.get("solved", false)), "placing both identity clues solves identity")
	_ok(gm.narrative.get_var("toby_identity_known") == true, "identity solve applies to GameManager")
	_assert_success_feedback_style(screen)
	_ok(screen.get_node_or_null("ClueArea/Clue_back_alley_boy") == null,
		"clean-table clue list hides a clue once no unsolved question can use it")
	_ok(screen.get_node_or_null("ClueArea/Clue_toby_name") is Control,
		"clean-table clue list keeps a solved-question clue when a future question still uses it")
	_ok(String(screen.get_current_question_id()) == "toby_commission_risk", "screen advances to the risk question")
	_assert_blank_inside_book(screen, "Blank_commission")
	_assert_blank_inside_book(screen, "Blank_risk")
	_assert_blank_inside_book(screen, "Blank_mindset")
	_assert_sentence_uses_inline_blanks(screen)
	_assert_book_controls_do_not_overlap(screen)
	result = screen.place_clue_for_test("commission", "blacktooth_escort")
	_ok(bool(result.get("accepted", false)) and not bool(result.get("solved", false)), "first risk blank accepts the commission clue")
	result = screen.place_clue_for_test("risk", "high_pay_trap")
	_ok(bool(result.get("accepted", false)) and not bool(result.get("solved", false)), "second risk blank accepts the suspicious-pay clue")
	result = screen.place_clue_for_test("mindset", "one_person_walk")
	_ok(bool(result.get("solved", false)), "placing the mindset clue solves the risk question")
	_ok(gm.narrative.get_var("toby_danger_known") == true, "risk solve applies danger flag")
	_ok(gm.narrative.get_var("toby_commission_lead") == true, "risk solve applies day-map lead flag")
	_assert_success_feedback_style(screen)
	_assert_empty_question_style(screen)
	var solved: Node = screen.get_node_or_null("SolvedList")
	_ok(solved != null and solved.get_child_count() >= 2, "solved list records conclusions")
	_assert_solved_conclusion_style(solved)
	screen.queue_free()
	await get_tree().process_frame


func _test_mira_question_title_contract() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	_suppress_inference_tutorial_auto_start()
	gm.inference.add_clue("toby_name")
	gm.inference.add_clue("back_alley_boy")
	gm.inference.add_clue("mira_traveling_mentor")
	gm.apply_inference_result(gm.inference.try_place("toby_identity", "name", "toby_name"))
	gm.apply_inference_result(gm.inference.try_place("toby_identity", "identity", "back_alley_boy"))
	var scene: PackedScene = preload("res://scenes/ui/CleanTableInferenceScreen.tscn")
	var screen = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	_ok(String(screen.get_current_question_id()) == "mira_toby_old_relation",
		"screen can open directly on the first Mira inference question after Toby identity")
	_assert_question_title(screen, "米拉旧路")
	screen.queue_free()
	await get_tree().process_frame


func _test_public_account_gap_hint_contract() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	_suppress_inference_tutorial_auto_start()
	gm.economy.current_day = 20
	gm.inference.add_clue("toby_name")
	gm.inference.add_clue("back_alley_boy")
	var scene: PackedScene = preload("res://scenes/ui/CleanTableInferenceScreen.tscn")
	var screen = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var hint := screen.get_node_or_null("BookArea/PublicAccountGapHint") as Label
	_ok(hint != null, "Day20 clean-table screen exposes a public-account gap hint label")
	if hint != null:
		_ok(hint.visible, "public-account gap hint is visible while the route gate is still incomplete")
		_ok(hint.text.contains("公开账本缺") and hint.text.contains("托比身份"),
			"public-account gap hint names the first missing inference instead of hiding the gate")
	screen.queue_free()
	await get_tree().process_frame


func _assert_question_title(screen: Node, expected: String) -> void:
	var title := screen.get_node_or_null("BookArea/QuestionTitle") as Label
	_ok(title != null, "inference screen shows a current-question title")
	if title == null:
		return
	_ok(title.text == expected, "current-question title identifies this as %s" % expected)
	_ok(title.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"current-question title does not block clue placement")


func _assert_blank_inside_book(screen: Node, blank_name: String) -> void:
	var book := screen.get_node_or_null("BookArea") as Control
	var blank := screen.get_node_or_null("BookArea/" + blank_name) as Control
	_ok(book != null and blank != null, blank_name + " exists for bounds check")
	if book == null or blank == null:
		return
	_ok(blank.position.x >= 0.0 and blank.position.x + blank.size.x <= book.size.x,
		blank_name + " stays horizontally inside the book page")


func _assert_tabletop_background_contract(screen: Node) -> void:
	var tabletop := screen.get_node_or_null("TabletopArt") as TextureRect
	_ok(tabletop != null, "screen uses the approved tabletop background as a separate art layer")
	if tabletop == null:
		return
	_ok(tabletop.texture != null and tabletop.texture.resource_path == TABLETOP_TEXTURE_PATH,
		"TabletopArt uses the approved clean-table tabletop texture")
	_ok(tabletop.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"TabletopArt keeps nearest-neighbor pixel filtering")
	_ok(tabletop.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"TabletopArt never blocks clue dragging")


func _assert_table_style_contract(screen: Node) -> void:
	var clue_area := screen.get_node_or_null("ClueArea") as Panel
	var book_area := screen.get_node_or_null("BookArea") as Panel
	_ok(clue_area != null and _stylebox_is_empty_or_transparent(clue_area, "panel"),
		"ClueArea uses a notes art layer instead of a box, tray, or framed token container")
	_assert_texture_art(screen, "ClueArea/PanelArt", KEYWORD_NOTES_PANEL_TEXTURE_PATH)
	_ok(book_area != null and _stylebox_is_empty_or_transparent(book_area, "panel"),
		"BookArea uses a non-stretching art child instead of stretching a stylebox")
	_assert_texture_art(screen, "BookArea/PaperArt", INFERENCE_NOTE_TEXTURE_PATH)


func _assert_clue_title_position(screen: Node) -> void:
	var title := screen.get_node_or_null("ClueArea/PanelTitle") as Label
	_ok(title != null, "clue notes page keeps its title label")
	if title == null:
		return
	_ok(title.position.y >= 39.0,
		"摘录 title is lowered by about one text height from the top edge")


func _assert_clue_word_style(screen: Node, path: String, expected_text: String) -> void:
	var word := screen.get_node_or_null(path) as Panel
	_ok(word != null, path + " exists as a draggable clue word")
	if word == null:
		return
	_ok(word.mouse_filter == Control.MOUSE_FILTER_STOP,
		path + " remains the draggable hit target")
	_ok(_stylebox_is_empty_or_transparent(word, "panel"),
		path + " reads as inked text on a notes page, not as a framed chip or tray item")
	_ok(word.get_node_or_null("PaperArt") == null,
		path + " is a word token, not a paper scrap art layer")
	_ok(word.get_node_or_null("Source") == null,
		path + " does not spend panel space on source text")
	_ok(word.get_node_or_null("InkMark") == null,
		path + " does not draw an underline while selected or dragged")
	_ok(word.tooltip_text == "",
		path + " does not show Godot's default tooltip on hover")
	var label := word.get_node_or_null("Label") as Label
	_ok(label != null and label.text == expected_text,
		path + " shows the clue word itself")
	_ok(label != null and label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		path + " label text does not block dragging the word")
	_ok(String(word.get("clue_id")) == "back_alley_boy",
		path + " keeps the underlying clue id for dragging into sentence blanks")


func _assert_clue_word_can_be_arranged_on_notes_page(screen: Node, clue_id: String) -> void:
	var target := Vector2(176, 238)
	_drag_clue_word_to_notes_position(screen, clue_id, target)
	var word := screen.get_node_or_null("ClueArea/Clue_" + clue_id) as Control
	_ok(word != null and word.position.distance_to(target) <= 2.0,
		"clue words can be freely placed on the notes page and stay where released")


func _drag_clue_word_to_notes_position(screen: Node, clue_id: String, target_position: Vector2) -> void:
	var clue_area := screen.get_node_or_null("ClueArea") as Control
	var word := screen.get_node_or_null("ClueArea/Clue_" + clue_id) as Control
	_ok(clue_area != null and word != null, "drag test can find the notes page and clue word")
	if clue_area == null or word == null:
		return
	_drag_clue_word_to_global(screen, clue_id, clue_area.global_position + target_position + word.size * 0.5)


func _drag_clue_word_to_global(screen: Node, clue_id: String, target_global: Vector2) -> void:
	var word := screen.get_node_or_null("ClueArea/Clue_" + clue_id) as Control
	_ok(word != null, "drag test can find clue word " + clue_id)
	if word == null:
		return
	_ok(word.has_method("_gui_input"), "clue word handles mouse input for dragging")
	if not word.has_method("_gui_input"):
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = word.size * 0.5
	word._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = target_global
	motion.relative = target_global - (word.global_position + word.size * 0.5)
	if screen.has_method("_input"):
		screen.call("_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = target_global
	if screen.has_method("_input"):
		screen.call("_input", release)


func _control_center_global(screen: Node, path: String) -> Vector2:
	var control := screen.get_node_or_null(path) as Control
	_ok(control != null, path + " exists for drag target")
	if control == null:
		return Vector2.ZERO
	return control.global_position + control.size * 0.5


func _near_blank_left_edge_global(screen: Node, path: String, distance: float) -> Vector2:
	var control := screen.get_node_or_null(path) as Control
	_ok(control != null, path + " exists for generous drag target")
	if control == null:
		return Vector2.ZERO
	return control.global_position + Vector2(-distance, control.size.y * 0.5)


func _assert_blank_style(screen: Node, path: String, expected_texture: String) -> void:
	var blank := screen.get_node_or_null(path) as Button
	_ok(blank != null and _stylebox_texture_path(blank.get_theme_stylebox("normal")) == expected_texture,
		path + " uses the approved ink-ring drop target art")
	if blank != null:
		_ok(abs(blank.size.x - blank.size.y) <= 1.0,
			path + " keeps the ink-ring drop target square instead of stretching it into an oval")
		_ok(blank.text == "",
			path + " lets the ink ring communicate an empty slot instead of drawing text inside it")
		var style := blank.get_theme_stylebox("normal") as StyleBoxTexture
		if style != null and style.texture != null:
			_ok(abs(blank.size.x - style.texture.get_width()) <= 1.0 and abs(blank.size.y - style.texture.get_height()) <= 1.0,
				path + " renders the ink ring at native runtime size")


func _assert_filled_blank_reads_as_inline_ink(screen: Node, path: String) -> void:
	var blank := screen.get_node_or_null(path) as Button
	_ok(blank != null, path + " exists as a filled inline clue")
	if blank == null:
		return
	_ok(_stylebox_is_empty_or_transparent(blank, "normal"),
		path + " does not compress paper art behind filled clue text")
	_ok(blank.get_theme_color("font_color") == INFERENCE_INK_COLOR,
		path + " uses the same black ink as the sentence text")


func _assert_texture_art(screen: Node, path: String, expected_texture: String) -> void:
	var art := screen.get_node_or_null(path) as TextureRect
	_ok(art != null, path + " exists as a non-stretching art layer")
	if art == null:
		return
	_ok(art.texture != null and art.texture.resource_path == expected_texture,
		path + " uses the approved runtime texture")
	_ok(art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		path + " keeps nearest-neighbor pixel filtering")
	_ok(art.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		path + " never blocks dragging or clicking")
	_ok(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		path + " keeps the source aspect ratio")
	if art.texture != null:
		_ok(abs(art.size.x - art.texture.get_width()) <= 1.0 and abs(art.size.y - art.texture.get_height()) <= 1.0,
			path + " renders at native runtime size instead of being resampled")


func _assert_button_style(screen: Node, path: String) -> void:
	var button := screen.get_node_or_null(path) as Button
	_ok(button != null and _stylebox_texture_path(button.get_theme_stylebox("normal")) == PAPER_TAG_BUTTON_NORMAL_TEXTURE_PATH,
		path + " uses the approved normal paper-tag button art")
	_ok(button != null and _stylebox_texture_path(button.get_theme_stylebox("hover")) == PAPER_TAG_BUTTON_HOVER_TEXTURE_PATH,
		path + " uses a distinct hover paper-tag button art")
	_ok(button != null and _stylebox_texture_path(button.get_theme_stylebox("pressed")) == PAPER_TAG_BUTTON_PRESSED_TEXTURE_PATH,
		path + " uses a distinct pressed paper-tag button art")
	if button != null:
		for state in ["normal", "hover", "pressed"]:
			var style := button.get_theme_stylebox(state) as StyleBoxTexture
			if style != null and style.texture != null:
				_ok(abs(button.size.x - style.texture.get_width()) <= 1.0 and abs(button.size.y - style.texture.get_height()) <= 1.0,
					path + " renders its " + state + " paper tag at native runtime size")


func _assert_solved_conclusion_style(solved: Node) -> void:
	if solved == null or solved.get_child_count() == 0:
		return
	var header := solved.get_node_or_null("ConclusionHeader") as Label
	_ok(header != null and header.text == "已成立",
		"solved conclusions use a persistent ink-list header")
	if header != null:
		_ok(header.get_theme_color("font_color") == ThemeColors.AMBER_PRIMARY,
			"solved conclusion header reads as warm ink on the table")
	var found_long := false
	for child in solved.get_children():
		if not String(child.name).begins_with("ConclusionEntry_"):
			continue
		var entry := child as Control
		_ok(entry != null and _stylebox_is_empty_or_transparent(entry, "panel"),
			"%s is transparent table ink, not a paper strip" % child.name)
		_ok(entry != null and _stylebox_texture_path(entry.get_theme_stylebox("panel")) == "",
			"%s does not use conclusion_strip paper art" % child.name)
		var label := entry.get_node_or_null("Label") as Label
		if label == null:
			continue
		_ok(label.text.begins_with("一、") or label.text.begins_with("二、"),
			"solved conclusion entries are numbered like notes")
		_ok(label.get_theme_color("font_color") == ThemeColors.TEXT_LIGHT,
			"solved conclusion text uses bright table ink without a paper backing")
		_ok(label.get_theme_constant("outline_size") >= 2,
			"solved conclusion text has an outline so it remains readable on the tabletop")
		if label.text.length() >= 36:
			found_long = true
			_ok(label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
				"long solved conclusions wrap as table notes instead of needing a larger paper")
	_ok(found_long, "test covers a long solved conclusion entry")


func _assert_empty_question_style(screen: Node) -> void:
	var question_label := screen.get_node_or_null("BookArea/QuestionLabel") as RichTextLabel
	_ok(question_label != null and question_label.visible,
		"empty inference state uses the book question label")
	if question_label == null:
		return
	_ok(question_label.get_theme_color("default_color") == INFERENCE_INK_COLOR,
		"empty inference state text uses black ink on the paper page")


func _assert_wrong_drop_feedback_style(screen: Node) -> void:
	var feedback := screen.get_node_or_null("BookArea/FeedbackLabel") as Label
	_ok(feedback != null and feedback.get_theme_color("font_color") == ThemeColors.AMBER_PRIMARY,
		"wrong placement feedback appears as table-note ink, not a detached debug message")
	_assert_judgement_layer(screen, "异议！", "wrong deduction pops a large objection-style judgement")


func _assert_wrong_trial_is_temporarily_filled(screen: Node, path: String) -> void:
	var blank := screen.get_node_or_null(path) as Button
	_ok(blank != null and blank.text != "",
		path + " temporarily shows the wrong clue before it is dismissed")
	if blank == null:
		return
	_ok(bool(blank.get_meta("wrong_trial", false)),
		path + " marks the temporary wrong hypothesis for visual treatment")
	_ok(blank.get_theme_color("font_color") != INFERENCE_INK_COLOR,
		path + " tints the wrong temporary clue differently from accepted ink")


func _assert_success_feedback_style(screen: Node) -> void:
	var feedback := screen.get_node_or_null("BookArea/FeedbackLabel") as Label
	_ok(feedback != null and feedback.visible,
		"solving a deduction shows immediate visual feedback on the inference page")
	if feedback == null:
		return
	_ok(feedback.text.contains("推断成立"),
		"success feedback explicitly marks the deduction as established")
	_ok(feedback.get_theme_color("font_color") != ThemeColors.AMBER_PRIMARY,
		"success feedback uses a different ink color from wrong-placement feedback")
	_assert_judgement_layer(screen, "推断成立", "successful deduction pops a large judgement layer")


func _assert_judgement_layer(screen: Node, expected_title: String, message: String) -> void:
	var layer := screen.get_node_or_null("BookArea/JudgementLayer") as Control
	_ok(layer != null and layer.visible, message)
	if layer == null:
		return
	var title := layer.get_node_or_null("Title") as Label
	var body := layer.get_node_or_null("Body") as Label
	_ok(title != null and title.text == expected_title,
		"judgement layer title is " + expected_title)
	_ok(title != null and title.get_theme_font_size("font_size") >= 34,
		"judgement title is large enough to read as a verdict")
	_ok(body != null and body.text != "",
		"judgement layer includes a short explanation")


func _stylebox_is_empty_or_transparent(control: Control, style_name: String) -> bool:
	if control == null:
		return false
	var style := control.get_theme_stylebox(style_name)
	if style is StyleBoxEmpty:
		return true
	var flat := style as StyleBoxFlat
	if flat == null:
		return false
	return flat.bg_color.a <= 0.08


func _stylebox_is_dark_panel(control: Control, style_name: String) -> bool:
	if control == null:
		return false
	var flat := control.get_theme_stylebox(style_name) as StyleBoxFlat
	if flat == null:
		return false
	return flat.bg_color.a >= 0.35 and flat.bg_color.r <= 0.16 and flat.bg_color.g <= 0.18 and flat.bg_color.b <= 0.18


func _stylebox_texture_path(style: StyleBox) -> String:
	var texture_style := style as StyleBoxTexture
	if texture_style == null or texture_style.texture == null:
		return ""
	return texture_style.texture.resource_path


func _assert_sentence_uses_inline_blanks(screen: Node) -> void:
	var question_label := screen.get_node_or_null("BookArea/QuestionLabel") as RichTextLabel
	var sentence_text := screen.get_node_or_null("BookArea/SentenceText_0") as Label
	_ok(question_label != null, "QuestionLabel exists for inline sentence check")
	if question_label != null:
		_ok(not question_label.text.contains("______"),
			"QuestionLabel does not duplicate fake underline blanks behind the real drop targets")
	_ok(sentence_text != null and sentence_text.visible,
		"sentence is rebuilt from inline text fragments around the drop targets")
	for child in (screen.get_node("BookArea") as Node).get_children():
		if String(child.name).begins_with("Blank_") and child is Button:
			var blank := child as Button
			_ok(blank.text != "放入线索",
				"%s uses a compact inline blank label instead of a detached button prompt" % child.name)


func _assert_sentence_text_uses_black_ink(screen: Node) -> void:
	var found := false
	for child in (screen.get_node("BookArea") as Node).get_children():
		if String(child.name).begins_with("SentenceText_") and child is Label:
			found = true
			var label := child as Label
			_ok(label.get_theme_color("font_color") == INFERENCE_INK_COLOR,
				"%s uses the same black ink as filled clues" % child.name)
	_ok(found, "sentence text labels exist for black-ink color check")


func _assert_book_controls_do_not_overlap(screen: Node) -> void:
	var feedback := screen.get_node_or_null("BookArea/FeedbackLabel") as Control
	_ok(feedback != null, "FeedbackLabel exists for overlap check")
	if feedback == null:
		return
	var feedback_rect := Rect2(feedback.position, feedback.size)
	for child in (screen.get_node("BookArea") as Node).get_children():
		if String(child.name).begins_with("Blank_") and child is Control:
			var blank := child as Control
			var blank_rect := Rect2(blank.position, blank.size)
			_ok(not feedback_rect.intersects(blank_rect),
				"%s does not overlap the feedback label" % child.name)


func _test_game_manager_clean_table_route_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game_manager.gd")
	_ok(source.contains("CleanTableInferenceScreen.tscn"), "GameManager can route to the clean-table screen")
	_ok(source.contains("has_available_questions"), "GameManager gates clean-table routing on solvable inference questions")
	_ok(source.contains("finish_clean_table_inference"), "GameManager exposes a return path from clean-table to ledger")


func _test_inference_tutorial_contract() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	var gm = get_node_or_null("/root/GameManager")
	_ok(tm != null and gm != null, "inference tutorial test can access GameManager and TutorialManager")
	if tm == null or gm == null:
		return

	var parsed := _tutorial_data()
	_ok(parsed.has("inference"), "tutorial data declares an inference group")

	gm._apply_save_state(gm._default_new_game_state())
	gm.inference.add_clue("toby_name")
	gm.inference.add_clue("back_alley_boy")

	var old_active: bool = tm._is_active
	var old_sequence: Array = tm._current_sequence.duplicate(true)
	var old_step: int = tm._current_step
	var old_completed: Array = tm._completed_steps.duplicate()
	var old_overlay = tm._overlay
	var old_inference_shown = tm.get("first_inference_shown")

	tm._remove_overlay()
	tm._is_active = false
	tm._current_sequence.clear()
	tm._current_step = -1
	if _tutorial_manager_has_inference_flag():
		tm.set("first_inference_shown", false)
	if parsed.has("inference"):
		for step in parsed.get("inference", []):
			tm._completed_steps.erase(String(step.get("id", "")))

	var scene: PackedScene = preload("res://scenes/ui/CleanTableInferenceScreen.tscn")
	var screen = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(screen.has_method("get_tutorial_highlight_rects"),
		"CleanTableInferenceScreen exposes tutorial highlight rects")
	if screen.has_method("get_tutorial_highlight_rects"):
		var rects: Dictionary = screen.call("get_tutorial_highlight_rects", "inference")
		for key in ["ClueArea", "BookArea", "ExtinguishBtn"]:
			_ok(rects.has(key), "inference tutorial exposes highlight rect: " + key)
			if rects.has(key):
				var values: Array = rects.get(key, [])
				_ok(values.size() == 4 and float(values[2]) > 0.0 and float(values[3]) > 0.0,
					"inference tutorial highlight rect has positive size: " + key)

	_ok(tm.get("first_inference_shown") == true,
		"opening the clean-table screen marks the inference tutorial as shown")
	_ok(tm._is_active, "opening the clean-table screen starts the inference tutorial")
	if tm._is_active and not tm._current_sequence.is_empty():
		_ok(String(tm._current_sequence[0].get("group", "")) == "inference",
			"clean-table screen starts the inference tutorial group")

	screen.queue_free()
	await get_tree().process_frame
	tm._remove_overlay()
	tm._is_active = old_active
	tm._current_sequence = old_sequence
	tm._current_step = old_step
	tm._completed_steps = old_completed
	if _tutorial_manager_has_inference_flag():
		tm.set("first_inference_shown", old_inference_shown == true)
	tm._overlay = old_overlay if is_instance_valid(old_overlay) else null


func _suppress_inference_tutorial_auto_start() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null and _tutorial_manager_has_inference_flag():
		tm.set("first_inference_shown", true)


func _tutorial_manager_has_inference_flag() -> bool:
	var source := FileAccess.get_file_as_string("res://scripts/tutorial/tutorial_manager.gd")
	return source.contains("first_inference_shown")


func _tutorial_data() -> Dictionary:
	var file := FileAccess.open("res://data/tutorial_steps.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-CLEAN-TABLE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-CLEAN-TABLE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-CLEAN-TABLE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
