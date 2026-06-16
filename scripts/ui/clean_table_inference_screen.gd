class_name CleanTableInferenceScreen
extends Control

class ClueWord:
	extends Panel

	var clue_id := ""
	var display_text := ""
	var screen: Node = null

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
				if screen != null:
					screen.call("_begin_clue_word_drag", self, mouse_event.position)
				accept_event()


class InferenceBlank:
	extends Button

	var blank_id := ""
	var screen: Node = null

	func _ready() -> void:
		pressed.connect(_on_pressed)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and String((data as Dictionary).get("clue_id", "")) != ""

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if screen != null:
			screen.call("_place_clue", blank_id, String((data as Dictionary).get("clue_id", "")))

	func _on_pressed() -> void:
		if screen != null:
			screen.call("_place_selected_clue", blank_id)


const PIXEL_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const TABLETOP_TEXTURE := "res://assets/textures/ui/clean_table_inference/clean_table_tabletop.png"
const COMPONENT_PREFIX := "res://assets/textures/ui/clean_table_inference/components/"
const CLUE_SCRAP_TEXTURE := COMPONENT_PREFIX + "clue_scrap.png"
const INFERENCE_NOTE_TEXTURE := COMPONENT_PREFIX + "inference_note.png"
const INK_RING_SLOT_TEXTURE := COMPONENT_PREFIX + "ink_ring_slot.png"
const KEYWORD_NOTES_PANEL_TEXTURE := COMPONENT_PREFIX + "keyword_notes_panel.png"
const PAPER_TAG_BUTTON_NORMAL_TEXTURE := COMPONENT_PREFIX + "paper_tag_button_normal.png"
const PAPER_TAG_BUTTON_HOVER_TEXTURE := COMPONENT_PREFIX + "paper_tag_button_hover.png"
const PAPER_TAG_BUTTON_PRESSED_TEXTURE := COMPONENT_PREFIX + "paper_tag_button_pressed.png"
const SUCCESS_FEEDBACK_COLOR := Color(0.17, 0.31, 0.19)
const INFERENCE_INK_COLOR := Color(0.18, 0.09, 0.035)
const OBJECTION_INK_COLOR := Color(0.58, 0.08, 0.035)
const CONCLUSION_NOTE_WIDTH := 276.0
const CONCLUSION_NOTE_TEXT_WIDTH := 260.0

@onready var _background: ColorRect = $Background
@onready var _tabletop_art: TextureRect = $TabletopArt
@onready var _clue_area: Panel = $ClueArea
@onready var _book_area: Panel = $BookArea
@onready var _question_label: RichTextLabel = $BookArea/QuestionLabel
@onready var _feedback_label: Label = $BookArea/FeedbackLabel
@onready var _solved_list: VBoxContainer = $SolvedList
@onready var _extinguish_btn: Button = $ExtinguishBtn

var _gm = null
var _inference = null
var _current_question: Dictionary = {}
var _selected_clue_id := ""
var _clue_positions: Dictionary = {}
var _drag_word: Control = null
var _drag_word_offset := Vector2.ZERO
var _drag_word_start := Vector2.ZERO
var _drag_word_moved := false
var _wrong_trial_placements: Dictionary = {}
var _wrong_trial_blank_id := ""
var _judgement_tween: Tween = null


func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_inference = _gm.inference
	_apply_static_style()
	_extinguish_btn.pressed.connect(_on_extinguish_pressed)
	_refresh()


func get_current_question_id() -> String:
	return String(_current_question.get("id", ""))


func place_clue_for_test(blank_id: String, clue_id: String) -> Dictionary:
	return _place_clue(blank_id, clue_id)


func _refresh() -> void:
	_render_clues()
	_render_current_question()


