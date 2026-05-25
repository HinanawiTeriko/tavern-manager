class_name SeasoningZone
extends Control

signal seasoning_applied(key: String)
signal seasoning_cleared()

var _gm
var _applied_seasoning: String = ""
var _hint_label: Label
var _applied_label: Label
var _btn_row: HBoxContainer

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	_hint_label = Label.new()
	_hint_label.text = "拖入香料"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_bottom = 0.6
	_hint_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_hint_label.add_theme_font_size_override("font_size", 12)
	add_child(_hint_label)

	_applied_label = Label.new()
	_applied_label.visible = false
	_applied_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_applied_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_applied_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_applied_label.anchor_right = 1.0
	_applied_label.anchor_bottom = 0.6
	_applied_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_applied_label.add_theme_font_size_override("font_size", 12)
	add_child(_applied_label)

	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 2)
	add_child(_btn_row)

	visible = false

func activate() -> void:
	_applied_seasoning = ""
	_applied_label.visible = false
	_hint_label.visible = true
	_rebuild_buttons()
	_btn_row.offset_left = 2
	_btn_row.offset_top = int(size.y * 0.6)
	_btn_row.offset_right = int(size.x) - 2
	_btn_row.offset_bottom = int(size.y) - 2
	visible = true
	queue_redraw()

func deactivate() -> void:
	_applied_seasoning = ""
	visible = false
	queue_redraw()

func try_apply_seasoning(item_key: String) -> bool:
	if not visible:
		return false
	var seasoning: Dictionary = _gm.seasoning.get_seasoning(item_key)
	if seasoning.is_empty():
		return false

	if item_key == "sleep_powder":
		if not _gm.inventory.has(item_key) or _gm.inventory[item_key] < 1:
			return false
		_gm.inventory[item_key] = _gm.inventory[item_key] - 1
		if _gm.inventory[item_key] <= 0:
			_gm.inventory.erase(item_key)
		_gm.notify_inventory_changed()

	_apply_seasoning(item_key)
	return true

func get_applied_seasoning() -> String:
	return _applied_seasoning

func clear_seasoning() -> void:
	_applied_seasoning = ""
	_applied_label.visible = false
	_hint_label.visible = true
	_rebuild_buttons()
	queue_redraw()
	seasoning_cleared.emit()

func _apply_seasoning(key: String) -> void:
	_applied_seasoning = key
	var seasoning: Dictionary = _gm.seasoning.get_seasoning(key)
	_applied_label.text = "已加: " + seasoning.get("name", key)
	_applied_label.visible = true
	_hint_label.visible = false
	for child in _btn_row.get_children():
		child.queue_free()
	queue_redraw()
	seasoning_applied.emit(key)

func _rebuild_buttons() -> void:
	for child in _btn_row.get_children():
		child.queue_free()

	for key in _gm.seasoning.seasonings:
		var data: Dictionary = _gm.seasoning.seasonings[key]
		if key == "sleep_powder":
			if not _gm.inventory.has(key) or _gm.inventory[key] < 1:
				continue

		var btn = Button.new()
		btn.text = data.get("name", key)
		btn.custom_minimum_size = Vector2(28, 24)
		ThemeColors.style_small_button(btn, 10)
		btn.pressed.connect(_apply_seasoning.bind(key))
		_btn_row.add_child(btn)

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var bg: Color
	if _applied_seasoning != "":
		bg = Color(0.15, 0.13, 0.06)
	else:
		bg = Color(0.13, 0.10, 0.07)
	draw_rect(rect, bg)

	var dash_color = Color(ThemeColors.AMBER_PRIMARY, 0.5)
	var dash = 5.0
	var gap = 4.0
	var w = rect.size.x
	var h = rect.size.y

	var x = 0.0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(min(x + dash, w), 0), dash_color)
		draw_line(Vector2(x, h), Vector2(min(x + dash, w), h), dash_color)
		x += dash + gap

	var y = 0.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(0, min(y + dash, h)), dash_color)
		draw_line(Vector2(w, y), Vector2(w, min(y + dash, h)), dash_color)
		y += dash + gap
