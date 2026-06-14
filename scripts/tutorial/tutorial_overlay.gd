class_name TutorialOverlay
extends CanvasLayer

const TUTORIAL_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const PANEL_TEXTURE_PATH := "res://assets/textures/tutorial/ui/tutorial_panel.png"
const DIALOGUE_PANEL_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_panel.png"
const DIALOGUE_PANEL_RUNTIME_SIZE := Vector2(1200.0, 216.0)
const DIALOGUE_PANEL_TEXTURE_MARGINS := Vector4(96.0, 64.0, 96.0, 52.0)
const DIALOGUE_PANEL_CONTENT_MARGINS := Vector4(64.0, 32.0, 64.0, 32.0)
const DEFAULT_NARRATOR_NAME := "薇拉"
const PANEL_TEXT_MARGIN_X := 56.0
const PANEL_TITLE_Y := 30.0
const PANEL_TITLE_HEIGHT := 24.0
const PANEL_TITLE_FONT_SIZE := 20
const PANEL_BODY_Y := 58.0
const PANEL_BOTTOM_MARGIN := 22.0
const PANEL_MIN_HEIGHT := 180.0
const PANEL_BODY_FONT_SIZE := 15
const PANEL_MEASURE_MAX_HEIGHT := 1200.0
const NARRATOR_TEXTURES := {
	"neutral": "res://assets/textures/characters/vera/vera_neutral.png",
	"smirk": "res://assets/textures/characters/vera/vera_smirk.png",
	"concerned": "res://assets/textures/characters/vera/vera_concerned.png",
	"surprised": "res://assets/textures/characters/vera/vera_surprised.png",
	"ledge": "res://assets/textures/characters/vera/vera_ledge.png",
}
const NARRATOR_DEFAULT_TEXTURE := "res://assets/textures/characters/vera/vera.png"
const NARRATOR_PORTRAIT_SIZE := Vector2(256.0, 320.0)
const NARRATOR_PANEL_HEIGHT := DIALOGUE_PANEL_RUNTIME_SIZE.y
const NARRATOR_PANEL_MAX_WIDTH := 900.0
const NARRATOR_PANEL_MIN_WIDTH := 480.0
const NARRATOR_MARGIN := 24.0
const NARRATOR_GAP := 20.0
const NARRATOR_LEDGE_OVERLAP := 20.0
const NARRATOR_BODY_FONT_SIZE := 18

var _highlight_panels: Array = [null, null, null, null]
var _highlight_frame: TextureRect
var _description_panel: Panel
var _description_label: RichTextLabel
var _title_label: Label
var _narrator_portrait: TextureRect
var _narrator_panel: Panel
var _narrator_name_label: RichTextLabel
var _narrator_label: RichTextLabel
var _narrator_progress_art: TextureRect
var _next_btn: Button
var _skip_btn: Button

var _tutorial_mgr
var _has_next: bool = false
var _narrator_lines: Array = []
var _narrator_line_index: int = 0
var _narrator_uses_ledge_pose: bool = false


func _ready() -> void:
	_tutorial_mgr = get_node_or_null("/root/TutorialManager")
	layer = 100
	_create_ui()
	visible = false


