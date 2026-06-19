class_name InventoryOverlay
extends Control

signal item_dropped(item_key: String, global_position: Vector2)
signal closed

const InventoryGridSlotScript := preload("res://scripts/ui/inventory_grid_slot.gd")
const GRID_COLUMNS := 5
const GRID_SLOT_H_GAP := 16
const GRID_SLOT_V_GAP := 10
const TOOLTIP_OFFSET := Vector2(18.0, 10.0)
const TITLE_RECT := Rect2(40.0, 24.0, 420.0, 32.0)
const SECTION_TITLE_RECT := Rect2(72.0, 78.0, 476.0, 28.0)
const GRID_RECT := Rect2(78.0, 96.0, 464.0, 360.0)
const CLOSE_BUTTON_RECT := Rect2(508.0, 24.0, 80.0, 36.0)

@onready var _panel: Panel = $Panel
@onready var _material_list: Control = $Panel/MaterialList
@onready var _story_list: Control = $Panel/StoryList

var _gm
var _material_keys: Array[String] = []
var _story_keys: Array[String] = []
var _all_item_keys: Array[String] = []
var _material_grid: GridContainer = null
var _story_grid: GridContainer = null
var _tooltip: PanelContainer = null
var _tooltip_title: Label = null
var _tooltip_type: Label = null
var _tooltip_count: Label = null
var _tooltip_price: Label = null
var _tooltip_tags: Label = null


func _ready() -> void:
	ThemeColors.style_inventory_panel(_panel)
	ThemeColors.style_brush_label($Panel/Title, 18, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Panel/MaterialTitle, 16, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Panel/StoryTitle, 16, ThemeColors.AMBER_PRIMARY)
	$Panel/MaterialTitle.text = ""
	$Panel/MaterialTitle.visible = false
	$Panel/StoryTitle.visible = false
	_story_list.visible = false
	_apply_unified_grid_layout()
	_material_grid = _ensure_grid_container(_material_list, "MaterialGrid")
	_story_grid = _ensure_grid_container(_story_list, "StoryGrid")
	_ensure_tooltip()
	_add_close_button()

func _add_close_button() -> void:
	var close_btn = Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(80, 36)
	close_btn.position = CLOSE_BUTTON_RECT.position
	close_btn.size = CLOSE_BUTTON_RECT.size
	ThemeColors.style_brush_button(close_btn, 14)
	close_btn.pressed.connect(_on_return_pressed)
	_panel.add_child(close_btn)


func _apply_unified_grid_layout() -> void:
	var title := $Panel/Title as Label
	title.position = TITLE_RECT.position
	title.size = TITLE_RECT.size
	var material_title := $Panel/MaterialTitle as Label
	material_title.position = SECTION_TITLE_RECT.position
	material_title.size = SECTION_TITLE_RECT.size
	_material_list.position = GRID_RECT.position
	_material_list.size = GRID_RECT.size


func _on_return_pressed() -> void:
	close()


func configure(game_manager) -> void:
	_gm = game_manager


func open() -> void:
	refresh()
	visible = true


func close() -> void:
	_hide_tooltip()
	if not visible:
		return
	visible = false
	closed.emit()


func accepts_world_drop(world_position: Vector2, _item_key: String = "") -> bool:
	if not visible or _panel == null:
		return false
	return _panel.get_global_rect().has_point(world_position)


func refresh() -> void:
	if _gm == null:
		return
	_material_keys.clear()
	_story_keys.clear()
	_all_item_keys.clear()
	for key in _gm.inventory:
		if int(_gm.inventory[key]) <= 0:
			continue
		var is_inventory_item := false
		if _gm.inventory_sys.is_story_item(key):
			_story_keys.append(key)
			is_inventory_item = true
		elif _gm.inventory_sys.is_material(key) or _gm.seasoning.is_seasoning(key):
			_material_keys.append(key)
			is_inventory_item = true
		if is_inventory_item:
			_all_item_keys.append(key)
	_material_keys.sort()
	_story_keys.sort()
	_all_item_keys.sort()
	_material_grid = _ensure_grid_container(_material_list, "MaterialGrid")
	_story_grid = _ensure_grid_container(_story_list, "StoryGrid")
	_rebuild_grid(_material_grid, _all_item_keys)
	_rebuild_grid(_story_grid, [])


func get_material_keys() -> Array[String]:
	return _material_keys.duplicate()


func get_story_keys() -> Array[String]:
	return _story_keys.duplicate()


func _ensure_grid_container(wrapper: Control, grid_name: String) -> GridContainer:
	var grid := wrapper.get_node_or_null(grid_name) as GridContainer
	if grid == null:
		for child in wrapper.get_children():
			wrapper.remove_child(child)
			child.queue_free()
		grid = GridContainer.new()
		grid.name = grid_name
		wrapper.add_child(grid)
	grid.columns = GRID_COLUMNS
	grid.custom_minimum_size = Vector2(
		float(GRID_COLUMNS) * InventoryGridSlot.SLOT_SIZE.x + float(GRID_COLUMNS - 1) * GRID_SLOT_H_GAP,
		0.0
	)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", GRID_SLOT_H_GAP)
	grid.add_theme_constant_override("v_separation", GRID_SLOT_V_GAP)
	return grid


