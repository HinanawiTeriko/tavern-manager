class_name InventorySystem
extends RefCounted

# 唯一库存写入口。materials 是可堆叠材料/物品计数字典；
# GameManager.inventory 指向同一引用，因此本字典永远原地修改，绝不重新赋值。
var materials: Dictionary = {}

func set_initial(data: Dictionary) -> void:
	materials.clear()
	for key in data:
		materials[key] = int(data[key])

func add(key: String, amount: int = 1) -> void:
	if key == "" or amount <= 0:
		return
	materials[key] = int(materials.get(key, 0)) + amount

func remove(key: String, amount: int = 1) -> bool:
	if key == "" or amount <= 0:
		return false
	var cur: int = int(materials.get(key, 0))
	if cur < amount:
		return false
	var remaining: int = cur - amount
	if remaining <= 0:
		materials.erase(key)
	else:
		materials[key] = remaining
	return true

func get_count(key: String) -> int:
	return int(materials.get(key, 0))

func has(key: String) -> bool:
	return get_count(key) > 0

# 物品定义（只读），由 GameManager 从 CraftSystem 注入，用于能力查询。
var _items: Dictionary = {}

func load_items(items: Dictionary) -> void:
	_items = items

func get_capabilities(key: String) -> Array[String]:
	var def: Dictionary = _items.get(key, {})
	var caps: Array[String] = []
	if def.has("capabilities"):
		for c in def["capabilities"]:
			caps.append(String(c))
		return caps
	var t := String(def.get("type", ""))
	match t:
		"material":
			caps.append("material")
		"product":
			caps.append("product")
		"intermediate":
			caps.append("intermediate")
	return caps

func is_material(key: String) -> bool:
	return get_capabilities(key).has("material")

func is_product(key: String) -> bool:
	return get_capabilities(key).has("product")

func is_story_item(key: String) -> bool:
	return get_capabilities(key).has("story_item")

func get_story_items() -> Array[String]:
	var result: Array[String] = []
	for key in materials:
		if is_story_item(key):
			result.append(key)
	result.sort()
	return result
