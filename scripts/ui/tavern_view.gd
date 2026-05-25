class_name TavernView
extends Node2D

var _bg_sprite: Sprite2D
var _customer_sprite: TextureRect
var _customer_name: Label
var _order_bubble: Label
var _timer_bar: ProgressBar
var _gold_label: Label
var _rep_label: Label
var _day_label: Label
var _menu_panel: Panel
var _message_label: Label
var _end_night_btn: Button
var _dialogue_overlay: ColorRect
var _gm

const NPC_TEXTURE_KEYS: Dictionary = {
	"ryan": "ryan_neutral",
	"mira": "mira_neutral",
}

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	_bg_sprite = $Background
	_customer_sprite = $CustomerArea/CustomerSprite
	_customer_name = $CustomerArea/CustomerName
	_order_bubble = $CustomerArea/OrderBubble
	_timer_bar = $CustomerArea/TimerBar
	_gold_label = $TopPanel/GoldLabel
	_rep_label = $TopPanel/ReputationLabel
	_day_label = $TopPanel/DayLabel
	_message_label = $BottomBar/MessageLabel
	_end_night_btn = $TopPanel/EndNightBtn
	_dialogue_overlay = $DialogueOverlay

	_menu_panel = $OverlayMenu
	$TopPanel/MenuButton.pressed.connect(_toggle_menu)
	$OverlayMenu/CloseBtn.pressed.connect(_toggle_menu)
	_menu_panel.visible = false

	_end_night_btn.pressed.connect(_on_end_night)

	_apply_theme()

	$BottomBar.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_theme() -> void:
	var bg_tex = TextureManager.try_load("res://assets/textures/backgrounds/tavern_bg.png")
	if bg_tex != null:
		_bg_sprite.texture = bg_tex
	else:
		var grad = GradientTexture2D.new()
		grad.width = 1280; grad.height = 720
		var g = Gradient.new()
		g.colors = [ThemeColors.BACKGROUND_DEEP, ThemeColors.SURFACE_LOW]
		g.offsets = [0.0, 1.0]
		grad.gradient = g
		_bg_sprite.texture = grad

	_customer_name.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_customer_name.add_theme_font_size_override("font_size", 18)
	_order_bubble.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_order_bubble.add_theme_font_size_override("font_size", 15)

	_gold_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_gold_label.add_theme_font_size_override("font_size", 16)
	_rep_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_rep_label.add_theme_font_size_override("font_size", 16)
	_day_label.add_theme_color_override("font_color", ThemeColors.TEXT_SUBTITLE)
	_day_label.add_theme_font_size_override("font_size", 15)

	ThemeColors.style_button($TopPanel/MenuButton, 14)
	ThemeColors.style_button(_end_night_btn, 14)

	var parchment_tex = ThemeColors._get().panel_parchment()
	if parchment_tex != null:
		_menu_panel.add_theme_stylebox_override("panel", parchment_tex)
	else:
		_menu_panel.add_theme_stylebox_override("panel", ThemeColors.parchment_panel())

	ThemeColors.style_button($OverlayMenu/TabBtns/BtnRecipes, 14)
	ThemeColors.style_button($OverlayMenu/TabBtns/BtnBackpack, 14)
	ThemeColors.style_button($OverlayMenu/CloseBtn, 14)

	var recipe_panel = $OverlayMenu/RecipePanel
	var backpack_panel = $OverlayMenu/BackpackPanel
	$OverlayMenu/TabBtns/BtnRecipes.pressed.connect(func(): recipe_panel.visible = true; backpack_panel.visible = false)
	$OverlayMenu/TabBtns/BtnBackpack.pressed.connect(func(): recipe_panel.visible = false; backpack_panel.visible = true)

	_gm.inventory_changed.connect(_on_inventory_changed)

	_message_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	_message_label.add_theme_font_size_override("font_size", 14)

	var patience_bg = TextureManager.try_load_style_box("res://assets/textures/ui/bar_patience_bg.png")
	var patience_fill = TextureManager.try_load_style_box("res://assets/textures/ui/bar_patience_fill.png")
	if patience_bg != null:
		_timer_bar.add_theme_stylebox_override("background", patience_bg)
	else:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(ThemeColors.SURFACE_HIGH, 0.8)
		sb.border_width_left = 1; sb.border_width_top = 1
		sb.border_width_right = 1; sb.border_width_bottom = 1
		sb.border_color = ThemeColors.PANEL_BORDER
		_timer_bar.add_theme_stylebox_override("background", sb)
	if patience_fill != null:
		_timer_bar.add_theme_stylebox_override("fill", patience_fill)
	_timer_bar.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)

	var top_bar_tex = ThemeColors._get().bar_top_panel()
	var top_panel_bg = get_node_or_null("TopPanelBg")
	if top_panel_bg != null:
		if top_bar_tex != null:
			top_panel_bg.add_theme_stylebox_override("panel", top_bar_tex)
		else:
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(ThemeColors.BACKGROUND_DEEP, 0.85)
			sb.border_width_bottom = 1
			sb.border_color = ThemeColors.PANEL_BORDER
			top_panel_bg.add_theme_stylebox_override("panel", sb)

	var shortcut_bg_tex = ThemeColors._get().bar_shortcut_bg()
	var shortcut_bg = get_node_or_null("ShortcutBarBg")
	if shortcut_bg != null:
		if shortcut_bg_tex != null:
			shortcut_bg.add_theme_stylebox_override("panel", shortcut_bg_tex)
		else:
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(ThemeColors.SURFACE_LOW, 0.8)
			sb.border_width_top = 1
			sb.border_color = ThemeColors.PANEL_BORDER
			shortcut_bg.add_theme_stylebox_override("panel", sb)

