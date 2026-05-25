class_name ShopSystem
extends RefCounted

var _material_prices: Dictionary = {}
var _recipe_unlock_prices: Dictionary = {}
var _mira_discount: float = 0.8

func load_config() -> void:
	var file = FileAccess.open("res://data/shop.json", FileAccess.READ)
	if file == null:
		print("[Shop] shop.json 未找到")
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("[Shop] JSON 解析失败: ", error)
		return
	var data: Dictionary = json.data
	if data == null:
		return
	_material_prices.clear()
	if data.has("materials") and data["materials"] != null:
		for m in data["materials"]:
			_material_prices[m["key"]] = m["price"]
	_recipe_unlock_prices.clear()
	if data.has("recipeUnlocks") and data["recipeUnlocks"] != null:
		for r in data["recipeUnlocks"]:
			_recipe_unlock_prices[r["key"]] = r["price"]
	if data.has("miraDiscount"):
		_mira_discount = data["miraDiscount"]
	print("[Shop] 加载 ", _material_prices.size(), " 种材料, ", _recipe_unlock_prices.size(), " 种可解锁配方")

func get_material_price(key: String, mira_active: bool = false) -> int:
	if not _material_prices.has(key):
		return 999
	var price: int = _material_prices[key]
	if mira_active:
		return floori(price * _mira_discount)
	return price

func get_recipe_unlock_price(key: String) -> int:
	if _recipe_unlock_prices.has(key):
		return _recipe_unlock_prices[key]
	return -1

func is_mira_shop_today(current_day: int, narrative) -> bool:
	var scenes = narrative.get_today_scenes(current_day)
	for npc in scenes:
		if npc.id == "mira":
			return true
	return false
