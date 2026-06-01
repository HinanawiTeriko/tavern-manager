class_name CraftSystem
extends RefCounted

var items: Dictionary = {}
var _ops: Dictionary = {}
var _combine: Dictionary = {}
var item_physics_profiles: Dictionary = {}
var unlocked_recipes: Array = []
var recipes: Dictionary = {}              # 原始 JSON：product_key -> recipe data
var _recipes_by_container: Dictionary = {}  # "barrel|ale" -> "ale_beer"

func is_recipe_unlocked(key: String) -> bool:
	return unlocked_recipes.has(key)

func unlock_recipe(key: String) -> void:
	if not unlocked_recipes.has(key):
		unlocked_recipes.append(key)

func get_orderable_products(day: int) -> Array[String]:
	var result: Array[String] = []
	for product_key in recipes:
		var recipe: Dictionary = recipes[product_key]
		if not bool(recipe.get("orderable", true)):
			continue
		if int(recipe.get("unlock_day", 1)) > day:
			continue
		if bool(recipe.get("requires_purchase", false)) and not is_recipe_unlocked(product_key):
			continue
		if is_product(product_key):
			result.append(product_key)
	result.sort()
	return result

func load_data() -> void:
	_load_items()
	_load_item_physics_profiles()
	_load_operations()
	_load_combines()
	_load_recipes()
	print("[Craft] 加载 ", items.size(), " 种物品, ", _ops.size(), " 个加工节点, ", _combine.size(), " 条组合规则, ", recipes.size(), " 条容器配方")

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

func _load_item_physics_profiles() -> void:
	var file = FileAccess.open("res://data/item_physics_profiles.json", FileAccess.READ)
	if file == null:
		push_warning("[Craft] item_physics_profiles.json 未找到，用 DeskItem 默认物理参数")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null or not data is Dictionary:
		push_error("[Craft] item_physics_profiles.json 格式无效")
		return
	item_physics_profiles = data

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

func _load_recipes() -> void:
	var file = FileAccess.open("res://data/recipes.json", FileAccess.READ)
	if file == null:
		push_error("[Craft] recipes.json 未找到")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null or not data is Dictionary:
		push_error("[Craft] recipes.json 格式无效")
		return
	recipes = data
	for product_key in recipes.keys():
		var recipe: Dictionary = recipes[product_key]
		var container: String = recipe.get("container", "")
		var ingredients: Array = recipe.get("ingredients", [])
		if container == "" or ingredients.is_empty():
			push_warning("[Craft] recipe %s 缺 container 或 ingredients，跳过" % product_key)
			continue
		var sorted_ingr: Array = ingredients.duplicate()
		sorted_ingr.sort()
		var key: String = container + "|" + "+".join(sorted_ingr)
		_recipes_by_container[key] = product_key

func _make_key(a: String, b: String) -> String:
	return a + "|" + b

func get_item(key: String) -> Dictionary:
	return items.get(key, {})

func get_item_physics_profiles() -> Dictionary:
	return item_physics_profiles

func get_operations(key: String) -> Dictionary:
	return _ops.get(key, {})

func has_operations(key: String) -> bool:
	return _ops.has(key)

func is_product(key: String) -> bool:
	var item: Dictionary = items.get(key, {})
	return item.get("type", "") == "product"

func get_memory_for(product_key: String) -> Dictionary:
	var recipe: Dictionary = recipes.get(product_key, {})
	return recipe.get("memory_for", {})

func get_combine_result(a: String, b: String) -> String:
	if a == "" or b == "":
		return ""
	return _combine.get(_make_key(a, b), "")

func query_recipe(container: String, ingredients: Array) -> String:
	if container == "" or ingredients.is_empty():
		return ""
	var sorted_ingr: Array = ingredients.duplicate()
	sorted_ingr.sort()
	var key: String = container + "|" + "+".join(sorted_ingr)
	return _recipes_by_container.get(key, "")