func _ensure_tooltip() -> void:
	_tooltip = _panel.get_node_or_null("ItemTooltip") as PanelContainer
	if _tooltip == null:
		_tooltip = PanelContainer.new()
		_tooltip.name = "ItemTooltip"
		_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tooltip.z_index = 50
		_tooltip.custom_minimum_size = Vector2(196.0, 0.0)
		ThemeColors.style_brush_content_panel(_tooltip)
		_panel.add_child(_tooltip)
	var box := _tooltip.get_node_or_null("VBox") as VBoxContainer
	if box == null:
		box = VBoxContainer.new()
		box.name = "VBox"
		box.add_theme_constant_override("separation", 2)
		_tooltip.add_child(box)
	_tooltip_title = _ensure_tooltip_label(box, "Title", 15, ThemeColors.AMBER_PRIMARY)
	_tooltip_type = _ensure_tooltip_label(box, "Type", 12, ThemeColors.TEXT_SUBTITLE)
	_tooltip_count = _ensure_tooltip_label(box, "Count", 12, ThemeColors.TEXT_LIGHT)
	_tooltip_price = _ensure_tooltip_label(box, "Price", 12, ThemeColors.TEXT_LIGHT)
	_tooltip_tags = _ensure_tooltip_label(box, "Tags", 11, ThemeColors.TEXT_DIM)
	_tooltip.visible = false


func _ensure_tooltip_label(box: VBoxContainer, label_name: String, font_size: int, color: Color) -> Label:
	var label := box.get_node_or_null(label_name) as Label
	if label == null:
		label = Label.new()
		label.name = label_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	ThemeColors.style_brush_label(label, font_size, color)
	return label


func _rebuild_grid(grid: GridContainer, keys: Array[String]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for key in keys:
		var item_data: Dictionary = _gm.craft.get_item(key)
		var capabilities: Array[String] = _gm.inventory_sys.get_capabilities(key)
		var slot = InventoryGridSlotScript.new()
		slot.configure(
			key,
			String(item_data.get("name", key)),
			_gm.inventory_sys.get_count(key),
			_item_icon_or_swatch(key, item_data),
			capabilities.has("readable")
		)
		slot.hovered.connect(_show_item_tooltip)
		slot.unhovered.connect(_hide_tooltip)
		slot.open_requested.connect(_on_row_open_requested)
		grid.add_child(slot)


func _show_item_tooltip(item_key: String, slot: Control) -> void:
	if _gm == null or _tooltip == null:
		return
	var item_data: Dictionary = _gm.craft.get_item(item_key)
	var capabilities: Array[String] = _gm.inventory_sys.get_capabilities(item_key)
	var count: int = _gm.inventory_sys.get_count(item_key)
	_tooltip_title.text = String(item_data.get("name", item_key))
	_tooltip_type.text = "类型：" + _item_type_label(item_key, item_data, capabilities)
	_tooltip_count.text = "数量：x%d" % count
	var price: int = _item_price(item_key, item_data, capabilities)
	_tooltip_price.text = "价格：%d金" % price if price > 0 else "价格：-"
	_tooltip_tags.text = "标记：" + _capability_label(capabilities)
	_tooltip.visible = true
	_tooltip.reset_size()
	var desired := slot.get_global_rect().position - _panel.global_position + TOOLTIP_OFFSET
	var min_size := _tooltip.get_combined_minimum_size()
	var max_x := maxf(4.0, _panel.size.x - min_size.x - 8.0)
	var max_y := maxf(4.0, _panel.size.y - min_size.y - 8.0)
	_tooltip.position = Vector2(clampf(desired.x, 4.0, max_x), clampf(desired.y, 4.0, max_y))


func _hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.visible = false


func _item_type_label(item_key: String, item_data: Dictionary, capabilities: Array[String]) -> String:
	if capabilities.has("story_item"):
		return "剧情物品"
	if _gm != null and _gm.seasoning.is_seasoning(item_key):
		return "调料"
	var type_key := String(item_data.get("type", ""))
	match type_key:
		"material":
			return "材料"
		"product":
			return "成品"
		"intermediate":
			return "半成品"
		"special":
			return "特殊物品"
		_:
			return "物品"


func _capability_label(capabilities: Array[String]) -> String:
	if capabilities.is_empty():
		return "无"
	var labels: Array[String] = []
	for capability in capabilities:
		match capability:
			"material":
				labels.append("材料")
			"product":
				labels.append("成品")
			"intermediate":
				labels.append("半成品")
			"story_item":
				labels.append("剧情")
			"readable":
				labels.append("可读")
			_:
				labels.append(capability)
	return "、".join(labels)


func _item_price(item_key: String, item_data: Dictionary, capabilities: Array[String]) -> int:
	var price := int(item_data.get("price", 0))
	if price > 0:
		return price
	if _gm == null or _gm.shop == null or not capabilities.has("material"):
		return 0
	var material_price: int = _gm.shop.get_material_price(item_key)
	return material_price if material_price != ShopSystem.UNKNOWN_PRICE else 0


func _on_row_open_requested(item_key: String) -> void:
	# 双击可阅读物品 → 打开文档阅读
	_gm.request_open_document(item_key)
	close()


func _item_icon_or_swatch(key: String, item_data: Dictionary) -> Texture2D:
	var icon_texture = _gm.try_load_material_icon(key)
	if icon_texture != null:
		return icon_texture
	var rgb: Array = item_data.get("color", [0.55, 0.5, 0.45])
	var gradient := Gradient.new()
	var color := Color(rgb[0], rgb[1], rgb[2])
	gradient.colors = PackedColorArray([color, color])
	var texture := GradientTexture2D.new()
	texture.width = 20
	texture.height = 20
	texture.gradient = gradient
	return texture


func _can_drop_data(at_position: Vector2, data) -> bool:
	return data is Dictionary \
		and data.has("item_key") \
		and not _panel.get_rect().has_point(at_position)


func _drop_data(at_position: Vector2, data) -> void:
	if not _can_drop_data(at_position, data):
		return
	item_dropped.emit(String(data["item_key"]), global_position + at_position)
	close()