func _render_clues() -> void:
	_clear_children_with_prefix(_clue_area, "Clue_")
	var owned: Array = _inference.get_relevant_owned_clues() if _inference.has_method("get_relevant_owned_clues") else _inference.get_owned_clues()
	var cursor := Vector2(68.0, 76.0)
	var max_right := 250.0
	var row_height := 44.0
	for clue in owned:
		var data: Dictionary = clue
		var word := ClueWord.new()
		var clue_id := String(data.get("id", ""))
		var text := String(data.get("label", clue_id))
		var width: float = clampf(_measure_sentence_text(text, 14) + 16.0, 62.0, 178.0)
		if cursor.x > 68.0 and cursor.x + width > max_right:
			cursor.x = 68.0
			cursor.y += row_height
		word.name = "Clue_" + clue_id
		word.clue_id = clue_id
		word.display_text = text
		word.screen = self
		word.size = Vector2(width, 32.0)
		if _clue_positions.has(clue_id) and _clue_positions[clue_id] is Vector2:
			word.position = _clamp_clue_word_position(word, _clue_positions[clue_id])
		else:
			word.position = _clamp_clue_word_position(word, cursor)
		word.tooltip_text = ""
		word.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		word.mouse_filter = Control.MOUSE_FILTER_STOP
		word.mouse_default_cursor_shape = Control.CURSOR_DRAG
		word.add_theme_stylebox_override("panel", _clue_word_style(false))

		var label := Label.new()
		label.name = "Label"
		label.position = Vector2.ZERO
		label.size = word.size
		label.text = text
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(label, 14, Color(0.22, 0.12, 0.045))
		word.add_child(label)

		_clue_area.add_child(word)
		cursor.x += width + 12.0


func _begin_clue_word_drag(word: Control, local_mouse_position: Vector2) -> void:
	if word == null:
		return
	_drag_word = word
	_drag_word_offset = local_mouse_position
	_drag_word_start = word.position
	_drag_word_moved = false
	_drag_word.z_index = 80
	_select_clue(String(word.get("clue_id")))


func _input(event: InputEvent) -> void:
	if _drag_word == null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_move_drag_word_to_global(motion.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_release_clue_word(mouse_event.position)
			_drag_word = null
			get_viewport().set_input_as_handled()


func _move_drag_word_to_global(global_mouse_position: Vector2) -> void:
	if _drag_word == null:
		return
	var local_mouse := _clue_area.get_global_transform().affine_inverse() * global_mouse_position
	_drag_word.position = local_mouse - _drag_word_offset
	_drag_word_moved = _drag_word_moved or _drag_word.position.distance_to(_drag_word_start) > 3.0


func _release_clue_word(global_mouse_position: Vector2) -> Dictionary:
	var word := _drag_word
	if word == null:
		return {"accepted": false, "solved": false, "hint": ""}
	word.z_index = 0
	var clue_id := String(word.get("clue_id"))
	var blank := _blank_at_global_position(global_mouse_position)
	if blank != null:
		var result := _place_clue(String(blank.get("blank_id")), clue_id)
		if not bool(result.get("accepted", false)) and is_instance_valid(word):
			_set_clue_word_position(word, _drag_word_start, true)
		return result
	var local_mouse := _clue_area.get_global_transform().affine_inverse() * global_mouse_position
	_set_clue_word_position(word, local_mouse - _drag_word_offset, true)
	return {"accepted": false, "solved": false, "hint": ""}


func _blank_at_global_position(global_position: Vector2) -> Control:
	for child in _book_area.get_children():
		if String(child.name).begins_with("Blank_") and child is Control:
			var blank := child as Control
			if Rect2(blank.global_position, blank.size).has_point(global_position):
				return blank
	return null


func _set_clue_word_position(word: Control, target_position: Vector2, store: bool) -> void:
	var clamped := _clamp_clue_word_position(word, target_position)
	word.position = clamped
	if store:
		_clue_positions[String(word.get("clue_id"))] = clamped


func _clamp_clue_word_position(word: Control, target_position: Vector2) -> Vector2:
	var min_pos := Vector2(48.0, 52.0)
	var max_pos := Vector2(258.0 - word.size.x, 522.0 - word.size.y)
	max_pos.x = maxf(min_pos.x, max_pos.x)
	max_pos.y = maxf(min_pos.y, max_pos.y)
	return Vector2(
		clampf(target_position.x, min_pos.x, max_pos.x),
		clampf(target_position.y, min_pos.y, max_pos.y)
	)


func _render_current_question() -> void:
	_clear_children_with_prefix(_book_area, "Blank_")
	_clear_children_with_prefix(_book_area, "SentenceText_")
	var title := _ensure_question_title()
	var questions: Array = _inference.get_available_questions()
	if questions.is_empty():
		_current_question = {}
		title.visible = false
		_question_label.visible = true
		_question_label.text = "今晚没有新的推断。"
		_clear_feedback()
		_extinguish_btn.text = "翻到账本"
		return
	_current_question = questions[0]
	_question_label.visible = false
	_question_label.text = ""
	title.text = String(_current_question.get("title", "推断"))
	title.visible = true
	_clear_feedback()
	_extinguish_btn.text = "暂时合上"
	var blanks: Dictionary = _current_question.get("blanks", {})
	var placements: Dictionary = _merged_render_placements(_current_question.get("placements", {}))
	_render_sentence_controls(blanks, placements)


func _ensure_question_title() -> Label:
	var title := _book_area.get_node_or_null("QuestionTitle") as Label
	if title == null:
		title = Label.new()
		title.name = "QuestionTitle"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_book_area.add_child(title)
	title.position = Vector2(44.0, 78.0)
	title.size = Vector2(420.0, 34.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(title, 17, INFERENCE_INK_COLOR)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.95, 0.73, 0.42, 0.35))
	return title