func _create_ui() -> void:
	for i in range(4):
		var panel := ColorRect.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(panel)
		_highlight_panels[i] = panel

	var highlight_click_catcher := ColorRect.new()
	highlight_click_catcher.name = "HighlightClickCatcher"
	highlight_click_catcher.color = Color(0, 0, 0, 0.05)
	highlight_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	highlight_click_catcher.z_index = 1
	add_child(highlight_click_catcher)

	_highlight_frame = TextureRect.new()
	_highlight_frame.name = "HighlightFrame"
	_highlight_frame.texture = null
	_highlight_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_highlight_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_highlight_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_highlight_frame.z_index = 2
	_highlight_frame.visible = false
	add_child(_highlight_frame)

	_description_panel = Panel.new()
	_description_panel.name = "DescriptionPanel"
	_description_panel.z_index = 10
	_description_panel.add_theme_stylebox_override("panel", _tutorial_panel_style())
	add_child(_description_panel)

	_description_label = RichTextLabel.new()
	_description_label.name = "DescriptionLabel"
	_description_label.bbcode_enabled = true
	_description_label.fit_content = false
	_description_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_description_label.clip_contents = true
	_description_label.scroll_active = false
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.add_theme_font_override("normal_font", TUTORIAL_FONT)
	_description_label.add_theme_font_size_override("normal_font_size", PANEL_BODY_FONT_SIZE)
	_description_label.add_theme_color_override("default_color", ThemeColors.TEXT_LIGHT)
	_description_panel.add_child(_description_label)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.z_index = 11
	_title_label.add_theme_font_override("font", TUTORIAL_FONT)
	_title_label.add_theme_font_size_override("font_size", PANEL_TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_title_label.add_theme_constant_override("outline_size", 2)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.68))
	add_child(_title_label)

	_narrator_portrait = TextureRect.new()
	_narrator_portrait.name = "NarratorPortrait"
	_narrator_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_narrator_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narrator_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_narrator_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_narrator_portrait.z_index = 9
	_narrator_portrait.visible = false
	add_child(_narrator_portrait)

	_narrator_panel = Panel.new()
	_narrator_panel.name = "NarratorPanel"
	_narrator_panel.z_index = 10
	_narrator_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_narrator_panel.add_theme_stylebox_override("panel", _narrator_panel_style())
	_narrator_panel.visible = false
	_narrator_panel.gui_input.connect(_on_narrator_panel_gui_input)
	add_child(_narrator_panel)

	_narrator_name_label = RichTextLabel.new()
	_narrator_name_label.name = "NarratorNameLabel"
	_narrator_name_label.bbcode_enabled = true
	_narrator_name_label.fit_content = false
	_narrator_name_label.scroll_active = false
	_narrator_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narrator_name_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_narrator_name_label.add_theme_font_override("normal_font", TUTORIAL_FONT)
	_narrator_name_label.add_theme_font_size_override("normal_font_size", 18)
	_narrator_name_label.add_theme_color_override("default_color", ThemeColors.AMBER_PRIMARY)
	_narrator_name_label.add_theme_color_override("font_outline_color", Color(0.015, 0.012, 0.01, 0.9))
	_narrator_name_label.add_theme_constant_override("outline_size", 2)
	_narrator_panel.add_child(_narrator_name_label)

	_narrator_label = RichTextLabel.new()
	_narrator_label.name = "NarratorLineLabel"
	_narrator_label.bbcode_enabled = true
	_narrator_label.fit_content = false
	_narrator_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_narrator_label.clip_contents = true
	_narrator_label.scroll_active = false
	_narrator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narrator_label.add_theme_font_override("normal_font", TUTORIAL_FONT)
	_narrator_label.add_theme_font_size_override("normal_font_size", NARRATOR_BODY_FONT_SIZE)
	_narrator_label.add_theme_color_override("default_color", ThemeColors.TEXT_LIGHT)
	_narrator_panel.add_child(_narrator_label)

	_narrator_progress_art = TextureRect.new()
	_narrator_progress_art.name = "NarratorProgressArt"
	_narrator_progress_art.texture = null
	_narrator_progress_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_narrator_progress_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narrator_progress_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_narrator_progress_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_narrator_progress_art.visible = false
	_narrator_panel.add_child(_narrator_progress_art)

	_next_btn = Button.new()
	_next_btn.name = "NextButton"
	_next_btn.custom_minimum_size = Vector2(150, 44)
	_next_btn.z_index = 12
	ThemeColors.style_brush_button(_next_btn, 16)
	_next_btn.pressed.connect(_on_next)
	add_child(_next_btn)

	_skip_btn = Button.new()
	_skip_btn.name = "SkipButton"
	_skip_btn.text = "跳过教程"
	_skip_btn.custom_minimum_size = Vector2(100, 34)
	_skip_btn.z_index = 12
	ThemeColors.style_brush_tab_button(_skip_btn, 12)
	_skip_btn.pressed.connect(_on_skip)
	add_child(_skip_btn)


func _load_texture(path: String) -> Texture2D:
	var texture := TextureManager.try_load(path)
	if texture != null:
		return texture
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return null
	var image_texture := ImageTexture.create_from_image(image)
	image_texture.resource_path = path
	return image_texture


