class_name CraftSystem
extends RefCounted

var items: Dictionary = {}
var _ops: Dictionary = {}
var _combine: Dictionary = {}
var unlocked_recipes: Array = []

func is_recipe_unlocked(key: String) -> bool:
	return unlocked_recipes.has(key)

func unlock_recipe(key: String) -> void:
	if not unlocked_recipes.has(key):
		unlocked_recipes.append(key)

func load_data() -> void:
	_load_items()
	_load_operations()
	_load_combines()
	print("[Craft] 加载 ", items.size(), " 种物品, ", _ops.size(), " 个加工节点, ", _combine.size(), " 条组合规则")

func _load_items() -> void:
	var file = FileAccess.open("res://data/items.json", FileAccess.READ)
	if file == null:
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null:
		return
	items = data

func _load_operations() -> void:
	var file = FileAccess.open("res://data/operations.json", FileAccess.READ)
	if file == null:
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null:
		return
	_ops = data

func _load_combines() -> void:
	var file = FileAccess.open("res://data/combines.json", FileAccess.READ)
	if file == null:
		push_error("[Craft] combines.json 未找到")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null or not data is Dictionary or not data.has("pairs"):
		push_error("[Craft] combines.json 格式无效")
		return
	var pairs: Array = data["pairs"]
	for p in pairs:
		var a: String = p[0]
		var b: String = p[1]
		var r: String = p[2]
		_combine[_make_key(a, b)] = r
		_combine[_make_key(b, a)] = r

func _make_key(a: String, b: String) -> String:
	return a + "|" + b

func get_item(key: String) -> Dictionary:
	return items.get(key, {})

func get_operations(key: String) -> Dictionary:
	return _ops.get(key, {})

func has_operations(key: String) -> bool:
	return _ops.has(key)

func is_product(key: String) -> bool:
	var item: Dictionary = items.get(key, {})
	return item.get("price", 0) > 0

func get_combine_result(a: String, b: String) -> String:
	if a == "" or b == "":
		return ""
	return _combine.get(_make_key(a, b), "")
