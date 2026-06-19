class_name ShopOverlay
extends Control

signal closed

const FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const SHOP_BRUSH_BACKDROP := "res://assets/textures/daymap/shop_brush/shop_brush_backdrop.png"
const SHOP_BRUSH_PANEL_LIST := "res://assets/textures/daymap/shop_brush/shop_brush_panel_list.png"
const SHOP_BRUSH_PANEL_DETAIL := "res://assets/textures/daymap/shop_brush/shop_brush_panel_detail.png"
const SHOP_BRUSH_ROW_NORMAL := "res://assets/textures/daymap/shop_brush/shop_brush_row_normal.png"
const SHOP_BRUSH_ROW_HOVER := "res://assets/textures/daymap/shop_brush/shop_brush_row_hover.png"
const SHOP_BRUSH_ROW_SELECTED := "res://assets/textures/daymap/shop_brush/shop_brush_row_selected.png"
const SHOP_BRUSH_ROW_DISABLED := "res://assets/textures/daymap/shop_brush/shop_brush_row_disabled.png"
const SHOP_BRUSH_CATEGORY_NORMAL := "res://assets/textures/daymap/shop_brush/shop_brush_category_normal.png"
const SHOP_BRUSH_CATEGORY_SELECTED := "res://assets/textures/daymap/shop_brush/shop_brush_category_selected.png"
const SHOP_BRUSH_BUTTON_NORMAL := "res://assets/textures/daymap/shop_brush/shop_brush_button_normal.png"
const SHOP_BRUSH_BUTTON_HOVER := "res://assets/textures/daymap/shop_brush/shop_brush_button_hover.png"
const SHOP_BRUSH_BUTTON_PRESSED := "res://assets/textures/daymap/shop_brush/shop_brush_button_pressed.png"
const SHOP_BRUSH_BUTTON_DISABLED := "res://assets/textures/daymap/shop_brush/shop_brush_button_disabled.png"
const SHOP_BRUSH_CLOSE_NORMAL := "res://assets/textures/daymap/shop_brush/shop_brush_close_normal.png"
const SHOP_BRUSH_CLOSE_HOVER := "res://assets/textures/daymap/shop_brush/shop_brush_close_hover.png"
const SHOP_BRUSH_CLOSE_PRESSED := "res://assets/textures/daymap/shop_brush/shop_brush_close_pressed.png"
const SHOP_BRUSH_CHECKOUT_STRIP := "res://assets/textures/daymap/shop_brush/shop_brush_checkout_strip.png"
const SHOP_BRUSH_GOLD_AREA := "res://assets/textures/daymap/shop_brush/shop_brush_gold_area.png"
const SHOP_BRUSH_QUANTITY_MINUS := "res://assets/textures/daymap/shop_brush/shop_brush_quantity_minus.png"
const SHOP_BRUSH_QUANTITY_BODY := "res://assets/textures/daymap/shop_brush/shop_brush_quantity_body.png"
const SHOP_BRUSH_QUANTITY_PLUS := "res://assets/textures/daymap/shop_brush/shop_brush_quantity_plus.png"
const SHOP_BRUSH_STATUS_OWNED := "res://assets/textures/daymap/shop_brush/shop_brush_status_owned.png"
const SHOP_BRUSH_STATUS_DISCOUNT := "res://assets/textures/daymap/shop_brush/shop_brush_status_discount.png"
const SHOP_SCENE_V2_TEXTURE_DIR := "res://assets/textures/daymap/shop_scene_v2/"
const SHOP_SCENE_V2_BACKDROP := "res://assets/textures/daymap/shop_scene_v2/shop_scene_bg.png"
const SHOP_SCENE_V2_LIST_PANEL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_list_panel.png"
const SHOP_SCENE_V2_DETAIL_PANEL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_detail_panel.png"
const SHOP_SCENE_V2_CHECKOUT := "res://assets/textures/daymap/shop_scene_v2/shop_scene_checkout.png"
const SHOP_SCENE_V2_GOLD_AREA := "res://assets/textures/daymap/shop_scene_v2/shop_scene_gold_area.png"
const SHOP_SCENE_V2_TAB_MATERIALS_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_materials_normal.png"
const SHOP_SCENE_V2_TAB_MATERIALS_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_materials_hover.png"
const SHOP_SCENE_V2_TAB_MATERIALS_SELECTED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_materials_selected.png"
const SHOP_SCENE_V2_TAB_RECIPES_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_recipes_normal.png"
const SHOP_SCENE_V2_TAB_RECIPES_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_recipes_hover.png"
const SHOP_SCENE_V2_TAB_RECIPES_SELECTED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_recipes_selected.png"
const SHOP_SCENE_V2_TAB_ABILITIES_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_abilities_normal.png"
const SHOP_SCENE_V2_TAB_ABILITIES_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_abilities_hover.png"
const SHOP_SCENE_V2_TAB_ABILITIES_SELECTED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_tab_abilities_selected.png"
const SHOP_SCENE_V2_ROW_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_row_normal.png"
const SHOP_SCENE_V2_ROW_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_row_hover.png"
const SHOP_SCENE_V2_ROW_SELECTED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_row_selected.png"
const SHOP_SCENE_V2_ROW_DISABLED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_row_disabled.png"
const SHOP_SCENE_V2_BUTTON_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_button_normal.png"
const SHOP_SCENE_V2_BUTTON_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_button_hover.png"
const SHOP_SCENE_V2_BUTTON_PRESSED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_button_pressed.png"
const SHOP_SCENE_V2_BUTTON_DISABLED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_button_disabled.png"
const SHOP_SCENE_V2_QUANTITY_MINUS := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_minus.png"
const SHOP_SCENE_V2_QUANTITY_MINUS_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_minus_hover.png"
const SHOP_SCENE_V2_QUANTITY_MINUS_PRESSED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_minus_pressed.png"
const SHOP_SCENE_V2_QUANTITY_MINUS_DISABLED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_minus_disabled.png"
const SHOP_SCENE_V2_QUANTITY_BODY := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_body.png"
const SHOP_SCENE_V2_QUANTITY_PLUS := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_plus.png"
const SHOP_SCENE_V2_QUANTITY_PLUS_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_plus_hover.png"
const SHOP_SCENE_V2_QUANTITY_PLUS_PRESSED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_plus_pressed.png"
const SHOP_SCENE_V2_QUANTITY_PLUS_DISABLED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_quantity_plus_disabled.png"
const SHOP_SCENE_V2_CLOSE_NORMAL := "res://assets/textures/daymap/shop_scene_v2/shop_scene_close_normal.png"
const SHOP_SCENE_V2_CLOSE_HOVER := "res://assets/textures/daymap/shop_scene_v2/shop_scene_close_hover.png"
const SHOP_SCENE_V2_CLOSE_PRESSED := "res://assets/textures/daymap/shop_scene_v2/shop_scene_close_pressed.png"
const SHOP_SCENE_V2_STATUS_DISCOUNT := "res://assets/textures/daymap/shop_scene_v2/shop_scene_status_discount.png"
const SHOP_CLEAN_TEXTURE_DIR := "res://assets/textures/daymap/shop_clean/"
const SHOP_CLEAN_BACKDROP := "res://assets/textures/daymap/shop_clean/shop_clean_backdrop.png"
const SHOP_CLEAN_LIST_PANEL := "res://assets/textures/daymap/shop_clean/shop_clean_list_panel.png"
const SHOP_CLEAN_DETAIL_PAGE_BASE := "res://assets/textures/daymap/shop_clean/shop_clean_detail_page_base.png"
const SHOP_CLEAN_DETAIL_TITLE_SLIP := "res://assets/textures/daymap/shop_clean/shop_clean_detail_title_slip.png"
const SHOP_CLEAN_DETAIL_BODY_PANEL := "res://assets/textures/daymap/shop_clean/shop_clean_detail_body_panel.png"
const SHOP_CLEAN_DETAIL_USES_PANEL := "res://assets/textures/daymap/shop_clean/shop_clean_detail_uses_panel.png"
const SHOP_CLEAN_GOLD_TAG := "res://assets/textures/daymap/shop_clean/shop_clean_gold_tag.png"
const SHOP_CLEAN_TAB_NORMAL := "res://assets/textures/daymap/shop_clean/shop_clean_tab_normal.png"
const SHOP_CLEAN_TAB_HOVER := "res://assets/textures/daymap/shop_clean/shop_clean_tab_hover.png"
const SHOP_CLEAN_TAB_SELECTED := "res://assets/textures/daymap/shop_clean/shop_clean_tab_selected.png"
const SHOP_CLEAN_ITEM_ROW_NORMAL := "res://assets/textures/daymap/shop_clean/shop_clean_item_row_normal.png"
const SHOP_CLEAN_ITEM_ROW_HOVER := "res://assets/textures/daymap/shop_clean/shop_clean_item_row_hover.png"
const SHOP_CLEAN_ITEM_ROW_SELECTED := "res://assets/textures/daymap/shop_clean/shop_clean_item_row_selected.png"
const SHOP_CLEAN_ITEM_ROW_DISABLED := "res://assets/textures/daymap/shop_clean/shop_clean_item_row_disabled.png"
const SHOP_CLEAN_QUANTITY_MINUS_NORMAL := "res://assets/textures/daymap/shop_clean/shop_clean_quantity_button_minus_normal.png"
const SHOP_CLEAN_QUANTITY_MINUS_HOVER := "res://assets/textures/daymap/shop_clean/shop_clean_quantity_button_minus_hover.png"
const SHOP_CLEAN_QUANTITY_MINUS_DISABLED := "res://assets/textures/daymap/shop_clean/shop_clean_quantity_button_minus_disabled.png"
const SHOP_CLEAN_QUANTITY_BODY := "res://assets/textures/daymap/shop_clean/shop_clean_quantity_body.png"
const SHOP_CLEAN_QUANTITY_PLUS_NORMAL := "res://assets/textures/daymap/shop_clean/shop_clean_quantity_button_plus_normal.png"
const SHOP_CLEAN_QUANTITY_PLUS_HOVER := "res://assets/textures/daymap/shop_clean/shop_clean_quantity_button_plus_hover.png"
const SHOP_CLEAN_QUANTITY_PLUS_DISABLED := "res://assets/textures/daymap/shop_clean/shop_clean_quantity_button_plus_disabled.png"
const SHOP_CLEAN_PURCHASE_RECEIPT := "res://assets/textures/daymap/shop_clean/shop_clean_purchase_receipt.png"
const SHOP_CLEAN_PURCHASE_SEAL_NORMAL := "res://assets/textures/daymap/shop_clean/shop_clean_purchase_seal_normal.png"
const SHOP_CLEAN_PURCHASE_SEAL_HOVER := "res://assets/textures/daymap/shop_clean/shop_clean_purchase_seal_hover.png"
const SHOP_CLEAN_PURCHASE_SEAL_PRESSED := "res://assets/textures/daymap/shop_clean/shop_clean_purchase_seal_pressed.png"
const SHOP_CLEAN_PURCHASE_SEAL_DISABLED := "res://assets/textures/daymap/shop_clean/shop_clean_purchase_seal_disabled.png"
const SHOP_CLEAN_CLOSE_TAG_NORMAL := "res://assets/textures/daymap/shop_clean/shop_clean_close_tag_normal.png"
const SHOP_CLEAN_CLOSE_TAG_HOVER := "res://assets/textures/daymap/shop_clean/shop_clean_close_tag_hover.png"