func _merged_render_placements(real_placements: Dictionary) -> Dictionary:
	var placements := real_placements.duplicate()
	for blank_id in _wrong_trial_placements.keys():
		if String(placements.get(blank_id, "")) == "":
			placements[blank_id] = _wrong_trial_placements[blank_id]
	return placements


func _render_sentence_controls(blanks: Dictionary, placements: Dictionary) -> void:
	var text := String(_current_question.get("text", ""))
	var segments := text.split("______", true)
	var blank_ids := blanks.keys()
	var left := 44.0
	var right := 470.0
	var cursor := Vector2(left, 124.0)
	var line_height := 58.0
	var text_index := 0
	for i in range(blank_ids.size()):
		var segment := String(segments[i]) if i < segments.size() else ""
		if segment != "":
			var segment_width := _measure_sentence_text(segment, 20)
			if cursor.x > left and cursor.x + segment_width > right:
				cursor.x = left
				cursor.y += line_height
			_add_sentence_text(text_index, segment, cursor, Vector2(segment_width, 40.0))
			text_index += 1
			cursor.x += segment_width

		var blank_id := String(blank_ids[i])
		var blank := InferenceBlank.new()
		blank.name = "Blank_" + blank_id
		blank.blank_id = blank_id
		blank.screen = self
		blank.size = _sentence_blank_size(blank_id, placements)
		if cursor.x > left and cursor.x + blank.size.x > right:
			cursor.x = left
			cursor.y += line_height
		blank.position = Vector2(cursor.x, cursor.y - 2.0)
		var blank_empty := String(placements.get(blank_id, "")) == ""
		blank.text = "" if blank_empty else _blank_text(blank_id, placements)
		blank.set_meta("blank_empty", blank_empty)
		blank.set_meta("wrong_trial", _wrong_trial_placements.has(blank_id))
		blank.clip_text = true
		blank.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_style_blank(blank)
		_book_area.add_child(blank)
		cursor.x += blank.size.x + 8.0

	if segments.size() > blank_ids.size():
		var tail := String(segments[blank_ids.size()])
		if tail != "":
			var tail_width := _measure_sentence_text(tail, 20)
			if cursor.x > left and cursor.x + tail_width > right:
				cursor.x = left
				cursor.y += line_height
			_add_sentence_text(text_index, tail, cursor, Vector2(tail_width, 40.0))


func _add_sentence_text(index: int, text: String, position: Vector2, size: Vector2) -> void:
	var label := Label.new()
	label.name = "SentenceText_%d" % index
	label.position = position
	label.size = size
	label.text = text
	label.clip_text = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(label, 20, INFERENCE_INK_COLOR)
	_book_area.add_child(label)


