class_name ShopSystem
extends RefCounted

const UNKNOWN_PRICE: int = 999
const INVALID_RECIPE_PRICE: int = -1
const MIRA_DISCOUNT: float = 0.8

var _material_prices: Dictionary = {}
var _recipe_unlock_prices: Dictionary = {}
var _ability_prices: Dictionary = {}
var _ability_names: Dictionary = {}

func load_config() -> void:
	var file = FileAccess.open("res://data/shop.json", FileAccess.READ)
	if file == null:
		print("[Shop] shop.json 未找到")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null:
		print("[Shop] JSON 解析失败")
		return
	_material_prices.clear()
	if data.has("materials") and data["materials"] != null:
		for m in data["materials"]:
			_material_prices[m["key"]] = m["price"]
	_recipe_unlock_prices.clear()
	if data.has("recipeUnlocks") and data["recipeUnlocks"] != null:
		for r in data["recipeUnlocks"]:
			_recipe_unlock_prices[r["key"]] = r["price"]
	_ability_prices.clear()
	_ability_names.clear()
	if data.has("abilities") and data["abilities"] != null:
		for a in data["abilities"]:
			_ability_prices[a["key"]] = a["price"]
			_ability_names[a["key"]] = a["name"]
	print("[Shop] 加载 ", _material_prices.size(), " 种材料, ", _recipe_unlock_prices.size(), " 种可解锁配方, ", _ability_prices.size(), " 种技法")

func get_material_price(key: String, discount: float = 1.0) -> int:
	if not _material_prices.has(key):
		return UNKNOWN_PRICE
	var price: int = _material_prices[key]
	if discount < 1.0:
		return floori(price * discount)
	return price

func get_recipe_unlock_price(key: String) -> int:
	if _recipe_unlock_prices.has(key):
		return _recipe_unlock_prices[key]
	return INVALID_RECIPE_PRICE

func get_ability_price(key: String) -> int:
	return _ability_prices.get(key, INVALID_RECIPE_PRICE)

func get_ability_name(key: String) -> String:
	return _ability_names.get(key, key)

func get_ability_keys() -> Array:
	return _ability_prices.keys()
