class_name CraftSystem
extends RefCounted

var items: Dictionary = {}
var _ops: Dictionary = {}
var _combine: Dictionary = {}
var item_physics_profiles: Dictionary = {}
const DEFAULT_DISCOVERED_RECIPES := ["ale_beer", "wine", "herb_tea", "bread", "meat_cooked"]
const FAILURE_PRODUCTS_BY_CONTAINER := {
	"barrel": "failed_brew",
	"pot": "failed_stew",
}

var unlocked_recipes: Array = []
var discovered_recipes: Array = []
var newly_discovered_recipes: Array = []
var unlocked_slam_containers: Array = []   # 已购冲击魔法的容器类，如 ["pot","barrel"]
var slam_merge_low: float = 350.0
var slam_merge_high: float = 1000.0
var recipes: Dictionary = {}              # 原始 JSON：product_key -> recipe data
var _recipes_by_container: Dictionary = {}  # "barrel|ale" -> "ale_beer"

func ensure_default_discovered_recipes() -> void:
	for key in DEFAULT_DISCOVERED_RECIPES:
		if recipes.has(key) and not discovered_recipes.has(key):
			discovered_recipes.append(key)
	discovered_recipes.sort()

func is_recipe_discovered(key: String) -> bool:
	return discovered_recipes.has(key)

func discover_recipe(key: String) -> bool:
	if key == "" or not recipes.has(key):
		return false
	if discovered_recipes.has(key):
		return false
	discovered_recipes.append(key)
	discovered_recipes.sort()
	return true

func is_recipe_new(key: String) -> bool:
	return newly_discovered_recipes.has(key)

func mark_recipe_new(key: String) -> bool:
	if key == "" or not is_recipe_discovered(key):
		return false
	if newly_discovered_recipes.has(key):
		return false
	newly_discovered_recipes.append(key)
	newly_discovered_recipes.sort()
	return true

func clear_recipe_new(key: String) -> bool:
	if not newly_discovered_recipes.has(key):
		return false
	newly_discovered_recipes.erase(key)
	return true

func prune_new_recipe_markers() -> void:
	for index in range(newly_discovered_recipes.size() - 1, -1, -1):
		if not is_recipe_discovered(String(newly_discovered_recipes[index])):
			newly_discovered_recipes.remove_at(index)

func is_recipe_unlocked(key: String) -> bool:
	return unlocked_recipes.has(key)

func unlock_recipe(key: String) -> void:
	if not unlocked_recipes.has(key):
		unlocked_recipes.append(key)
	discover_recipe(key)

func _load_slam_config() -> void:
	var file = FileAccess.open("res://data/slam.json", FileAccess.READ)
	if file == null:
		push_warning("[Craft] slam.json 未找到，用默认力度阈值")
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null or not data is Dictionary:
		push_error("[Craft] slam.json 格式无效")
		return
	slam_merge_low = float(data.get("merge_low", slam_merge_low))
	slam_merge_high = float(data.get("merge_high", slam_merge_high))

func is_slam_unlocked(container: String) -> bool:
	return unlocked_slam_containers.has(container)

func unlock_slam(container: String) -> void:
	if not unlocked_slam_containers.has(container):
		unlocked_slam_containers.append(container)

## 力度分档：none=太轻不合成 / normal=窗口内 / poor=砸太狠降级
func classify_slam_force(speed: float) -> String:
	if speed < slam_merge_low:
		return "none"
	if speed > slam_merge_high:
		return "poor"
	return "normal"

func get_orderable_products(day: int) -> Array[String]:
	var result: Array[String] = []
	for product_key in recipes:
		var recipe: Dictionary = recipes[product_key]
		if not bool(recipe.get("orderable", true)):
			continue
		if int(recipe.get("unlock_day", 1)) > day:
			continue
		if not is_recipe_discovered(product_key):
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
	ensure_default_discovered_recipes()
	_load_slam_config()
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

func can_satisfy_order(served_key: String, order_key: String) -> bool:
	if served_key == "" or order_key == "":
		return false
	if served_key == order_key:
		return true
	var recipe: Dictionary = recipes.get(served_key, {})
	var compatible_orders: Array = recipe.get("satisfies_orders", [])
	for compatible_order in compatible_orders:
		if String(compatible_order) == order_key:
			return true
	return false

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


func failure_product_for_container(container: String) -> String:
	return String(FAILURE_PRODUCTS_BY_CONTAINER.get(container, ""))

## 砸合成配方反查。keys=两个材料 key（可相同）。
## 返回 {product, container, double} 或 {}。
## double=true 表示单料配方撞两个同料 → 产双份。
## 仅匹配已 is_slam_unlocked 的 container；requires_purchase 配方需已解锁。
func find_slam_recipe(keys: Array) -> Dictionary:
	if keys.size() != 2:
		return {}
	var sorted_keys: Array = keys.duplicate()
	sorted_keys.sort()
	for product_key in recipes:
		var recipe: Dictionary = recipes[product_key]
		var container: String = recipe.get("container", "")
		if not is_slam_unlocked(container):
			continue
		if bool(recipe.get("requires_purchase", false)) and not is_recipe_unlocked(product_key):
			continue
		var ingr: Array = (recipe.get("ingredients", []) as Array).duplicate()
		ingr.sort()
		if ingr.size() == 2 and ingr == sorted_keys:
			return {"product": product_key, "container": container, "double": false}
		if ingr.size() == 1 and keys[0] == keys[1] and ingr[0] == keys[0]:
			return {"product": product_key, "container": container, "double": true}
	return {}