func _measure_sentence_text(text: String, font_size: int) -> float:
	var measured := PIXEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return max(18.0, measured + 4.0)


func _sentence_blank_size(blank_id: String, placements: Dictionary) -> Vector2:
	var is_empty := String(placements.get(blank_id, "")) == ""
	if is_empty:
		return Vector2(48.0, 48.0)
	var text := _blank_text(blank_id, placements)
	var width: float = clampf(_measure_sentence_text(text, 14) + 34.0, 128.0, 190.0)
	if blank_id == "identity":
		width = max(width, 152.0)
	elif blank_id == "commission":
		width = max(width, 166.0)
	elif blank_id == "risk" or blank_id == "mindset":
		width = max(width, 158.0)
	return Vector2(width, 40.0)


func _place_selected_clue(blank_id: String) -> Dictionary:
	if _selected_clue_id == "":
		var result := {"accepted": false, "solved": false, "hint": "先拿起一个线索词。"}
		_show_feedback(String(result.get("hint", "")))
		return result
	return _place_clue(blank_id, _selected_clue_id)


func _place_clue(blank_id: String, clue_id: String) -> Dictionary:
	var question_id := get_current_question_id()
	if question_id == "":
		return {"accepted": false, "solved": false, "hint": ""}
	var result: Dictionary = _inference.try_place(question_id, blank_id, clue_id)
	if bool(result.get("accepted", false)):
		_clear_wrong_trial_state()
		_selected_clue_id = ""
		_clear_feedback()
		var success_feedback := ""
		if bool(result.get("solved", false)):
			if _gm.has_method("apply_inference_result"):
				_gm.apply_inference_result(result)
			var conclusion := String(result.get("conclusion", ""))
			_add_conclusion(conclusion)
			success_feedback = "推断成立：" + conclusion
		_refresh()
		if success_feedback != "":
			_show_success_feedback(success_feedback)
	else:
		var hint := String(result.get("hint", "这个词和这个空位对不上。"))
		_show_wrong_trial(blank_id, clue_id, hint)
	return result


func _show_feedback(text: String) -> void:
	if _feedback_label == null:
		return
	_feedback_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_feedback_label.text = text if text != "" else "这个词和这个空位对不上。"
	_feedback_label.visible = true


func _show_wrong_trial(blank_id: String, clue_id: String, hint: String) -> void:
	_wrong_trial_placements.clear()
	_wrong_trial_placements[blank_id] = clue_id
	_wrong_trial_blank_id = blank_id
	_render_current_question()
	_show_feedback(hint)
	_show_judgement_feedback("failure", "异议！", hint)


func _show_success_feedback(text: String) -> void:
	if _feedback_label == null:
		return
	_feedback_label.add_theme_color_override("font_color", SUCCESS_FEEDBACK_COLOR)
	_feedback_label.text = text
	_feedback_label.visible = true
	_show_judgement_feedback("success", "推断成立", text.trim_prefix("推断成立："))


func _clear_feedback() -> void:
	if _feedback_label == null:
		return
	_feedback_label.text = ""
	_feedback_label.visible = false


func _clear_wrong_trial_state() -> void:
	_wrong_trial_placements.clear()
	_wrong_trial_blank_id = ""


func _show_judgement_feedback(kind: String, title_text: String, body_text: String) -> void:
	var layer := _ensure_judgement_layer()
	var title := layer.get_node("Title") as Label
	var body := layer.get_node("Body") as Label
	var mark := layer.get_node("Mark") as Label
	var failure := kind == "failure"
	title.text = title_text
	body.text = body_text
	title.add_theme_color_override("font_color", OBJECTION_INK_COLOR if failure else SUCCESS_FEEDBACK_COLOR)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.01, 0.92) if failure else Color(0.05, 0.08, 0.035, 0.86))
	body.add_theme_color_override("font_color", OBJECTION_INK_COLOR if failure else INFERENCE_INK_COLOR)
	mark.visible = failure
	layer.visible = true
	layer.modulate = Color(1.0, 1.0, 1.0, 1.0)
	layer.scale = Vector2(1.08, 1.08)
	if _judgement_tween != null and _judgement_tween.is_valid():
		_judgement_tween.kill()
	_judgement_tween = create_tween()
	_judgement_tween.tween_property(layer, "scale", Vector2.ONE, 0.12)
	_judgement_tween.tween_interval(0.95 if failure else 1.15)
	_judgement_tween.tween_property(layer, "modulate:a", 0.0, 0.28)
	_judgement_tween.tween_callback(Callable(self, "_finish_judgement_feedback").bind(kind))


