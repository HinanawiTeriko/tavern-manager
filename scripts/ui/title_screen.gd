class_name TitleScreen
extends Node2D

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
	ThemeColors.style_button(btn, 22)
	btn.pressed.connect(_on_start)

	var hint = $UI/HintLabel
	hint.add_theme_color_override("font_color", Color(ThemeColors.TEXT_LIGHT, 0.6))
	hint.add_theme_font_size_override("font_size", 14)

	var ver = $UI/VersionLabel
	ver.add_theme_color_override("font_color", Color(ThemeColors.TEXT_SUBTITLE, 0.35))
	ver.add_theme_font_size_override("font_size", 11)

	_try_load_deco("Deco/CandleLeft", "res://assets/textures/ui/deco_candle_left.png")
	_try_load_deco("Deco/CandleRight", "res://assets/textures/ui/deco_candle_right.png")
	_try_load_deco("Deco/Mug", "res://assets/textures/ui/deco_mug.png")
	_try_load_deco("Deco/Emblem", "res://assets/textures/ui/deco_emblem.png")

	var title_sign = get_node_or_null("UI/TitlePanel/TitleSign")
	if title_sign != null:
		var sign_tex = TextureManager.try_load("res://assets/textures/ui/title_sign.png")
		if sign_tex != null:
			title_sign.texture = sign_tex

func _try_load_deco(node_path: String, tex_path: String) -> void:
	var node = get_node_or_null(node_path)
	if node != null:
		var tex = TextureManager.try_load(tex_path)
		if tex != null:
			node.texture = tex

func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/DayMap.tscn")
