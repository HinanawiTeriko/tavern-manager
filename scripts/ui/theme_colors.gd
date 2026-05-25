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