func _finish_judgement_feedback(kind: String) -> void:
	var layer := _book_area.get_node_or_null("JudgementLayer") as Control
	if layer != null:
		layer.visible = false
		layer.modulate.a = 1.0
		layer.scale = Vector2.ONE
	if kind == "failure":
		_clear_wrong_trial_state()
		_render_current_question()


func _add_conclusion(text: String) -> void:
	if text == "":
		return
	_ensure_conclusion_header()
	var entry_index := _conclusion_entry_count() + 1
	var entry := Panel.new()
	entry.name = "ConclusionEntry_%d" % entry_index
	var entry_size := _conclusion_note_size(text)
	entry.custom_minimum_size = entry_size
	entry.size = entry_size
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	entry.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	if entry_index > 1:
		var divider := ColorRect.new()
		divider.name = "Divider"
		divider.position = Vector2(0, 0)
		divider.size = Vector2(CONCLUSION_NOTE_WIDTH, 1)
		divider.color = Color(0.70, 0.54, 0.28, 0.42)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(divider)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(0, 7)
	label.size = Vector2(CONCLUSION_NOTE_TEXT_WIDTH, entry_size.y - 8.0)
	label.text = "%s、%s" % [_conclusion_number(entry_index), text]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(label, 13, ThemeColors.TEXT_LIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.012, 0.92))
	entry.add_child(label)
	_solved_list.add_child(entry)


func _ensure_conclusion_header() -> void:
	if _solved_list.get_node_or_null("ConclusionHeader") != null:
		return
	var header := Label.new()
	header.name = "ConclusionHeader"
	header.text = "已成立"
	header.custom_minimum_size = Vector2(CONCLUSION_NOTE_WIDTH, 30.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(header, 15, ThemeColors.AMBER_PRIMARY)
	header.add_theme_constant_override("outline_size", 2)
	header.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.012, 0.94))
	_solved_list.add_child(header)


func _conclusion_entry_count() -> int:
	var count := 0
	for child in _solved_list.get_children():
		if String(child.name).begins_with("ConclusionEntry_"):
			count += 1
	return count


func _conclusion_note_size(text: String) -> Vector2:
	var measured_width := _measure_sentence_text(text, 13)
	var line_count := ceili(maxf(1.0, measured_width / CONCLUSION_NOTE_TEXT_WIDTH))
	var height := clampf(18.0 + float(line_count) * 23.0, 46.0, 132.0)
	if text.length() >= 36:
		height = maxf(height, 104.0)
	return Vector2(CONCLUSION_NOTE_WIDTH, height)


func _conclusion_number(index: int) -> String:
	match index:
		1:
			return "一"
		2:
			return "二"
		3:
			return "三"
		4:
			return "四"
	return str(index)


func _select_clue(clue_id: String) -> void:
	_selected_clue_id = clue_id
	for child in _clue_area.get_children():
		if String(child.name).begins_with("Clue_"):
			var selected := String(child.name) == "Clue_" + clue_id
			child.modulate = Color.WHITE
			if child is Panel:
				(child as Panel).add_theme_stylebox_override("panel", _clue_word_style(selected))
			var label := child.get_node_or_null("Label") as Label
			if label != null:
				label.add_theme_color_override("font_color", Color(0.13, 0.055, 0.02) if selected else Color(0.22, 0.12, 0.045))


func _blank_text(blank_id: String, placements: Dictionary) -> String:
	var clue_id := String(placements.get(blank_id, ""))
	if clue_id == "":
		return "待证"
	var clue: Dictionary = _inference.get_clue(clue_id)
	return String(clue.get("label", clue_id))


