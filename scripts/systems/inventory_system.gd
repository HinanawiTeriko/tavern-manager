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
	if key == "" or amount == 0:
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