func _tutorial_panel_style() -> StyleBox:
	var texture := _load_texture(PANEL_TEXTURE_PATH)
	if texture == null:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(ThemeColors.SURFACE_LOW, 0.95)
		fallback.border_color = Color(ThemeColors.AMBER_PRIMARY, 0.45)
		fallback.border_width_left = 2
		fallback.border_width_right = 2
		fallback.border_width_top = 2
		fallback.border_width_bottom = 2
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(0, 0, texture.get_width(), texture.get_height())
	style.set_content_margin(SIDE_LEFT, PANEL_TEXT_MARGIN_X)
	style.set_content_margin(SIDE_RIGHT, PANEL_TEXT_MARGIN_X)
	style.set_content_margin(SIDE_TOP, 42.0)
	style.set_content_margin(SIDE_BOTTOM, 24.0)
	return style


func _narrator_panel_style() -> StyleBox:
	return _texture_style(
		DIALOGUE_PANEL_TEXTURE,
		DIALOGUE_PANEL_TEXTURE_MARGINS,
		DIALOGUE_PANEL_CONTENT_MARGINS
	)


func _texture_style(path: String, texture_margins: Vector4, content_margins: Vector4) -> StyleBox:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = ThemeColors.SURFACE_LOW
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


func show_step(step: Dictionary, highlight_rect: Array, _has_prev: bool, has_next: bool) -> void:
	_has_next = has_next
	if highlight_rect.size() < 4:
		highlight_rect = [0, 0, 0, 0]

	var shadow := Color(0.0, 0.0, 0.0, 0.73)
	var border_w := 2.0
	var x: float = highlight_rect[0]
	var y: float = highlight_rect[1]
	var w: float = highlight_rect[2]
	var h: float = highlight_rect[3]
	var vs := get_viewport().get_visible_rect().size

	_highlight_panels[0].position = Vector2(0, 0)
	_highlight_panels[0].size = Vector2(vs.x, max(y - border_w, 0))
	_highlight_panels[0].color = shadow

	_highlight_panels[1].position = Vector2(0, y + h + border_w)
	_highlight_panels[1].size = Vector2(vs.x, max(vs.y - (y + h + border_w), 0))
	_highlight_panels[1].color = shadow

	_highlight_panels[2].position = Vector2(0, max(y - border_w, 0))
	_highlight_panels[2].size = Vector2(max(x - border_w, 0), min(h + border_w * 2, vs.y))
	_highlight_panels[2].color = shadow

	_highlight_panels[3].position = Vector2(x + w + border_w, max(y - border_w, 0))
	_highlight_panels[3].size = Vector2(max(vs.x - (x + w + border_w), 0), min(h + border_w * 2, vs.y))
	_highlight_panels[3].color = shadow

	if _highlight_frame != null:
		_highlight_frame.position = Vector2(x - 18.0, y - 18.0)
		_highlight_frame.size = Vector2(w + 36.0, h + 36.0)
		_highlight_frame.visible = false

	var catcher := get_node_or_null("HighlightClickCatcher") as Control
	if catcher != null:
		catcher.position = Vector2(x, y)
		catcher.size = Vector2(w, h)

	_narrator_lines = _read_narrator_lines(step)
	_narrator_line_index = 0
	if not _narrator_lines.is_empty():
		_show_narrator_step(step, highlight_rect, vs)
		visible = true
		return

	_hide_narrator()
	_description_panel.visible = true
	_title_label.visible = true
	_next_btn.visible = true

	var desc_x: float = step.get("desc_pos_x", 0.5)
	var desc_y: float = step.get("desc_pos_y", 0.75)
	var desc_w: float = step.get("desc_width", 420)
	var desc_h: float = step.get("desc_height", 140)
	var text_width = max(desc_w - PANEL_TEXT_MARGIN_X * 2.0, 48.0)
	_description_label.text = "[font_size=%d]%s[/font_size]" % [PANEL_BODY_FONT_SIZE, step.get("description", "")]
	_description_label.size = Vector2(text_width, PANEL_MEASURE_MAX_HEIGHT)
	var required_body_h := ceilf(_description_label.get_content_height())
	var required_panel_h := PANEL_BODY_Y + required_body_h + PANEL_BOTTOM_MARGIN
	var panel_h: float = maxf(maxf(desc_h, PANEL_MIN_HEIGHT), required_panel_h)

	var panel_x := vs.x * desc_x - desc_w / 2.0
	var panel_y := vs.y * desc_y
	var btn_next_y: float = panel_y + panel_h + 8.0

	var panel_bottom: float = panel_y + panel_h
	var btn_margin := 60.0
	if panel_bottom + btn_margin > vs.y:
		var overflow: float = panel_bottom + btn_margin - vs.y
		panel_y = max(4, panel_y - overflow)
		btn_next_y = panel_y + panel_h + 8.0

	panel_x = clamp(panel_x, 10, vs.x - desc_w - 10)

	_description_panel.position = Vector2(panel_x, panel_y)
	_description_panel.size = Vector2(desc_w, panel_h)

	_title_label.position = Vector2(panel_x + PANEL_TEXT_MARGIN_X, panel_y + PANEL_TITLE_Y)
	_title_label.size = Vector2(text_width, PANEL_TITLE_HEIGHT)
	_title_label.text = step.get("title", "")

	var body_height = max(panel_h - PANEL_BODY_Y - PANEL_BOTTOM_MARGIN, 24.0)
	_description_label.position = Vector2(PANEL_TEXT_MARGIN_X, PANEL_BODY_Y)
	_description_label.size = Vector2(text_width, body_height)

	_skip_btn.position = Vector2(vs.x - 120, 16)
	_next_btn.position = Vector2(vs.x * desc_x - 75, btn_next_y)
	_next_btn.text = "完成" if not has_next else "下一步"

	visible = true


