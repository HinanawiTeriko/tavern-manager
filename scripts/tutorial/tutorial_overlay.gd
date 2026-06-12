class_name TutorialOverlay
extends CanvasLayer

const TUTORIAL_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const PANEL_TEXTURE_PATH := "res://assets/textures/tutorial/ui/tutorial_panel.png"
const HIGHLIGHT_TEXTURE_PATH := "res://assets/textures/tutorial/ui/tutorial_highlight_frame.png"
const PANEL_TEXT_MARGIN_X := 56.0
const PANEL_TITLE_Y := 30.0
const PANEL_TITLE_HEIGHT := 24.0
const PANEL_TITLE_FONT_SIZE := 20
const PANEL_BODY_Y := 58.0
const PANEL_BOTTOM_MARGIN := 22.0
const PANEL_MIN_HEIGHT := 180.0
const PANEL_BODY_FONT_SIZE := 15
const PANEL_MEASURE_MAX_HEIGHT := 1200.0

var _highlight_panels: Array = [null, null, null, null]
var _highlight_frame: TextureRect
var _description_panel: Panel
var _description_label: RichTextLabel
var _title_label: Label
var _next_btn: Button
var _skip_btn: Button

var _tutorial_mgr
var _has_next: bool = false


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
	_highlight_frame.texture = _load_texture(HIGHLIGHT_TEXTURE_PATH)
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
		_highlight_frame.visible = w > 0.0 and h > 0.0

	var catcher := get_node_or_null("HighlightClickCatcher") as Control
	if catcher != null:
		catcher.position = Vector2(x, y)
		catcher.size = Vector2(w, h)

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


func hide_overlay() -> void:
	visible = false


func _on_next() -> void:
	if _tutorial_mgr != null:
		_tutorial_mgr.next_step()


func _on_skip() -> void:
	if _tutorial_mgr != null:
		_tutorial_mgr.skip_tutorial()