const CATEGORIES := {
	"materials": "材料",
	"recipes": "配方",
	"abilities": "技法",
}

const ROW_SPACING := 70
const MAX_VISIBLE_ROWS := 5

var _gm = null
var _ui_data: Dictionary = {}
var _active_category := "materials"
var _selected_key := ""
var _quantity := 0
var _items_by_category: Dictionary = {}
var _page_offsets: Dictionary = {"materials": 0, "recipes": 0, "abilities": 0}
var _runtime_texture_cache: Dictionary = {}

var _backdrop: TextureRect
var _main_panel: Control
var _bookmarks: Control
var _bookmark_textures: Dictionary = {}
var _item_rows: Control
var _row_nodes: Dictionary = {}
var _item_page_up: Control
var _item_page_down: Control
var _item_page_indicator: Label
var _item_page_up_btn: Button
var _item_page_down_btn: Button
var _item_page_up_art: TextureRect
var _item_page_down_art: TextureRect
var _detail_page: Control
var _coin_tray: Control
var _quantity_control: Control
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
var _minus_art: TextureRect
var _plus_art: TextureRect
var _seal_art: TextureRect
var _close_tag_art: TextureRect
var _purchase_hovered := false
var _close_hovered := false
var _minus_hovered := false
var _plus_hovered := false
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
	_page_offsets[_active_category] = 0
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
	var keys := _sorted_keys_from_ui("recipes")
	if _gm != null and _gm.shop != null and _gm.shop.has_method("get_recipe_unlock_keys"):
		for key in _gm.shop.get_recipe_unlock_keys():
			var recipe_key := String(key)
			if recipe_key != "" and not keys.has(recipe_key):
				keys.append(recipe_key)
	return keys


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

	_backdrop = _add_texture(self, "ShopBackdrop", SHOP_CLEAN_BACKDROP, Vector2.ZERO, Vector2(1280, 720))

	_main_panel = Control.new()
	_main_panel.name = "MainBrushPanel"
	_main_panel.size = Vector2(1280, 720)
	add_child(_main_panel)
	_add_texture(_main_panel, "ListPanel", SHOP_CLEAN_LIST_PANEL, Vector2(56, 112), Vector2(680, 400))
	_add_texture(_main_panel, "DetailPanelArt", SHOP_CLEAN_DETAIL_PAGE_BASE, Vector2(804, 96), Vector2(432, 520))

	_bookmarks = Control.new()
	_bookmarks.name = "CategoryTabs"
	_bookmarks.size = Vector2(1280, 720)
	add_child(_bookmarks)
	_add_bookmark("materials", "Materials", Vector2(104, 64), SHOP_CLEAN_TAB_NORMAL, SHOP_CLEAN_TAB_HOVER, SHOP_CLEAN_TAB_SELECTED)
	_add_bookmark("recipes", "Recipes", Vector2(296, 64), SHOP_CLEAN_TAB_NORMAL, SHOP_CLEAN_TAB_HOVER, SHOP_CLEAN_TAB_SELECTED)
	_add_bookmark("abilities", "Abilities", Vector2(488, 64), SHOP_CLEAN_TAB_NORMAL, SHOP_CLEAN_TAB_HOVER, SHOP_CLEAN_TAB_SELECTED)

	_item_rows = Control.new()
	_item_rows.name = "ItemList"
	_item_rows.position = Vector2(104, 152)
	_item_rows.size = Vector2(580, 344)
	add_child(_item_rows)
	_build_item_page_controls()

	_detail_page = Control.new()
	_detail_page.name = "DetailPanel"
	_detail_page.position = Vector2(804, 96)
	_detail_page.size = Vector2(432, 520)
	add_child(_detail_page)
	var title_slip := _add_texture(_detail_page, "TitleSlipArt", SHOP_CLEAN_DETAIL_TITLE_SLIP, Vector2(32, 24), Vector2(368, 64))
	title_slip.visible = false
	var body_panel := _add_texture(_detail_page, "BodyPanelArt", SHOP_CLEAN_DETAIL_BODY_PANEL, Vector2(32, 84), Vector2(368, 208))
	body_panel.visible = false
	var uses_panel := _add_texture(_detail_page, "UsesPanelArt", SHOP_CLEAN_DETAIL_USES_PANEL, Vector2(32, 228), Vector2(368, 80))
	uses_panel.visible = false
	_detail_title = _add_label(_detail_page, "Title", Vector2(36, 36), Vector2(320, 44), 18, ThemeColors.AMBER_PRIMARY)
	_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_desc = _add_label(_detail_page, "Description", Vector2(36, 100), Vector2(320, 120), 14, ThemeColors.TEXT_SUBTITLE)
	_detail_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_detail_uses = _add_label(_detail_page, "Uses", Vector2(36, 244), Vector2(320, 64), 14, ThemeColors.TEXT_LIGHT)
	_detail_uses.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_detail_state = _add_label(_detail_page, "State", Vector2(36, 324), Vector2(320, 34), 14, ThemeColors.TEXT_DIM)
	_detail_state.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_owned_mark = _add_texture(_detail_page, "OwnedMark", "", Vector2(300, 314), Vector2(56, 48))
	_owned_mark.visible = false
	_discount_mark = _add_texture(_detail_page, "DiscountMark", SHOP_SCENE_V2_STATUS_DISCOUNT, Vector2(356, 314), Vector2(56, 52))

	_coin_tray = Control.new()
	_coin_tray.name = "CheckoutBar"
	_coin_tray.position = Vector2(804, 96)
	_coin_tray.size = Vector2(432, 520)
	add_child(_coin_tray)
	var gold_area_art := _add_texture(_coin_tray, "GoldAreaArt", SHOP_CLEAN_GOLD_TAG, Vector2(28, 368), Vector2(144, 56))
	gold_area_art.visible = false
	var receipt_strip := _add_texture(_coin_tray, "StripArt", SHOP_CLEAN_PURCHASE_RECEIPT, Vector2(244, 420), Vector2(256, 72))
	receipt_strip.visible = false
	_gold_label = _add_label(_coin_tray, "GoldLabel", Vector2(36, 380), Vector2(104, 30), 14, ThemeColors.TEXT_LIGHT)
	_total_label = _add_label(_coin_tray, "TotalLabel", Vector2(36, 412), Vector2(116, 30), 14, ThemeColors.AMBER_PRIMARY)

	_quantity_control = Control.new()
	_quantity_control.name = "QuantityControl"
	_quantity_control.position = Vector2(160, 408)
	_quantity_control.size = Vector2(108, 36)
	_coin_tray.add_child(_quantity_control)
	_minus_art = _add_texture(_quantity_control, "MinusArt", SHOP_CLEAN_QUANTITY_MINUS_NORMAL, Vector2.ZERO, Vector2(36, 36))
	_add_texture(_quantity_control, "BodyArt", SHOP_CLEAN_QUANTITY_BODY, Vector2(36, 0), Vector2(36, 36))
	_plus_art = _add_texture(_quantity_control, "PlusArt", SHOP_CLEAN_QUANTITY_PLUS_NORMAL, Vector2(72, 0), Vector2(36, 36))
	_minus_btn = _make_input_zone("MinusZone", Vector2(36, 36))
	_minus_btn.mouse_entered.connect(_set_quantity_hover.bind(false, true))
	_minus_btn.mouse_exited.connect(_set_quantity_hover.bind(false, false))
	_minus_btn.button_down.connect(_set_quantity_pressed.bind(false))
	_minus_btn.button_up.connect(_sync_quantity_button_art)
	_minus_btn.pressed.connect(func(): set_quantity(_quantity - 1))
	_quantity_control.add_child(_minus_btn)
	_qty_label = _add_label(_quantity_control, "QuantityLabel", Vector2(38, 4), Vector2(32, 26), 14, ThemeColors.AMBER_PRIMARY)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus_btn = _make_input_zone("PlusZone", Vector2(36, 36))
	_plus_btn.position = Vector2(72, 0)
	_plus_btn.mouse_entered.connect(_set_quantity_hover.bind(true, true))
	_plus_btn.mouse_exited.connect(_set_quantity_hover.bind(true, false))
	_plus_btn.button_down.connect(_set_quantity_pressed.bind(true))
	_plus_btn.button_up.connect(_sync_quantity_button_art)
	_plus_btn.pressed.connect(func(): set_quantity(_quantity + 1))
	_quantity_control.add_child(_plus_btn)

	_purchase_seal = Control.new()
	_purchase_seal.name = "PurchaseButton"
	_purchase_seal.position = Vector2(272, 404)
	_purchase_seal.size = Vector2(104, 96)
	_coin_tray.add_child(_purchase_seal)
	_seal_art = _add_texture(_purchase_seal, "ButtonArt", SHOP_CLEAN_PURCHASE_SEAL_NORMAL, Vector2.ZERO, Vector2(96, 96))
	_purchase_btn = _make_input_zone("PurchaseZone", Vector2(104, 96))
	_purchase_btn.mouse_entered.connect(func():
		_purchase_hovered = true
		_sync_purchase_seal()
	)
	_purchase_btn.mouse_exited.connect(func():
		_purchase_hovered = false
		_sync_purchase_seal()
	)
	_purchase_btn.button_down.connect(_set_purchase_pressed)
	_purchase_btn.button_up.connect(_sync_purchase_seal)
	_purchase_btn.pressed.connect(purchase_selected)
	_purchase_seal.add_child(_purchase_btn)
	var purchase_label := _add_label(_purchase_seal, "PurchaseLabel", Vector2(10, 16), Vector2(92, 36), 16, ThemeColors.TEXT_LIGHT)
	purchase_label.text = ""
	purchase_label.visible = false
	purchase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_close_tag = Control.new()
	_close_tag.name = "CloseButton"
	_close_tag.position = Vector2(352, 8)
	_close_tag.size = Vector2(80, 128)
	_coin_tray.add_child(_close_tag)
	_close_tag_art = _add_texture(_close_tag, "ButtonArt", SHOP_CLEAN_CLOSE_TAG_NORMAL, Vector2.ZERO, Vector2(80, 128))
	var close_zone := _make_input_zone("CloseZone", Vector2(80, 128))
	close_zone.mouse_entered.connect(func():
		_close_hovered = true
		_sync_close_tag()
	)
	close_zone.mouse_exited.connect(func():
		_close_hovered = false
		_sync_close_tag()
	)
	close_zone.button_down.connect(func(): _close_tag_art.texture = _load_texture(SHOP_CLEAN_CLOSE_TAG_HOVER))
	close_zone.button_up.connect(_sync_close_tag)
	close_zone.pressed.connect(close)
	_close_tag.add_child(close_zone)


