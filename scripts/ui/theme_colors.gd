class_name ThemeColors
extends RefCounted

const AMBER_PRIMARY = Color(1.0, 0.741, 0.498)
const AMBER_BRIGHT = Color(1.0, 0.584, 0.0)
const AMBER_DARK = Color(0.8, 0.45, 0.0)
const TEXT_ON_AMBER = Color(0.294, 0.157, 0.0)

const BACKGROUND_DEEP = Color(0.086, 0.075, 0.067)
const SURFACE_LOW = Color(0.122, 0.106, 0.098)
const SURFACE_MID = Color(0.137, 0.122, 0.114)
const SURFACE_HIGH = Color(0.18, 0.161, 0.153)
const SURFACE_HIGHEST = Color(0.224, 0.204, 0.192)

const TEXT_LIGHT = Color(0.918, 0.882, 0.867)
const TEXT_SUBTITLE = Color(0.859, 0.761, 0.678)
const TEXT_DIM = Color(0.64, 0.553, 0.478)

const SUCCESS = Color(0.29, 0.55, 0.25)
const DANGER = Color(0.65, 0.15, 0.1)
const PANEL_BORDER = Color(0.333, 0.263, 0.204)

const MENU_BRUSH_PANEL := "res://assets/textures/ui/menu_brush_panel.png"
const MENU_BRUSH_BAND := "res://assets/textures/ui/menu_brush_band.png"
const MENU_BRUSH_TAB := "res://assets/textures/ui/menu_brush_tab.png"
const MENU_BRUSH_MARKER := "res://assets/textures/title/title_pixel_menu_marker.png"
const MENU_FONT_PATH := "res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"

static var _menu_font: Font = null


static func menu_font() -> Font:
	if _menu_font == null:
		_menu_font = load(MENU_FONT_PATH)
	return _menu_font


## 像素字菜单标签：统一字体 + 字号 + 颜色，用于设置面板等刷痕菜单。
static func style_brush_label(label: Label, font_size: int = 16, color: Color = TEXT_LIGHT) -> void:
	var font := menu_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

static var _inst: ThemeColors = null

var _cached_btn_wide_normal: StyleBoxTexture = null
var _cached_btn_wide_hover: StyleBoxTexture = null
var _cached_btn_wide_pressed: StyleBoxTexture = null
var _cached_btn_small_normal: StyleBoxTexture = null
var _cached_btn_small_hover: StyleBoxTexture = null
var _cached_btn_small_pressed: StyleBoxTexture = null
var _cached_slot_material: StyleBoxTexture = null
var _cached_slot_result: StyleBoxTexture = null
var _cached_slot_shortcut: StyleBoxTexture = null
var _cached_panel_parchment: StyleBoxTexture = null
var _cached_bar_shortcut_bg: StyleBoxTexture = null
var _cached_bar_top_panel: StyleBoxTexture = null

static func instance() -> ThemeColors:
	if _inst == null:
		_inst = ThemeColors.new()
	return _inst

static func button_normal(w: int = 2, w_bot: int = 4) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = AMBER_PRIMARY
	sb.border_width_left = w; sb.border_width_top = w
	sb.border_width_right = w; sb.border_width_bottom = w_bot
	sb.border_color = Color(0, 0, 0, 0.4)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	return sb

static func button_hover(w: int = 2, w_bot: int = 4) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = AMBER_BRIGHT
	sb.border_width_left = w; sb.border_width_top = w
	sb.border_width_right = w; sb.border_width_bottom = w_bot
	sb.border_color = Color(0, 0, 0, 0.5)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	return sb

static func button_pressed(w_top: int = 4, w: int = 2) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = AMBER_DARK
	sb.border_width_left = w; sb.border_width_top = w_top
	sb.border_width_right = w; sb.border_width_bottom = w
	sb.border_color = Color(0, 0, 0, 0.5)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	return sb