func _read_narrator_lines(step: Dictionary) -> Array:
	var source = step.get("narrator_lines", [])
	if not (source is Array):
		return []
	var lines := []
	for line in source:
		if line is Dictionary and String(line.get("text", "")) != "":
			lines.append(line)
	return lines


func _show_narrator_step(step: Dictionary, highlight_rect: Array, viewport_size: Vector2) -> void:
	_description_panel.visible = false
	_title_label.visible = false
	_narrator_panel.visible = true
	_narrator_portrait.visible = true
	_next_btn.visible = false
	_layout_narrator(step, highlight_rect, viewport_size)
	_render_narrator_line()


func _hide_narrator() -> void:
	if _narrator_panel != null:
		_narrator_panel.visible = false
	if _narrator_portrait != null:
		_narrator_portrait.visible = false


func _layout_narrator(step: Dictionary, highlight_rect: Array, viewport_size: Vector2) -> void:
	var anchor := String(step.get("narrator_anchor", "auto"))
	if anchor == "" or anchor == "auto":
		anchor = _auto_narrator_anchor(highlight_rect, viewport_size)

	var portrait_size := NARRATOR_PORTRAIT_SIZE
	var panel_w := minf(DIALOGUE_PANEL_RUNTIME_SIZE.x, viewport_size.x)
	var panel_h := NARRATOR_PANEL_HEIGHT

	var panel_x := floorf((viewport_size.x - panel_w) * 0.5)
	var panel_y := 0.0 if anchor == "top" else viewport_size.y - panel_h
	var portrait_y := panel_y - portrait_size.y + NARRATOR_LEDGE_OVERLAP
	_narrator_uses_ledge_pose = anchor == "top"
	var portrait_x := _narrator_portrait_x(portrait_size, highlight_rect, viewport_size)
	if _narrator_uses_ledge_pose:
		portrait_x = clampf(
			viewport_size.x * 0.5 - portrait_size.x * 0.5,
			NARRATOR_MARGIN,
			maxf(NARRATOR_MARGIN, viewport_size.x - portrait_size.x - NARRATOR_MARGIN)
		)
		portrait_y = panel_y + panel_h - NARRATOR_LEDGE_OVERLAP
	_narrator_portrait.position = Vector2(portrait_x, portrait_y)
	_narrator_portrait.size = portrait_size
	_narrator_panel.position = Vector2(panel_x, panel_y)
	_narrator_panel.size = Vector2(panel_w, panel_h)
	_narrator_name_label.position = Vector2(34.0, 18.0)
	_narrator_name_label.size = Vector2(320.0, 36.0)
	_narrator_label.position = Vector2(34.0, 58.0)
	_narrator_label.size = Vector2(maxf(panel_w - 108.0, 32.0), panel_h - 78.0)
	_narrator_progress_art.position = Vector2(panel_w - 82.0, panel_h - 66.0)
	_narrator_progress_art.size = Vector2(64.0, 56.0)

	_skip_btn.position = Vector2(viewport_size.x - 120.0, 16.0)
	_next_btn.position = Vector2(panel_x + panel_w - 150.0, panel_y + panel_h + 8.0)
	if _next_btn.position.y + 44.0 > viewport_size.y - 4.0:
		_next_btn.position.y = viewport_size.y - 48.0


