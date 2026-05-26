class_name EndingScreen
extends Node2D

var _npc_endings_list: VBoxContainer
var _gold_label: Label
var _rep_label: Label
var _title_label: Label

func _ready() -> void:
	_npc_endings_list = $Content/NPCEndingsList
	_gold_label = $Content/Stats/GoldLabel
	_rep_label = $Content/Stats/RepLabel
	_title_label = $Content/TitleLabel

	ThemeColors.style_header(_title_label, 36)
	_title_label.add_theme_constant_override("outline_size", 3)

	_gold_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_gold_label.add_theme_font_size_override("font_size", 20)
	_rep_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_rep_label.add_theme_font_size_override("font_size", 20)

	ThemeColors.style_button($Content/QuitBtn)
	ThemeColors.style_button($Content/RestartBtn)

	$Content/QuitBtn.pressed.connect(func(): get_tree().quit())
	$Content/RestartBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn"))

	var gm = get_node("/root/GameManager")
	if gm != null:
		gm.register_view(self)

	var bg_node = get_node_or_null("Background")
	if bg_node != null:
		var bg_tex = TextureManager.try_load("res://assets/textures/backgrounds/ending_bg.png")
		if bg_tex != null:
			bg_node.texture = bg_tex
		else:
			var grad = GradientTexture2D.new()
			grad.width = 1280; grad.height = 720
			var g = Gradient.new()
			g.colors = [Color(0.055, 0.047, 0.04), ThemeColors.BACKGROUND_DEEP]
			g.offsets = [0.0, 1.0]
			grad.gradient = g
			bg_node.texture = grad

func show_endings(gold: int, rep: int, npc_endings: Dictionary) -> void:
	_gold_label.text = "最终金币：" + str(gold)
	_rep_label.text = "最终声望：" + str(rep)

	for child in _npc_endings_list.get_children():
		child.queue_free()

	var divider = ColorRect.new()
	divider.color = Color(ThemeColors.AMBER_PRIMARY, 0.3)
	divider.custom_minimum_size = Vector2(0, 2)
	_npc_endings_list.add_child(divider)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_npc_endings_list.add_child(spacer)

	for npc_id in npc_endings:
		var ending: String = npc_endings[npc_id]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, 40)

		var name_label = Label.new()
		name_label.text = npc_id
		name_label.custom_minimum_size = Vector2(120, 0)
		name_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
		name_label.add_theme_font_size_override("font_size", 18)
		row.add_child(name_label)

		var ending_label = Label.new()
		ending_label.text = ending
		ending_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		ending_label.add_theme_font_size_override("font_size", 15)
		row.add_child(ending_label)

		_npc_endings_list.add_child(row)