static func style_button(btn: Button, font_size: int = 16) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", TEXT_ON_AMBER)
	btn.add_theme_color_override("font_hover_color", TEXT_ON_AMBER)
	btn.add_theme_color_override("font_pressed_color", TEXT_ON_AMBER)
	var inst = instance()
	var tex_normal = inst._btn_wide_normal()
	var tex_hover = inst._btn_wide_hover()
	var tex_pressed = inst._btn_wide_pressed()
	if tex_normal != null and tex_hover != null and tex_pressed != null:
		btn.add_theme_stylebox_override("normal", tex_normal)
		btn.add_theme_stylebox_override("hover", tex_hover)
		btn.add_theme_stylebox_override("pressed", tex_pressed)
	else:
		btn.add_theme_stylebox_override("normal", button_normal())
		btn.add_theme_stylebox_override("hover", button_hover())
		btn.add_theme_stylebox_override("pressed", button_pressed())

static func style_small_button(btn: Button, font_size: int = 13) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", TEXT_ON_AMBER)
	btn.add_theme_color_override("font_hover_color", TEXT_ON_AMBER)
	btn.add_theme_color_override("font_pressed_color", TEXT_ON_AMBER)
	var inst = instance()
	var tex_normal = inst._btn_small_normal()
	var tex_hover = inst._btn_small_hover()
	var tex_pressed = inst._btn_small_pressed()
	if tex_normal != null and tex_hover != null and tex_pressed != null:
		btn.add_theme_stylebox_override("normal", tex_normal)
		btn.add_theme_stylebox_override("hover", tex_hover)
		btn.add_theme_stylebox_override("pressed", tex_pressed)
	else:
		btn.add_theme_stylebox_override("normal", button_normal(1, 2))
		btn.add_theme_stylebox_override("hover", button_hover(1, 2))
		btn.add_theme_stylebox_override("pressed", button_pressed(2, 1))


static func style_brush_panel(panel: Panel) -> void:
	var style = TextureManager.try_load_style_box(MENU_BRUSH_PANEL)
	panel.add_theme_stylebox_override("panel", style if style != null else _brush_fallback())


static func style_brush_button(button: Button, font_size: int = 16) -> void:
	_apply_brush_button_style(button, MENU_BRUSH_BAND, font_size)


static func style_brush_tab_button(button: Button, font_size: int = 14) -> void:
	_apply_brush_button_style(button, MENU_BRUSH_TAB, font_size)


static func set_brush_selected(button: Button, selected: bool) -> void:
	button.set_meta("brush_selected", selected)
	_sync_brush_marker(button)


static func _apply_brush_button_style(button: Button, texture_path: String, font_size: int) -> void:
	var loaded_style = TextureManager.try_load_style_box(texture_path)
	var style: StyleBox = loaded_style if loaded_style != null else _brush_fallback()
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var font := menu_font()
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT_LIGHT)
	button.add_theme_color_override("font_hover_color", AMBER_PRIMARY)
	button.add_theme_color_override("font_pressed_color", AMBER_BRIGHT)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM)
	if button.get_node_or_null("BrushHoverMarker") != null:
		return
	var marker := TextureRect.new()
	marker.name = "BrushHoverMarker"
	marker.texture = TextureManager.try_load(MENU_BRUSH_MARKER)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_SCALE
	marker.z_index = 1
	marker.visible = false
	button.add_child(marker)
	# 居中短下划线：按钮宽度的中间 40%，约 3px 高，随按钮实际尺寸缩放。
	marker.anchor_left = 0.3
	marker.anchor_right = 0.7
	marker.anchor_top = 1.0
	marker.anchor_bottom = 1.0
	marker.offset_left = 0.0
	marker.offset_right = 0.0
	marker.offset_top = -5.0
	marker.offset_bottom = -2.0
	button.mouse_entered.connect(_sync_brush_marker.bind(button))
	button.mouse_exited.connect(_sync_brush_marker.bind(button))


static func _sync_brush_marker(button: Button) -> void:
	var marker := button.get_node_or_null("BrushHoverMarker") as TextureRect
	if marker != null:
		marker.visible = bool(button.get_meta("brush_selected", false)) or button.is_hovered()


