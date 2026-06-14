extends "res://addons/dialogue_manager/example_balloon/example_balloon.gd"

const PANEL_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_panel.png"
const NAMEPLATE_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_nameplate.png"
const RESPONSE_NORMAL_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_response_normal.png"
const RESPONSE_HOVER_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_response_hover.png"
const RESPONSE_PRESSED_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_response_pressed.png"
const PROGRESS_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_progress_arrow.png"

@onready var _panel_container: PanelContainer = $Balloon/MarginContainer/PanelContainer
@onready var _outer_margin: MarginContainer = $Balloon/MarginContainer
@onready var _progress_art: TextureRect = $Balloon/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/Control/ProgressArt
@onready var _response_example: Button = $Balloon/ResponsesMenu/ResponseExample


func _ready() -> void:
	super._ready()
	_apply_project_dialogue_style()


func _process(_delta: float) -> void:
	var should_show_progress := (
		is_instance_valid(dialogue_line)
		and not dialogue_label.is_typing
		and dialogue_line.responses.size() == 0
		and not dialogue_line.has_tag("voice")
	)
	if progress != null:
		progress.visible = false
	if _progress_art != null:
		_progress_art.visible = should_show_progress


func _apply_project_dialogue_style() -> void:
	balloon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outer_margin.offset_left = 40.0
	_outer_margin.offset_right = -40.0
	_outer_margin.offset_top = -236.0
	_outer_margin.offset_bottom = -20.0

	_panel_container.add_theme_stylebox_override("panel", _texture_style(
		PANEL_TEXTURE,
		Vector4(96, 64, 96, 52),
		Vector4(96, 50, 96, 40)
	))

	var font := ThemeColors.menu_font()
	for label in [character_label, dialogue_label]:
		if font != null:
			label.add_theme_font_override("normal_font", font)
			label.add_theme_font_override("bold_font", font)
			label.add_theme_font_override("italics_font", font)
		label.add_theme_color_override("default_color", ThemeColors.TEXT_LIGHT)
		label.add_theme_color_override("font_outline_color", Color(0.015, 0.012, 0.01, 0.9))
		label.add_theme_constant_override("outline_size", 2)
		label.scroll_active = false

	character_label.custom_minimum_size = Vector2(360, 36)
	character_label.add_theme_font_size_override("normal_font_size", 18)
	character_label.add_theme_color_override("default_color", ThemeColors.AMBER_PRIMARY)
	character_label.add_theme_stylebox_override("normal", _texture_style(
		NAMEPLATE_TEXTURE,
		Vector4(56, 18, 56, 18),
		Vector4(28, 9, 28, 9)
	))

	dialogue_label.custom_minimum_size = Vector2(0, 104)
	dialogue_label.add_theme_font_size_override("normal_font_size", 20)

	_apply_response_button_style(_response_example)
	_setup_progress_art()


func _apply_response_button_style(button: Button) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.custom_minimum_size = Vector2(620, 56)
	button.add_theme_stylebox_override("normal", _texture_style(RESPONSE_NORMAL_TEXTURE, Vector4(60, 16, 60, 16), Vector4(34, 8, 34, 8)))
	button.add_theme_stylebox_override("hover", _texture_style(RESPONSE_HOVER_TEXTURE, Vector4(60, 16, 60, 16), Vector4(34, 8, 34, 8)))
	button.add_theme_stylebox_override("pressed", _texture_style(RESPONSE_PRESSED_TEXTURE, Vector4(60, 16, 60, 16), Vector4(34, 8, 34, 8)))
	button.add_theme_stylebox_override("focus", _texture_style(RESPONSE_HOVER_TEXTURE, Vector4(60, 16, 60, 16), Vector4(34, 8, 34, 8)))
	var font := ThemeColors.menu_font()
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", ThemeColors.AMBER_BRIGHT)
	button.add_theme_color_override("font_disabled_color", ThemeColors.TEXT_DIM)


func _setup_progress_art() -> void:
	progress.visible = false
	_progress_art.texture = TextureManager.try_load(PROGRESS_TEXTURE)
	_progress_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_progress_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_art.visible = false


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
