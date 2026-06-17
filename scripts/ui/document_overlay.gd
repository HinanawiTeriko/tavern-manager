class_name DocumentOverlay
extends Control

signal closed()

const DOCUMENT_FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const LEDGER_BACKDROP_TEXTURE := "res://assets/textures/ledger/ui/ledger_overlay_backdrop.png"
const LEDGER_BUTTON_NAV_LEFT_NORMAL := "res://assets/textures/ledger/ui/button_nav_left_normal.png"
const LEDGER_BUTTON_NAV_LEFT_HOVER := "res://assets/textures/ledger/ui/button_nav_left_hover.png"
const LEDGER_BUTTON_NAV_LEFT_PRESSED := "res://assets/textures/ledger/ui/button_nav_left_pressed.png"
const LEDGER_BUTTON_NAV_RIGHT_NORMAL := "res://assets/textures/ledger/ui/button_nav_right_normal.png"
const LEDGER_BUTTON_NAV_RIGHT_HOVER := "res://assets/textures/ledger/ui/button_nav_right_hover.png"
const LEDGER_BUTTON_NAV_RIGHT_PRESSED := "res://assets/textures/ledger/ui/button_nav_right_pressed.png"
const LEDGER_BUTTON_CLOSE_NORMAL := "res://assets/textures/ledger/ui/button_close_normal.png"
const LEDGER_BUTTON_CLOSE_HOVER := "res://assets/textures/ledger/ui/button_close_hover.png"
const LEDGER_BUTTON_CLOSE_PRESSED := "res://assets/textures/ledger/ui/button_close_pressed.png"
const DOCUMENT_PANEL_POS := Vector2.ZERO
const DOCUMENT_PANEL_SIZE := Vector2(1280, 720)
const DOCUMENT_TITLE_POS := Vector2(520, 608)
const DOCUMENT_TITLE_SIZE := Vector2(240, 36)
const DOCUMENT_LEFT_BODY_POS := Vector2(280, 120)
const DOCUMENT_RIGHT_BODY_POS := Vector2(744, 120)
const DOCUMENT_BODY_SIZE := Vector2(256, 368)
const DOCUMENT_PAGE_LABEL_POS := Vector2(560, 552)
const DOCUMENT_PAGE_LABEL_SIZE := Vector2(160, 28)
const DOCUMENT_PREV_POS := Vector2(96, 300)
const DOCUMENT_NEXT_POS := Vector2(1072, 300)
const DOCUMENT_CLOSE_POS := Vector2(1100, 62)
const DOCUMENT_NAV_BUTTON_SIZE := Vector2(112, 120)
const DOCUMENT_CLOSE_BUTTON_SIZE := Vector2(96, 96)
const DOCUMENT_DRAG_THRESHOLD := 240.0
const LEDGER_INK := Color(0.16, 0.105, 0.062)

@onready var _title: Label = $Panel/Title
@onready var _panel: Panel = $Panel
@onready var _left_body: Label = $Panel/LeftBody
@onready var _right_body: Label = $Panel/RightBody
@onready var _page_label: Label = $Panel/PageLabel
@onready var _previous_button: Button = $Panel/PreviousBtn
@onready var _next_button: Button = $Panel/NextBtn
@onready var _close_button: Button = $Panel/CloseBtn

var _pages: Array = []
var _page_index: int = 0
var _kind: String = ""
var _document_id: String = ""
var _drag_start_x: float = -1.0


func _ready() -> void:
	_apply_document_art()
	_previous_button.pressed.connect(previous_page)
	_next_button.pressed.connect(next_page)
	_close_button.pressed.connect(close)
	_panel.gui_input.connect(_on_panel_gui_input)


func open_document(document: Dictionary) -> void:
	_title.text = String(document.get("title", "文档"))
	_document_id = String(document.get("id", ""))
	_kind = String(document.get("kind", "document"))
	_pages = document.get("pages", []).duplicate()
	if _pages.is_empty():
		_pages.append("")
	_page_index = 0
	_refresh_page()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func next_page() -> void:
	var step := _page_step()
	if _page_index + step < _pages.size():
		_page_index += step
		_refresh_page()
		GameManager.play_audio_event("page_turn")


func previous_page() -> void:
	if _page_index > 0:
		_page_index = maxi(0, _page_index - _page_step())
		_refresh_page()
		GameManager.play_audio_event("page_turn")


func get_current_page_text() -> String:
	return _left_body.text


func get_right_page_text() -> String:
	return _right_body.text


func _on_panel_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_drag_start_x = event.position.x
		return
	if _drag_start_x < 0.0:
		return
	var dragged: float = event.position.x - _drag_start_x
	_drag_start_x = -1.0
	if absf(dragged) < DOCUMENT_DRAG_THRESHOLD:
		return
	if dragged < 0.0:
		next_page()
	else:
		previous_page()


func _page_step() -> int:
	return 2 if _kind == "ledger" else 1