func _narrator_portrait_x(portrait_size: Vector2, highlight_rect: Array, viewport_size: Vector2) -> float:
	var min_x := NARRATOR_MARGIN
	var max_x := maxf(NARRATOR_MARGIN, viewport_size.x - portrait_size.x - NARRATOR_MARGIN)
	var candidates := [
		min_x,
		viewport_size.x * 0.5 - portrait_size.x * 0.5,
		max_x,
	]
	var best_x := min_x
	var best_overlap := INF
	for candidate in candidates:
		var x := clampf(float(candidate), min_x, max_x)
		var overlap := _rect_overlap_area(Rect2(Vector2(x, 0.0), portrait_size), highlight_rect)
		if overlap < best_overlap:
			best_x = x
			best_overlap = overlap
	return best_x


func _rect_overlap_area(rect: Rect2, highlight_rect: Array) -> float:
	if highlight_rect.size() < 4:
		return 0.0
	var hx: float = highlight_rect[0]
	var hy: float = highlight_rect[1]
	var hw: float = highlight_rect[2]
	var hh: float = highlight_rect[3]
	var overlap_w := maxf(0.0, minf(rect.position.x + rect.size.x, hx + hw) - maxf(rect.position.x, hx))
	var overlap_h := maxf(0.0, minf(rect.position.y + rect.size.y, hy + hh) - maxf(rect.position.y, hy))
	return overlap_w * overlap_h


func _auto_narrator_anchor(highlight_rect: Array, viewport_size: Vector2) -> String:
	if highlight_rect.size() < 4:
		return "bottom"
	var y: float = highlight_rect[1]
	if y > viewport_size.y * 0.55:
		return "top"
	return "bottom"


func _render_narrator_line() -> void:
	if _narrator_lines.is_empty():
		return
	var line: Dictionary = _narrator_lines[_narrator_line_index]
	var expression := String(line.get("expression", "neutral"))
	if _narrator_uses_ledge_pose:
		expression = "ledge"
	var texture_path := String(NARRATOR_TEXTURES.get(expression, NARRATOR_DEFAULT_TEXTURE))
	_narrator_portrait.texture = _load_texture(texture_path)
	_narrator_name_label.text = "[font_size=18]%s[/font_size]" % String(line.get("speaker", DEFAULT_NARRATOR_NAME))
	_narrator_label.text = "[font_size=%d]%s[/font_size]" % [
		NARRATOR_BODY_FONT_SIZE,
		String(line.get("text", ""))
	]
	_update_next_button_text()


func _update_next_button_text() -> void:
	if not _narrator_lines.is_empty() and _narrator_line_index < _narrator_lines.size() - 1:
		_next_btn.text = "继续"
		return
	_next_btn.text = "完成" if not _has_next else "下一步"


func hide_overlay() -> void:
	visible = false
	_narrator_lines.clear()
	_narrator_line_index = 0
	_next_btn.visible = true


func _on_next() -> void:
	if not _narrator_lines.is_empty() and _narrator_line_index < _narrator_lines.size() - 1:
		_narrator_line_index += 1
		_render_narrator_line()
		return
	if _tutorial_mgr != null:
		_tutorial_mgr.next_step()


func _on_narrator_panel_gui_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]
	if pressed:
		_on_next()
		get_viewport().set_input_as_handled()


func _on_skip() -> void:
	if _tutorial_mgr != null:
		_tutorial_mgr.skip_tutorial()
