class_name TitleScreen
extends Node2D

const TITLE_MENU_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")

var _motion_time: float = 0.0
var _menu_marker_tween: Tween = null

@onready var _glow_overlay: Sprite2D = $GlowOverlay
@onready var _logo: Sprite2D = $Logo
@onready var _menu_marker: TextureRect = $UI/MenuMarker


func _ready() -> void:
	var ambience = $Ambience
	ambience.star_color = Color(ThemeColors.AMBER_PRIMARY, 0.9)
	ambience.dust_color = ThemeColors.AMBER_PRIMARY

	var title = $UI/TitlePanel/TitleLabel
	ThemeColors.style_header(title, 48)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))

	var title_panel = $UI/TitlePanel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(ThemeColors.SURFACE_MID, 0.7)
	panel_style.border_width_left = 2; panel_style.border_width_top = 2
	panel_style.border_width_right = 2; panel_style.border_width_bottom = 2
	panel_style.border_color = Color(ThemeColors.AMBER_PRIMARY, 0.3)
	title_panel.add_theme_stylebox_override("panel", panel_style)

	var subtitle = $UI/SubtitleLabel
	subtitle.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	subtitle.add_theme_font_size_override("font_size", 18)

	var btn = $UI/StartButton
	_style_title_menu_button(btn)
	btn.pressed.connect(_on_new_game)

	var has_save: bool = GameManager.has_save()
	var continue_btn = get_node_or_null("UI/ContinueButton")
	if continue_btn != null:
		_style_title_menu_button(continue_btn)
		continue_btn.pressed.connect(GameManager.continue_game)
		continue_btn.disabled = not has_save
	var restart_btn = get_node_or_null("UI/RestartButton")
	if restart_btn != null:
		_style_title_menu_button(restart_btn)
		restart_btn.pressed.connect(GameManager.restart_current_day)
		restart_btn.disabled = not has_save
	var quit_btn = get_node_or_null("UI/QuitButton")
	if quit_btn != null:
		_style_title_menu_button(quit_btn)
		quit_btn.pressed.connect(get_tree().quit)

	var hint = $UI/HintLabel
	hint.add_theme_color_override("font_color", Color(ThemeColors.TEXT_LIGHT, 0.6))
	hint.add_theme_font_size_override("font_size", 14)

	var ver = $UI/VersionLabel
	ver.add_theme_font_override("font", TITLE_MENU_FONT)
	ver.add_theme_color_override("font_color", Color(ThemeColors.TEXT_SUBTITLE, 0.35))
	ver.add_theme_font_size_override("font_size", 12)

	_try_load_deco("Deco/CandleLeft", "res://assets/textures/ui/deco_candle_left.png")
	_try_load_deco("Deco/CandleRight", "res://assets/textures/ui/deco_candle_right.png")
	_try_load_deco("Deco/Mug", "res://assets/textures/ui/deco_mug.png")
	_try_load_deco("Deco/Emblem", "res://assets/textures/ui/deco_emblem.png")

	# 隐藏 TitleSign，避免占位符生成的 "TAVERN" 文字与中文标题重叠
	var title_sign = get_node_or_null("UI/TitlePanel/TitleSign")
	if title_sign != null:
		title_sign.visible = false


func _process(delta: float) -> void:
	_motion_time += delta
	_glow_overlay.modulate.a = 0.14 + sin(_motion_time * 2.1) * 0.025 + sin(_motion_time * 3.7) * 0.01
	_logo.position.y = 300.0 + sin(_motion_time * 0.9) * 1.0


func _style_title_menu_button(btn: Button) -> void:
	btn.add_theme_font_override("font", TITLE_MENU_FONT)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	btn.add_theme_color_override("font_hover_color", ThemeColors.AMBER_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", ThemeColors.AMBER_BRIGHT)
	btn.add_theme_color_override("font_disabled_color", Color(ThemeColors.TEXT_DIM, 0.55))
	var empty_style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("hover", empty_style)
	btn.add_theme_stylebox_override("pressed", empty_style)
	btn.add_theme_stylebox_override("disabled", empty_style)
	btn.mouse_entered.connect(_show_menu_marker.bind(btn))
	btn.mouse_exited.connect(_hide_menu_marker)


func _show_menu_marker(btn: Button) -> void:
	if btn.disabled:
		return
	_kill_marker_tween()
	_menu_marker.position = Vector2(1000.0, btn.position.y + 40.0)
	_menu_marker.modulate.a = 0.0
	_menu_marker.visible = true
	_menu_marker_tween = create_tween()
	_menu_marker_tween.tween_property(_menu_marker, "modulate:a", 0.8, 0.16)


func _hide_menu_marker() -> void:
	if not _menu_marker.visible:
		return
	_kill_marker_tween()
	_menu_marker_tween = create_tween()
	_menu_marker_tween.tween_property(_menu_marker, "modulate:a", 0.0, 0.12)
	_menu_marker_tween.tween_callback(func(): _menu_marker.visible = false)


func _kill_marker_tween() -> void:
	if _menu_marker_tween != null and _menu_marker_tween.is_valid():
		_menu_marker_tween.kill()
	_menu_marker_tween = null


func _try_load_deco(node_path: String, tex_path: String) -> void:
	var node = get_node_or_null(node_path)
	if node != null:
		var tex = TextureManager.try_load(tex_path)
		if tex != null:
			node.texture = tex

func _on_new_game() -> void:
	GameManager.new_game()
