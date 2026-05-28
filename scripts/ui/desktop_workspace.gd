class_name DesktopWorkspace
extends Control

## 桌面合成区 —— 自由拖放材料、配方检测、操作执行

signal mix_available(available: bool)
signal contents_changed()

var _items: Array[Dictionary] = []   ## [{key, rect}]
var _gm: Node = null

const SLOT_SIZE := Vector2(64, 56)
const SLOT_MARGIN := 10.0


func _ready() -> void:
	_gm = get_node("/root/GameManager")
	mouse_filter = Control.MOUSE_FILTER_STOP


func add_item(key: String, at_position: Vector2) -> void:
	if key == "":
		return
	var local_pos = at_position - global_position
	_items.append({"key": key, "rect": Rect2(local_pos, SLOT_SIZE)})
	_refresh()


func clear_all() -> void:
	_items.clear()
	_refresh()


func get_item_keys() -> Array[String]:
	var keys: Array[String] = []
	for item in _items:
		keys.append(item["key"])
	return keys


## 返回 {key, local_pos} 或空字典
func pick_at(pos: Vector2) -> Dictionary:
	var local = pos - global_position
	for i in range(_items.size() - 1, -1, -1):
		if _items[i]["rect"].has_point(local):
			var item = _items[i]
			_items.remove_at(i)
			_refresh()
			return {"key": item["key"], "local_pos": item["rect"].position}
	return {}


func get_mix_recipe() -> Dictionary:
	if _gm == null:
		return {}
	var distinct: Array[String] = []
	for item in _items:
		var k: String = item["key"]
		if not distinct.has(k):
			distinct.append(k)
	if distinct.size() < 2:
		return {}
	for i in range(distinct.size()):
		for j in range(i + 1, distinct.size()):
			var result = _gm.craft.get_combine_result(distinct[i], distinct[j])
			if result != "":
				return {"a": distinct[i], "b": distinct[j], "result": result}
	return {}


func get_available_operation() -> Dictionary:
	if _gm == null:
		return {}
	var keys = get_item_keys()
	if keys.size() != 1:
		return {}
	return _gm.craft.get_operations(keys[0])


func do_mix(a: String, b: String, result: String) -> void:
	if _gm == null:
		return
	var removed_a = false
	var removed_b = false
	var new_items: Array[Dictionary] = []
	for item in _items:
		if item["key"] == a and not removed_a:
			removed_a = true
			continue
		if item["key"] == b and not removed_b:
			removed_b = true
			continue
		new_items.append(item)
	var pos = _find_free_spot()
	new_items.append({"key": result, "rect": Rect2(pos, SLOT_SIZE)})
	_items = new_items
	_refresh()


func do_operation(_op_name: String, result_key: String) -> void:
	if _gm == null or _items.size() == 0:
		return
	var consumed = _items[0]
	_items.remove_at(0)
	_items.append({"key": result_key, "rect": consumed["rect"]})
	_refresh()


func _find_free_spot() -> Vector2:
	var rect = get_rect()
	var max_cols = max(1, int((rect.size.x - SLOT_MARGIN) / (SLOT_SIZE.x + SLOT_MARGIN)))
	for attempt in range(200):
		var col = attempt % max_cols
		var row = attempt / max_cols
		var x = SLOT_MARGIN + col * (SLOT_SIZE.x + SLOT_MARGIN)
		var y = SLOT_MARGIN + row * (SLOT_SIZE.y + SLOT_MARGIN)
		if y + SLOT_SIZE.y <= rect.size.y:
			var test_rect = Rect2(x, y, SLOT_SIZE.x, SLOT_SIZE.y)
			var occupied = false
			for item in _items:
				if item["rect"].intersects(test_rect):
					occupied = true
					break
			if not occupied:
				return Vector2(x, y)
	return Vector2(SLOT_MARGIN, SLOT_MARGIN)


func _refresh() -> void:
	contents_changed.emit()
	var recipe = get_mix_recipe()
	mix_available.emit(not recipe.is_empty())
	queue_redraw()


func _draw() -> void:
	var rect = get_rect()
	draw_rect(rect, Color(0.35, 0.25, 0.15, 0.95))
	draw_rect(rect, Color(0.50, 0.35, 0.20, 1.0), false, 3.0)

	if _items.size() == 0:
		var font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(16, 32), "把材料从快捷栏拖到桌面开始合成 →",
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 16, Color(1, 1, 1, 0.4))

	for item in _items:
		var r: Rect2 = item["rect"]
		var item_data = _gm.craft.get_item(item["key"]) if _gm != null else {}
		var c = Color.GRAY
		var name_str: String = item["key"]
		if not item_data.is_empty():
			var col_arr = item_data.get("color", [])
			if col_arr is Array and col_arr.size() >= 3:
				c = Color(col_arr[0], col_arr[1], col_arr[2])
			name_str = item_data.get("name", name_str)
		draw_rect(r, c)
		draw_rect(r, Color(0.6, 0.6, 0.6, 0.7), false, 2.0)
		var font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(r.position.x + 4, r.position.y + 18),
				name_str, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 14, Color.WHITE)
