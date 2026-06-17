extends "res://addons/dialogue_manager/example_balloon/example_balloon.gd"

const PANEL_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_panel.png"
const PANEL_RUNTIME_SIZE := Vector2(1200.0, 216.0)
const PANEL_TEXTURE_MARGINS := Vector4(96.0, 64.0, 96.0, 52.0)
const PANEL_CONTENT_MARGINS := Vector4(64.0, 32.0, 64.0, 32.0)

@onready var _panel_container: PanelContainer = $Balloon/MarginContainer/PanelContainer
@onready var _outer_margin: MarginContainer = $Balloon/MarginContainer
@onready var _panel_content_margin: MarginContainer = $Balloon/MarginContainer/PanelContainer/MarginContainer
@onready var _progress_art: TextureRect = $Balloon/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/Control/ProgressArt


func _ready() -> void:
	super._ready()
	_apply_project_dialogue_style()


func _process(_delta: float) -> void:
	if progress != null:
		progress.visible = false
	if _progress_art != null:
		_progress_art.visible = false


func _apply_project_dialogue_style() -> void:
	balloon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outer_margin.offset_left = 40.0
	_outer_margin.offset_right = -40.0
	_outer_margin.offset_top = -236.0
	_outer_margin.offset_bottom = -20.0
	_outer_margin.custom_minimum_size = PANEL_RUNTIME_SIZE
	_panel_container.custom_minimum_size = PANEL_RUNTIME_SIZE
	_clear_margin_container(_outer_margin)
	_clear_margin_container(_panel_content_margin)

	_panel_container.add_theme_stylebox_override("panel", _texture_style(
		PANEL_TEXTURE,
		PANEL_TEXTURE_MARGINS,
		PANEL_CONTENT_MARGINS
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
	character_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

	dialogue_label.custom_minimum_size = Vector2(0, 104)
	dialogue_label.add_theme_font_size_override("normal_font_size", 20)

	_setup_progress_art()


func _setup_progress_art() -> void:
	progress.visible = false
	_progress_art.texture = null
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


func _clear_margin_container(container: MarginContainer) -> void:
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		container.add_theme_constant_override("margin_" + _side_name(side), 0)


func _side_name(side: int) -> String:
	match side:
		SIDE_LEFT:
			return "left"
		SIDE_TOP:
			return "top"
		SIDE_RIGHT:
			return "right"
		_:
			return "bottom"