func _add_texture(parent: Node, node_name: String, path: String, pos: Vector2, node_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = _load_texture(path) if path != "" else null
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.position = pos
	rect.size = node_size
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(rect)
	return rect


func _load_texture(path: String) -> Texture2D:
	var imported := TextureManager.try_load(path)
	if imported != null:
		return imported
	if not path.begins_with(SHOP_SCENE_V2_TEXTURE_DIR) and not path.begins_with(SHOP_CLEAN_TEXTURE_DIR):
		return null
	if _runtime_texture_cache.has(path):
		return _runtime_texture_cache[path] as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path(path)
	_runtime_texture_cache[path] = texture
	return texture


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


func _add_bookmark(category: String, title: String, pos: Vector2, normal_path: String, hover_path: String, selected_path: String) -> void:
	var art := _add_texture(_bookmarks, title + "Art", normal_path, pos, Vector2(168, 64))
	var zone := _make_input_zone(title + "Zone", Vector2(168, 64))
	zone.position = pos
	zone.mouse_entered.connect(_set_bookmark_hover.bind(category, true))
	zone.mouse_exited.connect(_set_bookmark_hover.bind(category, false))
	zone.pressed.connect(select_category.bind(category))
	_bookmarks.add_child(zone)
	var label := _add_label(_bookmarks, title + "Label", pos + Vector2(20, 16), Vector2(128, 28), 14, ThemeColors.TEXT_LIGHT)
	label.text = CATEGORIES[category]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bookmark_textures[category] = {
		"art": art,
		"normal": normal_path,
		"hover": hover_path,
		"selected": selected_path,
		"hovered": false,
	}


func _build_item_page_controls() -> void:
	_item_page_up = _new_page_control("ItemPageUp", Vector2(692, 160), "^")
	_item_page_up_art = _item_page_up.get_node_or_null("Art") as TextureRect
	_item_page_up_btn = _item_page_up.get_node_or_null("Zone") as Button
	if _item_page_up_btn != null:
		_item_page_up_btn.pressed.connect(_change_item_page.bind(-1))
	add_child(_item_page_up)

	_item_page_down = _new_page_control("ItemPageDown", Vector2(692, 438), "v")
	_item_page_down_art = _item_page_down.get_node_or_null("Art") as TextureRect
	_item_page_down_btn = _item_page_down.get_node_or_null("Zone") as Button
	if _item_page_down_btn != null:
		_item_page_down_btn.pressed.connect(_change_item_page.bind(1))
	add_child(_item_page_down)

	_item_page_indicator = _add_label(self, "ItemPageIndicator", Vector2(644, 484), Vector2(84, 22), 12, ThemeColors.TEXT_SUBTITLE)
	_item_page_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_page_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _new_page_control(node_name: String, pos: Vector2, text: String) -> Control:
	var control := Control.new()
	control.name = node_name
	control.position = pos
	control.size = Vector2(36, 36)
	var art := _add_texture(control, "Art", SHOP_CLEAN_QUANTITY_BODY, Vector2.ZERO, Vector2(36, 36))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _add_label(control, "Label", Vector2(0, 4), Vector2(36, 26), 14, ThemeColors.AMBER_PRIMARY)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zone := _make_input_zone("Zone", Vector2(36, 36))
	control.add_child(zone)
	return control


func _set_bookmark_hover(category: String, hovered: bool) -> void:
	if not _bookmark_textures.has(category):
		return
	var data: Dictionary = _bookmark_textures[category]
	data["hovered"] = hovered
	_bookmark_textures[category] = data
	_sync_bookmarks()


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
	_clamp_item_page_offset(_active_category)
	var visible_keys := _visible_keys_for_active_category()
	var index := 0
	for key in visible_keys:
		_add_item_row(String(key), index)
		index += 1
	_sync_item_page_controls()


func _visible_keys_for_active_category() -> Array:
	var keys: Array = _items_by_category.get(_active_category, [])
	var start := int(_page_offsets.get(_active_category, 0))
	var visible := []
	for index in range(start, mini(start + MAX_VISIBLE_ROWS, keys.size())):
		visible.append(keys[index])
	return visible


func _clamp_item_page_offset(category: String) -> void:
	var keys: Array = _items_by_category.get(category, [])
	var offset := int(_page_offsets.get(category, 0))
	var max_start := _max_page_start(keys.size())
	offset = clampi(offset, 0, max_start)
	_page_offsets[category] = offset


func _max_page_start(count: int) -> int:
	if count <= MAX_VISIBLE_ROWS:
		return 0
	return int(floor(float(count - 1) / float(MAX_VISIBLE_ROWS))) * MAX_VISIBLE_ROWS


func _change_item_page(direction: int) -> void:
	var keys: Array = _items_by_category.get(_active_category, [])
	if keys.size() <= MAX_VISIBLE_ROWS:
		return
	var current := int(_page_offsets.get(_active_category, 0))
	var next := clampi(current + direction * MAX_VISIBLE_ROWS, 0, _max_page_start(keys.size()))
	if next == current:
		return
	_page_offsets[_active_category] = next
	_refresh_items()
	var visible_keys := _visible_keys_for_active_category()
	if not visible_keys.has(_selected_key) and not visible_keys.is_empty():
		_selected_key = String(visible_keys[0])
		_quantity = 1 if _active_category == "materials" else 0
	_sync()


func _sync_item_page_controls() -> void:
	var keys: Array = _items_by_category.get(_active_category, [])
	var has_pages := keys.size() > MAX_VISIBLE_ROWS
	var offset := int(_page_offsets.get(_active_category, 0))
	var max_start := _max_page_start(keys.size())
	if _item_page_up != null:
		_item_page_up.visible = has_pages
	if _item_page_down != null:
		_item_page_down.visible = has_pages
	if _item_page_indicator != null:
		_item_page_indicator.visible = has_pages
		var page := int(floor(float(offset) / float(MAX_VISIBLE_ROWS))) + 1
		var page_count := int(floor(float(maxi(keys.size() - 1, 0)) / float(MAX_VISIBLE_ROWS))) + 1
		_item_page_indicator.text = "%d/%d" % [page, page_count]
	if _item_page_up_btn != null:
		_item_page_up_btn.disabled = not has_pages or offset <= 0
	if _item_page_down_btn != null:
		_item_page_down_btn.disabled = not has_pages or offset >= max_start
	if _item_page_up_art != null:
		_item_page_up_art.texture = _load_texture(SHOP_CLEAN_QUANTITY_MINUS_DISABLED if _item_page_up_btn != null and _item_page_up_btn.disabled else SHOP_CLEAN_QUANTITY_BODY)
	if _item_page_down_art != null:
		_item_page_down_art.texture = _load_texture(SHOP_CLEAN_QUANTITY_PLUS_DISABLED if _item_page_down_btn != null and _item_page_down_btn.disabled else SHOP_CLEAN_QUANTITY_BODY)


func _sync_bookmarks() -> void:
	for category in _bookmark_textures.keys():
		var data: Dictionary = _bookmark_textures[category]
		var art := data["art"] as TextureRect
		var path := String(data["normal"])
		if category == _active_category:
			path = String(data["selected"])
		elif bool(data.get("hovered", false)):
			path = String(data["hover"])
		art.texture = _load_texture(path)


func _add_item_row(key: String, index: int) -> void:
	var row := Control.new()
	row.name = "Item_%s" % key
	row.position = Vector2(0, index * ROW_SPACING)
	row.size = Vector2(580, 64)
	_item_rows.add_child(row)
	var art := _add_texture(row, "RowArt", SHOP_CLEAN_ITEM_ROW_NORMAL, Vector2.ZERO, Vector2(580, 64))
	var zone := _make_input_zone("ClickZone", Vector2(580, 64))
	zone.mouse_entered.connect(_set_row_hover.bind(key, true))
	zone.mouse_exited.connect(_set_row_hover.bind(key, false))
	zone.pressed.connect(select_item.bind(key))
	row.add_child(zone)
	var name_label := _add_label(row, "Name", Vector2(76, 11), Vector2(300, 34), 14, ThemeColors.TEXT_LIGHT)
	name_label.text = _display_name(key)
	var price_label := _add_label(row, "Price", Vector2(448, 11), Vector2(108, 34), 14, ThemeColors.AMBER_PRIMARY)
	price_label.text = str(_price_for(key)) + "金"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_row_nodes[key] = {"root": row, "art": art, "hover": false}


func _select_first_available() -> void:
	var keys: Array = _visible_keys_for_active_category()
	if keys.is_empty():
		keys = _items_by_category.get(_active_category, [])
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
	_quantity_control.visible = material_mode
	_minus_btn.visible = material_mode
	_plus_btn.visible = material_mode
	_qty_label.visible = material_mode
	_sync_quantity_button_art()
	_purchase_btn.disabled = _is_owned(_selected_key) or (material_mode and _quantity < 1)
	_sync_bookmarks()
	_sync_rows()
	_owned_mark.visible = false
	_discount_mark.visible = _active_category == "materials" and _discount() < 1.0
	_sync_purchase_seal()


func _sync_rows() -> void:
	for key in _row_nodes.keys():
		var data: Dictionary = _row_nodes[key]
		var art := data["art"] as TextureRect
		var owned := _active_category != "materials" and _is_owned(String(key))
		if owned:
			art.texture = _load_texture(SHOP_CLEAN_ITEM_ROW_DISABLED)
		elif String(key) == _selected_key:
			art.texture = _load_texture(SHOP_CLEAN_ITEM_ROW_SELECTED)
		elif bool(data.get("hover", false)):
			art.texture = _load_texture(SHOP_CLEAN_ITEM_ROW_HOVER)
		else:
			art.texture = _load_texture(SHOP_CLEAN_ITEM_ROW_NORMAL)


func _set_row_hover(key: String, hovered: bool) -> void:
	if not _row_nodes.has(key):
		return
	var data: Dictionary = _row_nodes[key]
	data["hover"] = hovered
	_row_nodes[key] = data
	_sync_rows()


func _set_quantity_hover(is_plus: bool, hovered: bool) -> void:
	if is_plus:
		_plus_hovered = hovered
	else:
		_minus_hovered = hovered
	_sync_quantity_button_art()


func _set_quantity_pressed(is_plus: bool) -> void:
	var button := _plus_btn if is_plus else _minus_btn
	var art := _plus_art if is_plus else _minus_art
	if button == null or art == null or button.disabled:
		return
	art.texture = _load_texture(SHOP_CLEAN_QUANTITY_PLUS_HOVER if is_plus else SHOP_CLEAN_QUANTITY_MINUS_HOVER)


func _sync_quantity_button_art() -> void:
	if _minus_art == null or _plus_art == null or _minus_btn == null or _plus_btn == null:
		return
	var material_mode := _quantity_control != null and _quantity_control.visible
	_minus_btn.disabled = not material_mode or _quantity <= 0
	_plus_btn.disabled = not material_mode
	_minus_art.texture = _load_texture(_quantity_state_path(false))
	_plus_art.texture = _load_texture(_quantity_state_path(true))


func _quantity_state_path(is_plus: bool) -> String:
	var button := _plus_btn if is_plus else _minus_btn
	var hovered := _plus_hovered if is_plus else _minus_hovered
	if button != null and button.disabled:
		return SHOP_CLEAN_QUANTITY_PLUS_DISABLED if is_plus else SHOP_CLEAN_QUANTITY_MINUS_DISABLED
	if hovered:
		return SHOP_CLEAN_QUANTITY_PLUS_HOVER if is_plus else SHOP_CLEAN_QUANTITY_MINUS_HOVER
	return SHOP_CLEAN_QUANTITY_PLUS_NORMAL if is_plus else SHOP_CLEAN_QUANTITY_MINUS_NORMAL


func _set_purchase_pressed() -> void:
	if _purchase_btn != null and not _purchase_btn.disabled:
		_seal_art.texture = _load_texture(SHOP_CLEAN_PURCHASE_SEAL_PRESSED)


func _sync_purchase_seal() -> void:
	if _seal_art == null or _purchase_btn == null:
		return
	var path := SHOP_CLEAN_PURCHASE_SEAL_NORMAL
	if _purchase_btn.disabled:
		path = SHOP_CLEAN_PURCHASE_SEAL_DISABLED
	elif _purchase_hovered:
		path = SHOP_CLEAN_PURCHASE_SEAL_HOVER
	_seal_art.texture = _load_texture(path)


func _sync_close_tag() -> void:
	if _close_tag_art == null:
		return
	var path := SHOP_CLEAN_CLOSE_TAG_HOVER if _close_hovered else SHOP_CLEAN_CLOSE_TAG_NORMAL
	_close_tag_art.texture = _load_texture(path)


func _description_for(key: String) -> String:
	var description := String(_meta_for(_active_category, key).get("description", ""))
	if description == "" and _active_category == "recipes":
		description = "买下%s的公开菜谱。" % _display_name(key)
	return description


func _uses_for_selected(key: String) -> String:
	if _active_category == "materials":
		return _uses_for_material(key)
	var usage := String(_meta_for(_active_category, key).get("usage", ""))
	if usage == "" and _active_category == "recipes":
		usage = "购买后配方书会显示%s，并可进入普通客人的点单池。" % _display_name(key)
	return usage


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