func _refresh_page() -> void:
	_apply_standard_document_layout()
	_left_body.text = String(_pages[_page_index])
	_right_body.visible = _kind == "ledger"
	_right_body.text = String(_pages[_page_index + 1]) if _kind == "ledger" and _page_index + 1 < _pages.size() else ""
	var last_visible_page := mini(_page_index + _page_step(), _pages.size())
	_page_label.text = "%d-%d / %d" % [_page_index + 1, last_visible_page, _pages.size()]
	_page_label.visible = true
	_previous_button.disabled = _page_index == 0
	_next_button.disabled = _page_index + _page_step() >= _pages.size()


func _apply_document_art() -> void:
	_ensure_ledger_backdrop()
	_panel.position = DOCUMENT_PANEL_POS
	_panel.size = DOCUMENT_PANEL_SIZE
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_style_label(_title, 20, ThemeColors.AMBER_PRIMARY)
	_title.add_theme_constant_override("outline_size", 2)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	_title.position = DOCUMENT_TITLE_POS
	_title.size = DOCUMENT_TITLE_SIZE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for body_label in [_left_body, _right_body]:
		_style_label(body_label, 16, LEDGER_INK)
		body_label.add_theme_constant_override("line_spacing", 4)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left_body.position = DOCUMENT_LEFT_BODY_POS
	_left_body.size = DOCUMENT_BODY_SIZE
	_right_body.position = DOCUMENT_RIGHT_BODY_POS
	_right_body.size = DOCUMENT_BODY_SIZE
	_style_label(_page_label, 14, ThemeColors.AMBER_PRIMARY)
	_page_label.add_theme_constant_override("outline_size", 1)
	_page_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.72))
	_page_label.position = DOCUMENT_PAGE_LABEL_POS
	_page_label.size = DOCUMENT_PAGE_LABEL_SIZE
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_document_button(
		_previous_button,
		"",
		DOCUMENT_PREV_POS,
		DOCUMENT_NAV_BUTTON_SIZE,
		LEDGER_BUTTON_NAV_LEFT_NORMAL,
		LEDGER_BUTTON_NAV_LEFT_HOVER,
		LEDGER_BUTTON_NAV_LEFT_PRESSED
	)
	_style_document_button(
		_next_button,
		"",
		DOCUMENT_NEXT_POS,
		DOCUMENT_NAV_BUTTON_SIZE,
		LEDGER_BUTTON_NAV_RIGHT_NORMAL,
		LEDGER_BUTTON_NAV_RIGHT_HOVER,
		LEDGER_BUTTON_NAV_RIGHT_PRESSED
	)
	_style_document_button(
		_close_button,
		"",
		DOCUMENT_CLOSE_POS,
		DOCUMENT_CLOSE_BUTTON_SIZE,
		LEDGER_BUTTON_CLOSE_NORMAL,
		LEDGER_BUTTON_CLOSE_HOVER,
		LEDGER_BUTTON_CLOSE_PRESSED
	)


func _ensure_ledger_backdrop() -> void:
	var backdrop := get_node_or_null("LedgerBackdrop") as TextureRect
	if backdrop == null:
		backdrop = TextureRect.new()
		backdrop.name = "LedgerBackdrop"
		add_child(backdrop)
		move_child(backdrop, 0)
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1280, 720)
	backdrop.texture = TextureManager.try_load(LEDGER_BACKDROP_TEXTURE)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_standard_document_layout() -> void:
	_title.position = DOCUMENT_TITLE_POS
	_title.size = DOCUMENT_TITLE_SIZE
	_left_body.position = DOCUMENT_LEFT_BODY_POS
	_left_body.size = DOCUMENT_BODY_SIZE
	_right_body.position = DOCUMENT_RIGHT_BODY_POS
	_right_body.size = DOCUMENT_BODY_SIZE
	_page_label.position = DOCUMENT_PAGE_LABEL_POS
	_page_label.size = DOCUMENT_PAGE_LABEL_SIZE


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_override("font", DOCUMENT_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


func _style_document_button(
	button: Button,
	text_value: String,
	pos: Vector2,
	size_value: Vector2,
	normal_path: String,
	hover_path: String,
	pressed_path: String
) -> void:
	button.text = text_value
	button.position = pos
	button.size = size_value
	button.custom_minimum_size = size_value
	button.add_theme_font_override("font", DOCUMENT_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", ThemeColors.TEXT_SUBTITLE)
	button.add_theme_color_override("font_disabled_color", ThemeColors.TEXT_DIM)
	button.add_theme_stylebox_override("normal", _document_button_style(normal_path))
	button.add_theme_stylebox_override("hover", _document_button_style(hover_path))
	button.add_theme_stylebox_override("pressed", _document_button_style(pressed_path))
	button.add_theme_stylebox_override("disabled", _document_button_style(normal_path))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _document_button_style(path: String) -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		return StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, 16.0)
	style.set_content_margin(SIDE_RIGHT, 16.0)
	style.set_content_margin(SIDE_TOP, 8.0)
	style.set_content_margin(SIDE_BOTTOM, 10.0)
	return style
