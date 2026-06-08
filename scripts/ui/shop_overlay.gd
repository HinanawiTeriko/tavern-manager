class_name ShopOverlay
extends Control

signal closed

const FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const SCENE_TEX := "res://assets/textures/daymap/shop_redesign/shop_scene.png"
const BOOK_TEX := "res://assets/textures/daymap/shop_redesign/shop_book.png"
const TAB_NORMAL := "res://assets/textures/daymap/shop_redesign/shop_tab_normal.png"
const TAB_SELECTED := "res://assets/textures/daymap/shop_redesign/shop_tab_selected.png"
const CARD_NORMAL := "res://assets/textures/daymap/shop_redesign/shop_item_card_normal.png"
const CARD_SELECTED := "res://assets/textures/daymap/shop_redesign/shop_item_card_selected.png"
const CARD_DISABLED := "res://assets/textures/daymap/shop_redesign/shop_item_card_disabled.png"
const BUTTON_NORMAL := "res://assets/textures/daymap/shop_redesign/shop_purchase_button_normal.png"
const BUTTON_DISABLED := "res://assets/textures/daymap/shop_redesign/shop_purchase_button_disabled.png"

const CATEGORIES := {
	"materials": "材料",
	"recipes": "配方",
	"abilities": "技法",
}

var _gm = null
var _ui_data: Dictionary = {}
var _active_category := "materials"
var _selected_key := ""
var _quantity := 0
var _items_by_category: Dictionary = {}

var _backdrop: TextureRect
var _book: TextureRect
var _tabs: HBoxContainer
var _grid: GridContainer
var _detail_title: Label
var _detail_desc: Label
var _detail_uses: Label
var _detail_state: Label
var _gold_label: Label
var _total_label: Label
var _qty_label: Label
var _purchase_btn: Button
var _minus_btn: Button
var _plus_btn: Button


func _ready() -> void:
	visible = false
	if _gm != null and get_child_count() == 0:
		_build()


func configure(game_manager) -> void:
	_gm = game_manager
	_load_ui_data()
	if is_inside_tree() and get_child_count() == 0:
		_build()


func open() -> void:
	visible = true
	if get_child_count() == 0:
		_build()
	_refresh_items()
	if _selected_key == "":
		_select_first_available()
	_sync()


func close() -> void:
	visible = false
	closed.emit()


func get_selected_key() -> String:
	return _selected_key


func get_quantity() -> int:
	return _quantity


func set_quantity(value: int) -> void:
	_quantity = maxi(0, value)
	_sync()


func select_category(category: String) -> void:
	if not CATEGORIES.has(category):
		return
	_active_category = category
	_selected_key = ""
	_quantity = 0
	_refresh_items()
	_select_first_available()
	_sync()


func select_item(key: String) -> void:
	_selected_key = key
	_quantity = 1 if _active_category == "materials" else 0
	_sync()


func purchase_selected() -> void:
	if _gm == null or _selected_key == "":
		return
	var success := false
	match _active_category:
		"materials":
			success = _gm.buy_material(_selected_key, _quantity, _discount())
		"recipes":
			success = _gm.buy_recipe_unlock(_selected_key)
		"abilities":
			success = _gm.buy_ability(_selected_key)
	if success:
		if _active_category == "materials":
			_quantity = 0
		_refresh_items()
		_sync()


func _load_ui_data() -> void:
	var file := FileAccess.open("res://data/shop_ui.json", FileAccess.READ)
	if file == null:
		_ui_data = {}
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_ui_data = parsed if parsed is Dictionary else {}


func _material_keys() -> Array:
	return _sorted_keys_from_ui("materials")


func _recipe_keys() -> Array:
	return _sorted_keys_from_ui("recipes")


func _ability_keys() -> Array:
	var keys := _sorted_keys_from_ui("abilities")
	if keys.is_empty() and _gm != null:
		keys = _gm.shop.get_ability_keys()
	return keys


func _sorted_keys_from_ui(section: String) -> Array:
	var rows: Array = _ui_data.get(section, []).duplicate()
	rows.sort_custom(func(a, b): return int(a.get("sort", 0)) < int(b.get("sort", 0)))
	var result := []
	for row in rows:
		result.append(String(row.get("key", "")))
	return result


func _meta_for(section: String, key: String) -> Dictionary:
	for row in _ui_data.get(section, []):
		if String(row.get("key", "")) == key:
			return row
	return {}


func _display_name(key: String) -> String:
	if _gm == null:
		return key
	var item: Dictionary = _gm.craft.get_item(key)
	if item.has("name"):
		return String(item["name"])
	if _active_category == "abilities":
		return _gm.shop.get_ability_name(key)
	var recipe: Dictionary = _gm.craft.recipes.get(key, {})
	return String(recipe.get("name", key))


func _uses_for_material(key: String) -> String:
	if _gm == null:
		return ""
	var names: Array[String] = []
	for product_key in _gm.craft.recipes.keys():
		var recipe: Dictionary = _gm.craft.recipes[product_key]
		var ingredients: Array = recipe.get("ingredients", [])
		if ingredients.has(key):
			names.append(String(recipe.get("name", product_key)))
	names.sort()
	return "可用于：" + "、".join(names) if not names.is_empty() else ""