func _highlight_blanks(text: String) -> String:
	return text.replace("______", "[color=#d6a84d]______[/color]")


func _blank_position(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2(153, 244)
	if count == 2:
		return Vector2(48 + index * 258, 244)
	if count == 3:
		if index < 2:
			return Vector2(48 + index * 258, 230)
		return Vector2(153, 292)
	var col := index % 2
	var row := int(index / 2)
	return Vector2(48 + col * 258, 220 + row * 62)


func _clear_children_with_prefix(parent: Node, prefix: String) -> void:
	for child in parent.get_children():
		if String(child.name).begins_with(prefix):
			parent.remove_child(child)
			child.queue_free()


func _apply_static_style() -> void:
	_background.color = ThemeColors.BACKGROUND_DEEP
	if _tabletop_art != null:
		_tabletop_art.texture = TextureManager.try_load(TABLETOP_TEXTURE)
		_tabletop_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_tabletop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clue_area.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_book_area.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clue_area.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_book_area.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_ensure_texture_art(_clue_area, "PanelArt", KEYWORD_NOTES_PANEL_TEXTURE)
	_ensure_texture_art(_book_area, "PaperArt", INFERENCE_NOTE_TEXTURE)
	_ensure_clue_panel_title()
	_ensure_judgement_layer()
	_question_label.bbcode_enabled = true
	_question_label.add_theme_font_override("normal_font", PIXEL_FONT)
	_question_label.add_theme_font_size_override("normal_font_size", 20)
	_question_label.add_theme_color_override("default_color", INFERENCE_INK_COLOR)
	_question_label.fit_content = false
	_style_label(_feedback_label, 13, ThemeColors.AMBER_PRIMARY)
	_feedback_label.visible = false
	_solved_list.add_theme_constant_override("separation", 8)
	_style_paper_tag_button(_extinguish_btn, 16)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _ensure_clue_panel_title() -> void:
	var title := _clue_area.get_node_or_null("PanelTitle") as Label
	if title == null:
		title = Label.new()
		title.name = "PanelTitle"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clue_area.add_child(title)
	title.position = Vector2(74, 40)
	title.size = Vector2(156, 26)
	title.text = "摘录"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 15, Color(0.23, 0.13, 0.055))


