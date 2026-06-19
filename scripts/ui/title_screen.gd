class_name TitleScreen
extends Node2D

const TITLE_MENU_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const LOGO_REST_Y := 360.0
const NATIVE_PIXEL_SCALE := 4.0
const GLOW_REST_A := 0.14

# 开场淡入时间线(秒)
const INTRO_BLACK_HOLD := 0.5   # 起始纯黑停顿
const INTRO_BG_FADE := 1.0      # 背景幕淡入
const INTRO_GAP_1 := 0.3        # 背景→Logo 停顿
const INTRO_LOGO_FADE := 1.0    # Logo 淡入
const INTRO_GAP_2 := 0.4        # Logo→菜单 停顿
const INTRO_MENU_FADE := 0.8    # 菜单幕淡入

var _motion_time: float = 0.0
var _menu_marker_tween: Tween = null
var _intro_active: bool = true
var _intro_tween: Tween = null

@onready var _background: Sprite2D = $Background
@onready var _ambience: Node2D = $Ambience
@onready var _glow_overlay: Sprite2D = $GlowOverlay
@onready var _logo: Sprite2D = $Logo
@onready var _menu_marker: TextureRect = $UI/MenuMarker
@onready var _settings_panel: SettingsPanel = $UI/SettingsPanel


func _ready() -> void:
	BGMManager.crossfade_to(preload("res://assets/audio/bgm/title.wav"))
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
	_settings_panel.configure(GameManager.settings)
	_settings_panel.tutorial_reset_requested.connect(_on_tutorial_reset_requested)
	var settings_btn = get_node_or_null("UI/SettingsButton")
	if settings_btn != null:
		_style_title_menu_button(settings_btn)
		settings_btn.pressed.connect(_settings_panel.open)
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

	# 隐藏 TitleSign，避免占位符生成的 "TAVERN" 文字与中文标题重叠
	var title_sign = get_node_or_null("UI/TitlePanel/TitleSign")
	if title_sign != null:
		title_sign.visible = false

	_play_intro()


func _process(delta: float) -> void:
	if _intro_active:
		return
	_motion_time += delta
	_glow_overlay.modulate.a = GLOW_REST_A + sin(_motion_time * 2.1) * 0.025 + sin(_motion_time * 3.7) * 0.01
	_logo.position.y = LOGO_REST_Y + roundf(sin(_motion_time * 0.9)) * NATIVE_PIXEL_SCALE


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
	_menu_marker.position = Vector2(
		btn.position.x + (btn.size.x - _menu_marker.size.x) * 0.5,
		btn.position.y + 40.0,
	)
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


func _on_tutorial_reset_requested() -> void:
	GameManager.reset_tutorial_progress()


func _menu_fade_nodes() -> Array:
	var names := [
		"UI/MenuBands", "UI/StartButton", "UI/ContinueButton",
		"UI/SettingsButton", "UI/QuitButton",
		"UI/SubtitleLabel", "UI/HintLabel", "UI/VersionLabel",
	]
	var nodes := []
	for n in names:
		var node = get_node_or_null(n)
		if node != null:
			nodes.append(node)
	return nodes


func _play_intro() -> void:
	# 初始态:背景幕/Logo/菜单全透明,黑底盖住一切
	_background.modulate.a = 0.0
	_ambience.modulate.a = 0.0
	_glow_overlay.modulate.a = 0.0
	_logo.modulate.a = 0.0
	var menu_nodes := _menu_fade_nodes()
	for node in menu_nodes:
		node.modulate.a = 0.0
	_set_menu_input(false)

	_intro_tween = create_tween()
	_intro_tween.tween_interval(INTRO_BLACK_HOLD)
	# 背景幕
	_intro_tween.tween_property(_background, "modulate:a", 1.0, INTRO_BG_FADE)
	_intro_tween.parallel().tween_property(_ambience, "modulate:a", 1.0, INTRO_BG_FADE)
	_intro_tween.parallel().tween_property(_glow_overlay, "modulate:a", GLOW_REST_A, INTRO_BG_FADE)
	_intro_tween.tween_interval(INTRO_GAP_1)
	# Logo
	_intro_tween.tween_property(_logo, "modulate:a", 1.0, INTRO_LOGO_FADE)
	_intro_tween.tween_interval(INTRO_GAP_2)
	# 菜单幕(并行)
	for i in menu_nodes.size():
		if i == 0:
			_intro_tween.tween_property(menu_nodes[i], "modulate:a", 1.0, INTRO_MENU_FADE)
		else:
			_intro_tween.parallel().tween_property(menu_nodes[i], "modulate:a", 1.0, INTRO_MENU_FADE)
	_intro_tween.chain().tween_callback(_finish_intro)


func _finish_intro() -> void:
	if not _intro_active:
		return
	_intro_active = false
	# 兜底:确保终态 alpha 全部就位
	_background.modulate.a = 1.0
	_ambience.modulate.a = 1.0
	_glow_overlay.modulate.a = GLOW_REST_A
	_logo.modulate.a = 1.0
	for node in _menu_fade_nodes():
		node.modulate.a = 1.0
	_set_menu_input(true)


func _set_menu_input(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for n in ["UI/StartButton", "UI/ContinueButton", "UI/SettingsButton", "UI/QuitButton"]:
		var btn = get_node_or_null(n)
		if btn != null:
			btn.mouse_filter = filter


func _unhandled_input(event: InputEvent) -> void:
	if not _intro_active:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventKey:
		pressed = event.pressed
	if not pressed:
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_finish_intro()
	get_viewport().set_input_as_handled()