func _price_for(key: String) -> int:
	if _gm == null:
		return 0
	match _active_category:
		"materials":
			return _gm.shop.get_material_price(key, _discount())
		"recipes":
			return _gm.shop.get_recipe_unlock_price(key)
		"abilities":
			return _gm.shop.get_ability_price(key)
	return 0


func _base_price_for(key: String) -> int:
	if _gm == null:
		return 0
	if _active_category == "materials":
		return _gm.shop.get_material_price(key)
	return _price_for(key)


func _discount() -> float:
	if _gm != null and _gm.is_mira_in_shop_today():
		return 0.8
	return 1.0


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = TextureRect.new()
	_backdrop.name = "SceneBackdrop"
	_backdrop.texture = TextureManager.try_load(SCENE_TEX)
	_backdrop.size = Vector2(1280, 720)
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_backdrop)

	_book = TextureRect.new()
	_book.name = "BookLayer"
	_book.texture = TextureManager.try_load(BOOK_TEX)
	_book.position = Vector2(140, 254)
	_book.size = Vector2(960, 416)
	_book.stretch_mode = TextureRect.STRETCH_SCALE
	_book.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_book)

	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.position = Vector2(172, 270)
	_tabs.size = Vector2(520, 56)
	_tabs.add_theme_constant_override("separation", 8)
	add_child(_tabs)
	for category in ["materials", "recipes", "abilities"]:
		var btn := Button.new()
		btn.name = {"materials": "MaterialsTab", "recipes": "RecipesTab", "abilities": "AbilitiesTab"}[category]
		btn.text = CATEGORIES[category]
		btn.custom_minimum_size = Vector2(168, 56)
		_style_tab(btn, false)
		btn.pressed.connect(select_category.bind(category))
		_tabs.add_child(btn)

	_grid = GridContainer.new()
	_grid.name = "ItemGrid"
	_grid.columns = 2
	_grid.position = Vector2(172, 338)
	_grid.size = Vector2(492, 240)
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 10)
	add_child(_grid)

	var detail := Control.new()
	detail.name = "Detail"
	detail.position = Vector2(708, 306)
	detail.size = Vector2(332, 260)
	add_child(detail)
	_detail_title = _add_label(detail, "Title", Vector2(0, 0), Vector2(332, 42), 22, ThemeColors.AMBER_PRIMARY)
	_detail_desc = _add_label(detail, "Description", Vector2(0, 52), Vector2(332, 56), 15, ThemeColors.TEXT_SUBTITLE)
	_detail_uses = _add_label(detail, "Uses", Vector2(0, 118), Vector2(332, 82), 15, ThemeColors.TEXT_LIGHT)
	_detail_state = _add_label(detail, "State", Vector2(0, 210), Vector2(332, 36), 15, ThemeColors.TEXT_DIM)

	var counter := Control.new()
	counter.name = "CounterBar"
	counter.position = Vector2(162, 628)
	counter.size = Vector2(920, 62)
	add_child(counter)
	_gold_label = _add_label(counter, "GoldLabel", Vector2(0, 8), Vector2(190, 40), 16, ThemeColors.TEXT_LIGHT)
	_total_label = _add_label(counter, "TotalLabel", Vector2(210, 8), Vector2(180, 40), 16, ThemeColors.AMBER_PRIMARY)
	_minus_btn = _make_small_button("MinusButton", "-")
	_minus_btn.position = Vector2(410, 8)
	_minus_btn.pressed.connect(func(): set_quantity(_quantity - 1))
	counter.add_child(_minus_btn)
	_qty_label = _add_label(counter, "QuantityLabel", Vector2(462, 8), Vector2(54, 40), 18, ThemeColors.AMBER_PRIMARY)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus_btn = _make_small_button("PlusButton", "+")
	_plus_btn.position = Vector2(522, 8)
	_plus_btn.pressed.connect(func(): set_quantity(_quantity + 1))
	counter.add_child(_plus_btn)
	_purchase_btn = _make_action_button("PurchaseButton", "购买")
	_purchase_btn.position = Vector2(608, 0)
	_purchase_btn.pressed.connect(purchase_selected)
	counter.add_child(_purchase_btn)
	var close_btn := _make_action_button("CloseButton", "离开")
	close_btn.position = Vector2(792, 0)
	close_btn.pressed.connect(close)
	counter.add_child(close_btn)


