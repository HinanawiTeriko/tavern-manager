extends Node

var _checks := 0
var _failures := 0

const RARE_MATERIALS := {
	"cave_mushroom": "洞窟菌",
	"rock_lizard_meat": "岩蜥肉",
	"north_sour_grape": "北路酸葡萄",
	"black_malt": "黑麦芽",
}

const UPGRADE_RECIPES := {
	"cave_mushroom_stew": {"name": "菌菇肉汤", "container": "pot", "ingredients": ["meat_raw", "cave_mushroom"]},
	"rock_lizard_steak": {"name": "岩蜥烤排", "container": "grill", "ingredients": ["rock_lizard_meat"]},
	"old_road_wine": {"name": "旧路酸葡萄酒", "container": "barrel", "ingredients": ["north_sour_grape"]},
	"miner_dark_ale": {"name": "矿工黑啤", "container": "barrel", "ingredients": ["black_malt"]},
}

const UPGRADE_SATISFIES_ORDERS := {
	"cave_mushroom_stew": ["meat_stew"],
	"rock_lizard_steak": ["meat_cooked"],
	"old_road_wine": ["wine"],
	"miner_dark_ale": ["ale_beer"],
}

const RARE_LOCATIONS := {
	"mushroom_forest": {"stable": "herb", "rare": "cave_mushroom"},
	"dark_river": {"stable": "meat_raw", "rare": "rock_lizard_meat"},
	"grape_trellis": {"stable": "grape", "rare": "north_sour_grape"},
	"mill_farm": {"stable": "ale", "rare": "black_malt"},
}


func _ready() -> void:
	_test_items_define_rare_materials_and_products()
	_test_recipes_keep_container_limits()
	_test_locations_advertise_stable_and_rare_rewards()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RARE-GATHERING-DATA] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RARE-GATHERING-DATA] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RARE-GATHERING-DATA] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_ok(file != null, path + " opens")
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_ok(parsed is Dictionary, path + " parses as Dictionary")
	return parsed if parsed is Dictionary else {}


func _test_items_define_rare_materials_and_products() -> void:
	var items := _load_json("res://data/items.json")
	for key in RARE_MATERIALS.keys():
		_ok(items.has(key), "items has rare material " + key)
		var item: Dictionary = items.get(key, {})
		_ok(String(item.get("name", "")) == String(RARE_MATERIALS[key]), key + " has expected Chinese name")
		_ok(String(item.get("type", "")) == "material", key + " is a material")
	for key in UPGRADE_RECIPES.keys():
		_ok(items.has(key), "items has upgrade product " + key)
		var product: Dictionary = items.get(key, {})
		_ok(String(product.get("name", "")) == String(UPGRADE_RECIPES[key]["name"]), key + " has expected Chinese name")
		_ok(String(product.get("type", "")) == "product", key + " is a product")


func _test_recipes_keep_container_limits() -> void:
	var recipes := _load_json("res://data/recipes.json")
	for key in UPGRADE_RECIPES.keys():
		_ok(recipes.has(key), "recipes has upgrade recipe " + key)
		var recipe: Dictionary = recipes.get(key, {})
		var expected: Dictionary = UPGRADE_RECIPES[key]
		var ingredients: Array = recipe.get("ingredients", [])
		_ok(String(recipe.get("container", "")) == String(expected["container"]), key + " uses expected container")
		_ok(ingredients == expected["ingredients"], key + " uses expected ingredients")
		_ok(recipe.get("satisfies_orders", []) == UPGRADE_SATISFIES_ORDERS[key], key + " declares base orders it satisfies")
		if String(recipe.get("container", "")) == "grill":
			_ok(ingredients.size() == 1, key + " keeps grill single-material rule")
		else:
			_ok(ingredients.size() <= 2, key + " keeps existing two-material cap")


func _test_locations_advertise_stable_and_rare_rewards() -> void:
	var data := _load_json("res://data/locations.json")
	var locations: Array = data.get("locations", [])
	for location_id in RARE_LOCATIONS.keys():
		var loc := _find_location(locations, location_id)
		_ok(not loc.is_empty(), "location exists: " + location_id)
		var expected: Dictionary = RARE_LOCATIONS[location_id]
		_ok(String(loc.get("stableReward", "")) == String(expected["stable"]), location_id + " declares stableReward")
		_ok(int(loc.get("stableRewardCount", 0)) == 2, location_id + " declares stableRewardCount 2")
		var rare: Dictionary = loc.get("rareReward", {})
		_ok(String(rare.get("key", "")) == String(expected["rare"]), location_id + " declares rare reward key")
		_ok(float(rare.get("chance", -1.0)) == 0.35, location_id + " declares 35 percent rare chance")
		_ok(int(rare.get("pityAfterMisses", 0)) == 2, location_id + " declares pity after two misses")
		_ok(String(loc.get("description", "")).length() > 8, location_id + " has a natural revised description")


func _find_location(locations: Array, location_id: String) -> Dictionary:
	for loc in locations:
		if String((loc as Dictionary).get("id", "")) == location_id:
			return loc
	return {}
