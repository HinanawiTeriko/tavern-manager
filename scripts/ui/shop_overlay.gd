class_name ShopOverlay
extends Control

signal closed

const FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const SCENE_TEX := "res://assets/textures/daymap/shop_redesign/shop_scene.png"
const BOOK_TEX := "res://assets/textures/daymap/shop_redesign/shop_book.png"
const BOOKMARK_MATERIALS_NORMAL := "res://assets/textures/daymap/shop_redesign/bookmark_materials_normal.png"
const BOOKMARK_MATERIALS_SELECTED := "res://assets/textures/daymap/shop_redesign/bookmark_materials_selected.png"
const BOOKMARK_RECIPES_NORMAL := "res://assets/textures/daymap/shop_redesign/bookmark_recipes_normal.png"
const BOOKMARK_RECIPES_SELECTED := "res://assets/textures/daymap/shop_redesign/bookmark_recipes_selected.png"
const BOOKMARK_ABILITIES_NORMAL := "res://assets/textures/daymap/shop_redesign/bookmark_abilities_normal.png"
const BOOKMARK_ABILITIES_SELECTED := "res://assets/textures/daymap/shop_redesign/bookmark_abilities_selected.png"
const ITEM_ROW_SELECTED := "res://assets/textures/daymap/shop_redesign/item_row_selected.png"
const ITEM_ROW_DISABLED := "res://assets/textures/daymap/shop_redesign/item_row_disabled.png"
const PURCHASE_SEAL_NORMAL := "res://assets/textures/daymap/shop_redesign/purchase_seal_normal.png"
const PURCHASE_SEAL_PRESSED := "res://assets/textures/daymap/shop_redesign/purchase_seal_pressed.png"
const PURCHASE_SEAL_DISABLED := "res://assets/textures/daymap/shop_redesign/purchase_seal_disabled.png"
const CLOSE_TAG_NORMAL := "res://assets/textures/daymap/shop_redesign/close_tag_normal.png"
const CLOSE_TAG_SELECTED := "res://assets/textures/daymap/shop_redesign/close_tag_selected.png"
const QUANTITY_ABACUS := "res://assets/textures/daymap/shop_redesign/quantity_abacus.png"
const STATUS_OWNED := "res://assets/textures/daymap/shop_redesign/status_owned.png"
const STATUS_DISCOUNT := "res://assets/textures/daymap/shop_redesign/status_discount.png"

const CATEGORIES := {
	"materials": "材料",
	"recipes": "配方",
	"abilities": "技法",
}

const ROW_SPACING := 60
const MAX_VISIBLE_ROWS := 5

var _gm = null
var _ui_data: Dictionary = {}
var _active_category := "materials"
var _selected_key := ""
var _quantity := 0
var _items_by_category: Dictionary = {}