func show_customer(name: String, order: String, npc_id: String = "guest") -> void:
	var tex_key: String = NPC_TEXTURE_KEYS.get(npc_id, npc_id)
	var tex = TextureManager.try_load("res://assets/textures/characters/" + tex_key + ".png")
	if tex != null:
		_customer_sprite.texture = tex
		_customer_sprite.modulate = Color.WHITE
	else:
		var grad = GradientTexture2D.new()
		grad.width = 200; grad.height = 250
		var g = Gradient.new()
		g.colors = [Color(0.35, 0.25, 0.4), Color(0.2, 0.15, 0.25)]
		g.offsets = [0.0, 1.0]
		grad.gradient = g
		_customer_sprite.texture = grad
		_customer_sprite.modulate = Color.WHITE

	_customer_sprite.visible = true
	_customer_name.text = name
	_order_bubble.text = "「来一份" + order + "！」"
	_order_bubble.visible = true

func hide_customer() -> void:
	_customer_sprite.visible = false
	_customer_name.text = "等待中……"
	_order_bubble.visible = false

func update_timer(ratio: float) -> void:
	_timer_bar.value = ratio * 100.0

func update_top_bar(gold: int, rep: int, day: int, max_day: int) -> void:
	_gold_label.text = "金币：" + str(gold)
	_rep_label.text = "声望：" + str(rep)
	_day_label.text = "第%d/%d天" % [day, max_day]

func show_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)

func set_dialogue_mode(active: bool) -> void:
	_dialogue_overlay.visible = active

func _exit_tree() -> void:
	if _gm != null:
		_gm.inventory_changed.disconnect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if not is_instance_valid(self):
		return
	if _menu_panel.visible:
		_build_backpack_list()

func _toggle_menu() -> void:
	_menu_panel.visible = not _menu_panel.visible
	if _menu_panel.visible:
		_build_recipe_list()
		_build_backpack_list()

func _on_end_night() -> void:
	_gm.end_night()

func _build_recipe_list() -> void:
	var recipe_list = _menu_panel.get_node("RecipePanel/RecipeList")
	for child in recipe_list.get_children():
		child.queue_free()

	for key in _gm.Craft.items:
		var item_data: Dictionary = _gm.Craft.items[key]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.custom_minimum_size = Vector2(0, 32)

		var icon_tex = _gm.try_load_material_icon(key)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(32, 32)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)
		else:
			var col_arr = item_data.get("color", [])
			var mat_color = Colors.GRAY
			if col_arr is Array and col_arr.size() >= 3:
				mat_color = Color(col_arr[0], col_arr[1], col_arr[2])
			var box = ColorRect.new()
			box.color = mat_color
			box.custom_minimum_size = Vector2(36, 20)
			row.add_child(box)

		var price_str = ""
		if item_data.get("price", 0) > 0:
			price_str = str(item_data["price"]) + "金"
		var name_label = Label.new()
		name_label.text = " " + item_data.get("name", key) + "  " + price_str
		name_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		name_label.add_theme_font_size_override("font_size", 14)
		row.add_child(name_label)

		recipe_list.add_child(row)

func _build_backpack_list() -> void:
	var inventory: Dictionary = _gm.inventory
	var backpack_list = _menu_panel.get_node("BackpackPanel/BackpackList")
	for child in backpack_list.get_children():
		child.queue_free()

	for mat in inventory:
		var count: int = inventory[mat]
		if count <= 0:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.custom_minimum_size = Vector2(0, 32)
		row.set_meta("material_key", mat)

		var icon_tex = _gm.try_load_material_icon(mat)
		if icon_tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.custom_minimum_size = Vector2(32, 32)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex_rect)
		else:
			var mat_item: Dictionary = _gm.Craft.get_item(mat)
			var col_arr = mat_item.get("color", [])
			var mat_color = Colors.GRAY
			if col_arr is Array and col_arr.size() >= 3:
				mat_color = Color(col_arr[0], col_arr[1], col_arr[2])
			var box = ColorRect.new()
			box.color = mat_color
			box.custom_minimum_size = Vector2(36, 20)
			row.add_child(box)

		var mat_item2: Dictionary = _gm.Craft.get_item(mat)
		var display_name = mat_item2.get("name", mat)
		var label = Label.new()
		label.text = display_name + "  x" + str(count)
		label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)

		backpack_list.add_child(row)