func _ensure_judgement_layer() -> Control:
	var layer := _book_area.get_node_or_null("JudgementLayer") as Control
	if layer == null:
		layer = Control.new()
		layer.name = "JudgementLayer"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.z_index = 100
		_book_area.add_child(layer)
	layer.position = Vector2(38.0, 176.0)
	layer.size = Vector2(436.0, 196.0)
	layer.pivot_offset = layer.size * 0.5
	layer.visible = false

	var mark := layer.get_node_or_null("Mark") as Label
	if mark == null:
		mark = Label.new()
		mark.name = "Mark"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(mark)
	mark.position = Vector2(50.0, 18.0)
	mark.size = Vector2(336.0, 130.0)
	mark.text = "×"
	mark.rotation = -0.16
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(mark, 96, Color(0.42, 0.04, 0.02, 0.22))

	var title := layer.get_node_or_null("Title") as Label
	if title == null:
		title = Label.new()
		title.name = "Title"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(title)
	title.position = Vector2.ZERO
	title.size = Vector2(436.0, 84.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(title, 42, SUCCESS_FEEDBACK_COLOR)
	title.add_theme_constant_override("outline_size", 5)

	var body := layer.get_node_or_null("Body") as Label
	if body == null:
		body = Label.new()
		body.name = "Body"
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(body)
	body.position = Vector2(38.0, 88.0)
	body.size = Vector2(360.0, 74.0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(body, 16, INFERENCE_INK_COLOR)
	body.add_theme_constant_override("outline_size", 2)
	body.add_theme_color_override("font_outline_color", Color(0.96, 0.76, 0.46, 0.42))
	return layer


func _style_blank(button: Button) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 14)
	var wrong_trial := bool(button.get_meta("wrong_trial", false))
	var ink_color := OBJECTION_INK_COLOR if wrong_trial else INFERENCE_INK_COLOR
	button.add_theme_color_override("font_color", ink_color)
	button.add_theme_color_override("font_hover_color", ink_color)
	button.add_theme_color_override("font_pressed_color", ink_color)
	button.add_theme_constant_override("outline_size", 2 if wrong_trial else 0)
	button.add_theme_color_override("font_outline_color", Color(0.96, 0.72, 0.42, 0.55) if wrong_trial else Color.TRANSPARENT)
	var empty := bool(button.get_meta("blank_empty", false))
	var style := _component_style(
		INK_RING_SLOT_TEXTURE,
		Vector4.ZERO,
		Vector4(4, 2, 4, 2),
		_paper_fallback(Color(0.28, 0.18, 0.08, 0.22), Color(ThemeColors.AMBER_PRIMARY, 0.36))
	) if empty else StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _paper_style() -> StyleBox:
	return StyleBoxEmpty.new()


func _word_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.060, 0.060, 0.76)
	style.border_color = Color(0.25, 0.20, 0.12, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 14
	style.content_margin_top = 14
	style.content_margin_right = 14
	style.content_margin_bottom = 14
	return style


func _clue_word_style(_selected: bool) -> StyleBox:
	return StyleBoxEmpty.new()


func _add_texture_art(parent: Control, node_name: String, texture_path: String) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = TextureManager.try_load(texture_path)
	parent.add_child(art)
	parent.move_child(art, 0)
	return art


func _ensure_texture_art(parent: Control, node_name: String, texture_path: String) -> TextureRect:
	var art := parent.get_node_or_null(node_name) as TextureRect
	if art == null:
		return _add_texture_art(parent, node_name, texture_path)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = TextureManager.try_load(texture_path)
	parent.move_child(art, 0)
	return art


func _style_paper_tag_button(button: Button, font_size: int) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.27, 0.15, 0.06))
	button.add_theme_color_override("font_hover_color", Color(0.16, 0.08, 0.03))
	button.add_theme_color_override("font_pressed_color", Color(0.12, 0.06, 0.02))
	var normal := _component_style(
		PAPER_TAG_BUTTON_NORMAL_TEXTURE,
		Vector4(40, 24, 40, 24),
		Vector4(32, 8, 20, 8),
		_paper_fallback(Color(0.64, 0.45, 0.20, 0.96), Color(0.19, 0.10, 0.04, 0.78))
	)
	var hover := _component_style(
		PAPER_TAG_BUTTON_HOVER_TEXTURE,
		Vector4(40, 24, 40, 24),
		Vector4(32, 8, 20, 8),
		_paper_fallback(Color(0.72, 0.52, 0.25, 0.96), Color(0.24, 0.12, 0.04, 0.84))
	)
	var pressed := _component_style(
		PAPER_TAG_BUTTON_PRESSED_TEXTURE,
		Vector4(40, 24, 40, 24),
		Vector4(32, 8, 20, 8),
		_paper_fallback(Color(0.42, 0.28, 0.12, 0.98), Color(0.13, 0.07, 0.03, 0.90))
	)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _component_style(texture_path: String, texture_margins: Vector4, content_margins: Vector4, fallback: StyleBox) -> StyleBox:
	var style := TextureManager.try_load_style_box(texture_path)
	if style == null:
		return fallback
	style.set_texture_margin(SIDE_LEFT, texture_margins.x)
	style.set_texture_margin(SIDE_TOP, texture_margins.y)
	style.set_texture_margin(SIDE_RIGHT, texture_margins.z)
	style.set_texture_margin(SIDE_BOTTOM, texture_margins.w)
	style.set_content_margin(SIDE_LEFT, content_margins.x)
	style.set_content_margin(SIDE_TOP, content_margins.y)
	style.set_content_margin(SIDE_RIGHT, content_margins.z)
	style.set_content_margin(SIDE_BOTTOM, content_margins.w)
	return style


func _paper_fallback(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	return style


func _on_extinguish_pressed() -> void:
	if _gm.has_method("finish_clean_table_inference"):
		_gm.finish_clean_table_inference()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/LedgerScreen.tscn")
