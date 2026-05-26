class_name SeasoningZone
extends Control

enum State { EMPTY, HAS_ITEM, SEASONED }

var _gm: GameManager
var _state: State = State.EMPTY
var _item_key: String = ""
var _applied_seasoning: String = ""
var _item_name: String = ""
var _label: Label

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "放入成品"
	_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	_label.add_theme_font_size_override("font_size", 14)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)

	queue_redraw()

func get_item_key() -> String:
	return _item_key

func get_state() -> State:
	return _state

func get_applied_seasoning() -> String:
	return _applied_seasoning

func set_item(key: String) -> void:
	_item_key = key
	_applied_seasoning = ""
	var item = _gm.craft.get_item(key)
	_item_name = item.get("name", key)
	_state = State.HAS_ITEM
	_label.text = _item_name
	_label.add_theme_color_override("font_color", ThemeColors.TEXT_LIGHT)
	queue_redraw()

func clear_item() -> void:
	_item_key = ""
	_applied_seasoning = ""
	_item_name = ""
	_state = State.EMPTY
	_label.text = "放入成品"
	_label.add_theme_color_override("font_color", ThemeColors.AMBER_PRIMARY)
	queue_redraw()

func try_apply_seasoning(seasoning_key: String) -> bool:
	if _state != State.HAS_ITEM and _state != State.SEASONED:
		return false
	if not _gm.seasoning.is_seasoning(seasoning_key):
		return false

	if seasoning_key == "sleep_powder":
		if not _gm.remove_from_inventory(seasoning_key, 1):
			return false

	_applied_seasoning = seasoning_key
	var seasoning = _gm.seasoning.get_seasoning(seasoning_key)
	var seasoning_name = seasoning.get("name", "")
	if seasoning_name == "":
		seasoning_name = _gm.craft.get_item(seasoning_key).get("name", seasoning_key)
	_item_name = _gm.craft.get_item(_item_key).get("name", _item_key) + " · " + seasoning_name
	_state = State.SEASONED
	_label.text = _item_name
	_label.add_theme_color_override("font_color", Color.LIME_GREEN)
	queue_redraw()
	return true

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)

	var bg: Color
	match _state:
		State.EMPTY:
			bg = Color(0.08, 0.06, 0.04)
		State.HAS_ITEM:
			bg = Color(0.15, 0.13, 0.06)
		State.SEASONED:
			bg = Color(0.12, 0.10, 0.04)
	draw_rect(rect, bg)

	var dash_color = Color(ThemeColors.AMBER_PRIMARY, 0.5 if _state == State.EMPTY else 0.8)
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