var _backdrop: TextureRect
var _book: TextureRect
var _bookmarks: Control
var _bookmark_textures: Dictionary = {}
var _item_rows: Control
var _row_nodes: Dictionary = {}
var _detail_page: Control
var _coin_tray: Control
var _quantity_abacus: Control
var _purchase_seal: Control
var _close_tag: Control
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
var _seal_art: TextureRect
var _close_tag_art: TextureRect
var _owned_mark: TextureRect
var _discount_mark: TextureRect


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

	_backdrop = _add_texture(self, "SceneBackdrop", SCENE_TEX, Vector2.ZERO, Vector2(1280, 720))
	_book = _add_texture(self, "BookLayer", BOOK_TEX, Vector2(192, 120), Vector2(992, 416))

	_bookmarks = Control.new()
	_bookmarks.name = "CategoryBookmarks"
	_bookmarks.size = Vector2(1280, 720)
	add_child(_bookmarks)
	_add_bookmark("materials", "Materials", Vector2(416, 120), BOOKMARK_MATERIALS_NORMAL, BOOKMARK_MATERIALS_SELECTED)
	_add_bookmark("recipes", "Recipes", Vector2(568, 120), BOOKMARK_RECIPES_NORMAL, BOOKMARK_RECIPES_SELECTED)
	_add_bookmark("abilities", "Abilities", Vector2(720, 120), BOOKMARK_ABILITIES_NORMAL, BOOKMARK_ABILITIES_SELECTED)

	_item_rows = Control.new()
	_item_rows.name = "ItemRows"
	_item_rows.position = Vector2(352, 200)
	_item_rows.size = Vector2(464, 312)
	add_child(_item_rows)

	_detail_page = Control.new()
	_detail_page.name = "DetailPage"
	_detail_page.position = Vector2(680, 196)
	_detail_page.size = Vector2(380, 300)
	add_child(_detail_page)
	_detail_title = _add_label(_detail_page, "Title", Vector2(0, 0), Vector2(316, 40), 19, ThemeColors.AMBER_PRIMARY)
	_detail_desc = _add_label(_detail_page, "Description", Vector2(0, 54), Vector2(316, 64), 14, ThemeColors.TEXT_SUBTITLE)
	_detail_uses = _add_label(_detail_page, "Uses", Vector2(0, 126), Vector2(316, 78), 14, ThemeColors.TEXT_LIGHT)
	_detail_state = _add_label(_detail_page, "State", Vector2(0, 216), Vector2(316, 42), 14, ThemeColors.TEXT_DIM)
	_owned_mark = _add_texture(_detail_page, "OwnedMark", STATUS_OWNED, Vector2(8, 212), Vector2(160, 56))
	_discount_mark = _add_texture(_detail_page, "DiscountMark", STATUS_DISCOUNT, Vector2(96, 228), Vector2(160, 56))

	_coin_tray = Control.new()
	_coin_tray.name = "CoinTray"
	_coin_tray.position = Vector2(64, 548)
	_coin_tray.size = Vector2(320, 100)
	add_child(_coin_tray)
	_gold_label = _add_label(_coin_tray, "GoldLabel", Vector2(0, 0), Vector2(248, 38), 16, ThemeColors.TEXT_LIGHT)
	_total_label = _add_label(_coin_tray, "TotalLabel", Vector2(0, 42), Vector2(278, 38), 16, ThemeColors.AMBER_PRIMARY)

	_quantity_abacus = Control.new()
	_quantity_abacus.name = "QuantityAbacus"
	_quantity_abacus.position = Vector2(496, 520)
	_quantity_abacus.size = Vector2(192, 72)
	add_child(_quantity_abacus)
	_add_texture(_quantity_abacus, "AbacusArt", QUANTITY_ABACUS, Vector2.ZERO, Vector2(192, 72))
	_minus_btn = _make_input_zone("MinusZone", Vector2(60, 72))
	_minus_btn.pressed.connect(func(): set_quantity(_quantity - 1))
	_quantity_abacus.add_child(_minus_btn)
	_qty_label = _add_label(_quantity_abacus, "QuantityLabel", Vector2(62, 12), Vector2(68, 44), 18, ThemeColors.AMBER_PRIMARY)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus_btn = _make_input_zone("PlusZone", Vector2(60, 72))
	_plus_btn.position = Vector2(132, 0)
	_plus_btn.pressed.connect(func(): set_quantity(_quantity + 1))
	_quantity_abacus.add_child(_plus_btn)

	_purchase_seal = Control.new()
	_purchase_seal.name = "PurchaseSeal"
	_purchase_seal.position = Vector2(780, 544)
	_purchase_seal.size = Vector2(184, 72)
	add_child(_purchase_seal)
	_seal_art = _add_texture(_purchase_seal, "SealArt", PURCHASE_SEAL_NORMAL, Vector2.ZERO, Vector2(184, 72))
	_purchase_btn = _make_input_zone("PurchaseZone", Vector2(184, 72))
	_purchase_btn.button_down.connect(_set_purchase_pressed)
	_purchase_btn.button_up.connect(_sync)
	_purchase_btn.pressed.connect(purchase_selected)
	_purchase_seal.add_child(_purchase_btn)
	var purchase_label := _add_label(_purchase_seal, "PurchaseLabel", Vector2(32, 14), Vector2(120, 42), 16, ThemeColors.TEXT_LIGHT)
	purchase_label.text = "购买"
	purchase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_close_tag = Control.new()
	_close_tag.name = "CloseTag"
	_close_tag.position = Vector2(952, 536)
	_close_tag.size = Vector2(176, 104)
	add_child(_close_tag)
	_close_tag_art = _add_texture(_close_tag, "TagArt", CLOSE_TAG_NORMAL, Vector2.ZERO, Vector2(176, 64))
	var close_zone := _make_input_zone("CloseZone", Vector2(176, 104))
	close_zone.mouse_entered.connect(func(): _close_tag_art.texture = TextureManager.try_load(CLOSE_TAG_SELECTED))
	close_zone.mouse_exited.connect(func(): _close_tag_art.texture = TextureManager.try_load(CLOSE_TAG_NORMAL))
	close_zone.pressed.connect(close)
	_close_tag.add_child(close_zone)
	var close_label := _add_label(_close_tag, "CloseLabel", Vector2(24, 20), Vector2(120, 38), 16, ThemeColors.TEXT_LIGHT)
	close_label.text = "离开"
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _add_texture(parent: Node, node_name: String, path: String, pos: Vector2, node_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = TextureManager.try_load(path)
	rect.position = pos
	rect.size = node_size
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(rect)
	return rect


func _add_label(parent: Node, node_name: String, pos: Vector2, node_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = pos
	label.size = node_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_input_zone(node_name: String, node_size: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.size = node_size
	button.custom_minimum_size = node_size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _add_bookmark(category: String, title: String, pos: Vector2, normal_path: String, selected_path: String) -> void:
	var art := _add_texture(_bookmarks, title + "Art", normal_path, pos, Vector2(144, 64))
	var zone := _make_input_zone(title + "Zone", Vector2(144, 64))
	zone.position = pos
	zone.pressed.connect(select_category.bind(category))
	_bookmarks.add_child(zone)
	var label := _add_label(_bookmarks, title + "Label", pos + Vector2(18, 9), Vector2(108, 34), 15, ThemeColors.TEXT_LIGHT)
	label.text = CATEGORIES[category]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bookmark_textures[category] = {
		"art": art,
		"normal": normal_path,
		"selected": selected_path,
	}


func _refresh_items() -> void:
	for child in _item_rows.get_children():
		child.queue_free()
	_row_nodes.clear()
	_items_by_category = {
		"materials": _material_keys(),
		"recipes": _recipe_keys(),
		"abilities": _ability_keys(),
	}
	_sync_bookmarks()
	var index := 0
	for key in _items_by_category.get(_active_category, []):
		if index >= MAX_VISIBLE_ROWS:
			break
		_add_item_row(String(key), index)
		index += 1


func _sync_bookmarks() -> void:
	for category in _bookmark_textures.keys():
		var data: Dictionary = _bookmark_textures[category]
		var art := data["art"] as TextureRect
		var path := String(data["normal"])
		if category == _active_category:
			path = String(data["selected"])
		art.texture = TextureManager.try_load(path)


func _add_item_row(key: String, index: int) -> void:
	var row := Control.new()
	row.name = "Item_%s" % key
	row.position = Vector2(0, index * ROW_SPACING)
	row.size = Vector2(464, ROW_SPACING)
	_item_rows.add_child(row)
	var art := _add_texture(row, "RowArt", ITEM_ROW_SELECTED, Vector2.ZERO, Vector2(464, 72))
	art.visible = false
	var zone := _make_input_zone("ClickZone", Vector2(464, ROW_SPACING))
	zone.pressed.connect(select_item.bind(key))
	row.add_child(zone)
	var name_label := _add_label(row, "Name", Vector2(72, 8), Vector2(236, 30), 14, ThemeColors.TEXT_LIGHT)
	name_label.text = _display_name(key)
	var price_label := _add_label(row, "Price", Vector2(322, 8), Vector2(104, 30), 14, ThemeColors.AMBER_PRIMARY)
	price_label.text = str(_price_for(key)) + "金"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_row_nodes[key] = {"root": row, "art": art}


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
	_quantity_abacus.visible = material_mode
	_minus_btn.visible = material_mode
	_plus_btn.visible = material_mode
	_qty_label.visible = material_mode
	_purchase_btn.disabled = _is_owned(_selected_key) or (material_mode and _quantity < 1)
	_sync_bookmarks()
	_sync_rows()
	_owned_mark.visible = _active_category != "materials" and _is_owned(_selected_key)
	_discount_mark.visible = _active_category == "materials" and _discount() < 1.0
	_sync_purchase_seal()


func _sync_rows() -> void:
	for key in _row_nodes.keys():
		var data: Dictionary = _row_nodes[key]
		var art := data["art"] as TextureRect
		var owned := _active_category != "materials" and _is_owned(String(key))
		if owned:
			art.texture = TextureManager.try_load(ITEM_ROW_DISABLED)
			art.visible = true
		elif String(key) == _selected_key:
			art.texture = TextureManager.try_load(ITEM_ROW_SELECTED)
			art.visible = true
		else:
			art.visible = false


func _set_purchase_pressed() -> void:
	if _purchase_btn != null and not _purchase_btn.disabled:
		_seal_art.texture = TextureManager.try_load(PURCHASE_SEAL_PRESSED)


func _sync_purchase_seal() -> void:
	if _seal_art == null:
		return
	var path := PURCHASE_SEAL_NORMAL
	if _purchase_btn.disabled:
		path = PURCHASE_SEAL_DISABLED
	_seal_art.texture = TextureManager.try_load(path)


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