static func _brush_fallback() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(SURFACE_LOW, 0.95)
	return style


static func wood_panel() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(SURFACE_MID, 0.85)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = PANEL_BORDER
	return sb

static func parchment_panel() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.15, 0.11, 0.92)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(AMBER_PRIMARY, 0.25)
	return sb

static func style_header(label: Label, font_size: int = 28) -> void:
	label.add_theme_color_override("font_color", AMBER_PRIMARY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))

static func style_body(label: Label, font_size: int = 16) -> void:
	label.add_theme_color_override("font_color", TEXT_LIGHT)
	label.add_theme_font_size_override("font_size", font_size)

static func style_dim(label: Label, font_size: int = 14) -> void:
	label.add_theme_color_override("font_color", TEXT_SUBTITLE)
	label.add_theme_font_size_override("font_size", font_size)

# Cached texture accessors
func _btn_wide_normal() -> StyleBoxTexture:
	if _cached_btn_wide_normal == null:
		_cached_btn_wide_normal = TextureManager.try_load_style_box("res://assets/textures/ui/btn_wide_normal.png")
	return _cached_btn_wide_normal

func _btn_wide_hover() -> StyleBoxTexture:
	if _cached_btn_wide_hover == null:
		_cached_btn_wide_hover = TextureManager.try_load_style_box("res://assets/textures/ui/btn_wide_hover.png")
	return _cached_btn_wide_hover

func _btn_wide_pressed() -> StyleBoxTexture:
	if _cached_btn_wide_pressed == null:
		_cached_btn_wide_pressed = TextureManager.try_load_style_box("res://assets/textures/ui/btn_wide_pressed.png")
	return _cached_btn_wide_pressed

func _btn_small_normal() -> StyleBoxTexture:
	if _cached_btn_small_normal == null:
		_cached_btn_small_normal = TextureManager.try_load_style_box("res://assets/textures/ui/btn_small_normal.png")
	return _cached_btn_small_normal

func _btn_small_hover() -> StyleBoxTexture:
	if _cached_btn_small_hover == null:
		_cached_btn_small_hover = TextureManager.try_load_style_box("res://assets/textures/ui/btn_small_hover.png")
	return _cached_btn_small_hover

func _btn_small_pressed() -> StyleBoxTexture:
	if _cached_btn_small_pressed == null:
		_cached_btn_small_pressed = TextureManager.try_load_style_box("res://assets/textures/ui/btn_small_pressed.png")
	return _cached_btn_small_pressed

func slot_material() -> StyleBoxTexture:
	if _cached_slot_material == null:
		_cached_slot_material = TextureManager.try_load_style_box("res://assets/textures/ui/slot_material.png")
	return _cached_slot_material

func slot_result() -> StyleBoxTexture:
	if _cached_slot_result == null:
		_cached_slot_result = TextureManager.try_load_style_box("res://assets/textures/ui/slot_result.png")
	return _cached_slot_result

func slot_shortcut() -> StyleBoxTexture:
	if _cached_slot_shortcut == null:
		_cached_slot_shortcut = TextureManager.try_load_style_box("res://assets/textures/ui/slot_shortcut.png")
	return _cached_slot_shortcut

func panel_parchment() -> StyleBoxTexture:
	if _cached_panel_parchment == null:
		_cached_panel_parchment = TextureManager.try_load_style_box("res://assets/textures/ui/panel_parchment_9patch.png")
	return _cached_panel_parchment

func bar_shortcut_bg() -> StyleBoxTexture:
	if _cached_bar_shortcut_bg == null:
		_cached_bar_shortcut_bg = TextureManager.try_load_style_box("res://assets/textures/ui/bar_shortcut_bg.png")
	return _cached_bar_shortcut_bg

func bar_top_panel() -> StyleBoxTexture:
	if _cached_bar_top_panel == null:
		_cached_bar_top_panel = TextureManager.try_load_style_box("res://assets/textures/ui/bar_top_panel.png")
	return _cached_bar_top_panel
