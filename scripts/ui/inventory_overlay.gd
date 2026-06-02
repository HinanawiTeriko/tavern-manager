class_name InventoryOverlay
extends Control

signal item_dropped(item_key: String, global_position: Vector2)

@onready var _panel: Panel = $Panel
@onready var _material_list: VBoxContainer = $Panel/MaterialList
@onready var _story_list: VBoxContainer = $Panel/StoryList

var _gm
var _material_keys: Array[String] = []
var _story_keys: Array[String] = []


func _ready() -> void:
	ThemeColors.style_brush_panel(_panel)
	ThemeColors.style_brush_label($Panel/Title, 18, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Panel/MaterialTitle, 16, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Panel/StoryTitle, 16, ThemeColors.AMBER_PRIMARY)


func configure(game_manager) -> void:
	_gm = game_manager


func open() -> void:
	refresh()
	visible = true


func close() -> void:
	visible = false


func refresh() -> void:
	if _gm == null:
		return
	_material_keys.clear()
	_story_keys.clear()
	for key in _gm.inventory:
		if int(_gm.inventory[key]) <= 0:
			continue
		if _gm.inventory_sys.is_story_item(key):
			_story_keys.append(key)
		elif _gm.inventory_sys.is_material(key):
			_material_keys.append(key)
	_material_keys.sort()
	_story_keys.sort()
	_rebuild_list(_material_list, _material_keys)
	_rebuild_list(_story_list, _story_keys)


func get_material_keys() -> Array[String]:
	return _material_keys.duplicate()


func get_story_keys() -> Array[String]:
	return _story_keys.duplicate()


func _rebuild_list(list: VBoxContainer, keys: Array[String]) -> void:
	for child in list.get_children():
		child.queue_free()
	for key in keys:
		var item_data: Dictionary = _gm.craft.get_item(key)
		var row := InventoryDragRow.new()
		row.custom_minimum_size = Vector2(250.0, 34.0)
		row.configure(
			key,
			"%s  x%d" % [item_data.get("name", key), _gm.inventory_sys.get_count(key)],
			_item_icon_or_swatch(key, item_data)
		)
		list.add_child(row)


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
