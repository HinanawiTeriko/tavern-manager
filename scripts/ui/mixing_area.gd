class_name MixingArea
extends Control

signal combine_query(a: String, b: String)
signal contents_changed()

var _items: Array = []
var _gm = null

func _ready() -> void:
	_gm = get_node("/root/GameManager")
	mouse_filter = Control.MOUSE_FILTER_STOP

func add_item(key: String) -> void:
	if key == "":
		return

	var distinct: Array = []
	for i in _items:
		if i != key and not distinct.has(i):
			distinct.append(i)

	if distinct.size() > 0 and not _items.has(key):
		combine_query.emit(key, distinct[0])
		return

	_items.append(key)
	_refresh()

func force_add_item(key: String) -> void:
	if key == "":
		return
	_items.append(key)
	_refresh()

func force_add_items(keys: Array) -> void:
	for key in keys:
		if key != "":
			_items.append(key)
	_refresh()

func remove_item(key: String) -> void:
	var idx = _items.find(key)
	if idx >= 0:
		_items.remove_at(idx)
		_refresh()

func clear_items() -> void:
	_items.clear()
	_refresh()

func consume_and_replace_single(new_key: String) -> void:
	_items.clear()
	_items.append(new_key)
	_refresh()

func consume_and_replace(consumed: Array, new_key: String) -> void:
	for c in consumed:
		var idx = _items.find(c)
		if idx >= 0:
			_items.remove_at(idx)
	_items.append(new_key)
	_refresh()

func _refresh() -> void:
	contents_changed.emit()
	queue_redraw()

func _draw() -> void:
	var rect = get_rect()

	draw_rect(rect, Color(0.15, 0.12, 0.1))
	draw_rect(rect, Color(0.3, 0.25, 0.2), false)

	if _items.size() == 0:
		var font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(8, rect.size.y * 0.35), "拖入材料",
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 16)
		return

	var margin = 8.0
	var item_w = (rect.size.x - margin * (_items.size() + 1)) / max(1, _items.size())
	item_w = min(item_w, 100.0)

	for i in range(_items.size()):
		var item = _gm.Craft.get_item(_items[i])
		var c: Color = Colors.GRAY
		if not item.is_empty():
			var col_arr = item.get("color", [])
			if col_arr is Array and col_arr.size() >= 3:
				c = Color(col_arr[0], col_arr[1], col_arr[2])
		var x = margin + i * (item_w + margin)
		var y = rect.size.y * 0.25
		var h = rect.size.y * 0.5

		draw_rect(Rect2(x, y, item_w, h), c)
		draw_rect(Rect2(x, y, item_w, h), Color.WHITE, false)

		var name = item.get("name", _items[i])
		var font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(x + 2, y + 14), name,
				HORIZONTAL_ALIGNMENT_LEFT, item_w - 4, 14)