func _add_label(parent: Node, node_name: String, pos: Vector2, node_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = pos
	label.size = node_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_small_button(node_name: String, text_value: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.size = Vector2(44, 40)
	button.custom_minimum_size = button.size
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_stylebox_override("normal", _texture_style(BUTTON_NORMAL, 8, 6))
	button.add_theme_stylebox_override("hover", _texture_style(BUTTON_NORMAL, 8, 6))
	button.add_theme_stylebox_override("pressed", _texture_style(BUTTON_NORMAL, 8, 6))
	return button


func _make_action_button(node_name: String, text_value: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.size = Vector2(176, 56)
	button.custom_minimum_size = button.size
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	button.add_theme_color_override("font_disabled_color", ThemeColors.TEXT_DIM)
	button.add_theme_stylebox_override("normal", _texture_style(BUTTON_NORMAL, 16, 8))
	button.add_theme_stylebox_override("hover", _texture_style(BUTTON_NORMAL, 16, 8))
	button.add_theme_stylebox_override("pressed", _texture_style(BUTTON_NORMAL, 16, 8))
	button.add_theme_stylebox_override("disabled", _texture_style(BUTTON_DISABLED, 16, 8))
	return button


func _style_tab(button: Button, selected: bool) -> void:
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	var style_path := TAB_SELECTED if selected else TAB_NORMAL
	button.add_theme_stylebox_override("normal", _texture_style(style_path, 16, 6))
	button.add_theme_stylebox_override("hover", _texture_style(TAB_SELECTED, 16, 6))
	button.add_theme_stylebox_override("pressed", _texture_style(TAB_SELECTED, 16, 6))


func _texture_style(path: String, margin_x: int, margin_y: int) -> StyleBoxTexture:
	var style := TextureManager.try_load_style_box(path)
	if style == null:
		return StyleBoxTexture.new()
	style.set_content_margin(SIDE_LEFT, margin_x)
	style.set_content_margin(SIDE_RIGHT, margin_x)
	style.set_content_margin(SIDE_TOP, margin_y)
	style.set_content_margin(SIDE_BOTTOM, margin_y)
	return style


func _refresh_items() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_items_by_category = {
		"materials": _material_keys(),
		"recipes": _recipe_keys(),
		"abilities": _ability_keys(),
	}
	for category_btn in _tabs.get_children():
		var selected := (
			(category_btn.name == "MaterialsTab" and _active_category == "materials") or
			(category_btn.name == "RecipesTab" and _active_category == "recipes") or
			(category_btn.name == "AbilitiesTab" and _active_category == "abilities")
		)
		_style_tab(category_btn, selected)
	for key in _items_by_category.get(_active_category, []):
		var card := Button.new()
		card.name = "Item_%s" % key
		card.text = _card_text(key)
		card.custom_minimum_size = Vector2(232, 112)
		card.add_theme_font_override("font", FONT)
		card.add_theme_font_size_override("font_size", 14)
		card.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
		card.add_theme_color_override("font_disabled_color", ThemeColors.TEXT_DIM)
		card.add_theme_stylebox_override("normal", _texture_style(CARD_NORMAL, 12, 8))
		card.add_theme_stylebox_override("hover", _texture_style(CARD_SELECTED, 12, 8))
		card.add_theme_stylebox_override("pressed", _texture_style(CARD_SELECTED, 12, 8))
		card.add_theme_stylebox_override("disabled", _texture_style(CARD_DISABLED, 12, 8))
		card.pressed.connect(select_item.bind(key))
		_grid.add_child(card)


func _card_text(key: String) -> String:
	return "%s\n%s金" % [_display_name(key), str(_price_for(key))]


func _select_first_available() -> void:
	var keys: Array = _items_by_category.get(_active_category, [])
	if keys.is_empty():
		return
	_selected_key = String(keys[0])
	_quantity = 1 if _active_category == "materials" else 0


func _sync() -> void:
	if _gm == null or _selected_key == "":
		return
	_gold_label.text = "金币：" + str(_gm.economy.gold)
	_qty_label.text = str(_quantity)
	var price := _price_for(_selected_key)
	var total := price
	if _active_category == "materials":
		total = price * _quantity
	_total_label.text = "总价：" + str(total) + "金"
	_detail_title.text = _display_name(_selected_key)
	_detail_desc.text = _description_for(_selected_key)
	_detail_uses.text = _uses_for_selected(_selected_key)
	_detail_state.text = _state_for(_selected_key)
	var material_mode := _active_category == "materials"
	_minus_btn.visible = material_mode
	_plus_btn.visible = material_mode
	_qty_label.visible = material_mode
	_purchase_btn.disabled = _is_owned(_selected_key) or (material_mode and _quantity < 1)


func _description_for(key: String) -> String:
	return String(_meta_for(_active_category, key).get("description", ""))


func _uses_for_selected(key: String) -> String:
	if _active_category == "materials":
		return _uses_for_material(key)
	return String(_meta_for(_active_category, key).get("usage", ""))


func _state_for(key: String) -> String:
	if _active_category == "materials":
		var owned := "持有：" + str(_gm.inventory_sys.get_count(key))
		if _discount() < 1.0:
			return owned + "  米拉折扣：" + str(_base_price_for(key)) + "→" + str(_price_for(key)) + "金"
		return owned
	if _is_owned(key):
		return "已拥有" if _active_category == "recipes" else "已掌握"
	return "价格：" + str(_price_for(key)) + "金"


func _is_owned(key: String) -> bool:
	if _gm == null:
		return false
	if _active_category == "recipes":
		return _gm.craft.is_recipe_unlocked(key)
	if _active_category == "abilities":
		return _gm.is_ability_owned(key)
	return false
