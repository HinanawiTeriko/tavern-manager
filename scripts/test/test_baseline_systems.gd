extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_orderable_products_respect_purchase_unlock()
	_test_orderable_products_wait_for_production_chain()
	_test_recipe_discovery_controls_recipe_visibility()
	_test_recipe_discovery_new_marker_can_be_cleared()
	_test_hand_combine_recipes_are_discoverable()
	_test_intermediate_items_have_downstream_use()
	_test_recipe_expansion_items_unlocks_and_attributes()
	_test_all_recipes_are_reachable_through_current_workspace_rules()
	_test_shop_unlock_keys_exist_in_recipes()
	_test_today_important_npc_resets_on_empty_day()
	_test_material_icons_load()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-BASELINE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-BASELINE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-BASELINE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_orderable_products_respect_purchase_unlock() -> void:
	var craft := CraftSystem.new()
	craft.load_data()
	var before := craft.get_orderable_products(1)
	_ok(before.has("ale_beer"), "basic ale_beer should be orderable")
	_ok(not before.has("herbal_ale"), "shop recipe should not be orderable before unlock")
	craft.unlock_recipe("herbal_ale")
	var after := craft.get_orderable_products(1)
	_ok(after.has("herbal_ale"), "shop recipe should become orderable after unlock")
	_ok(not craft.get_orderable_products(3).has("herb_broth"), "hidden pot recipe should not be orderable before shop unlock")
	craft.unlock_recipe("herb_broth")
	_ok(craft.get_orderable_products(3).has("herb_broth"), "newly unlocked pot recipe should enter regular orders")


func _test_orderable_products_wait_for_production_chain() -> void:
	var craft := CraftSystem.new()
	craft.load_data()
	var day2 := craft.get_orderable_products(2)
	_ok(day2.has("meat_cooked"), "day2 should offer grill recipes that can be made directly")
	_ok(not day2.has("bread"), "day2 should not offer bread before the dough-making pot is available")
	var day3 := craft.get_orderable_products(3)
	_ok(day3.has("bread"), "bread should enter regular orders once the pot unlocks the dough chain")


func _test_recipe_discovery_controls_recipe_visibility() -> void:
	var craft = CraftSystem.new()
	craft.load_data()
	_ok(craft.has_method("is_recipe_discovered"), "craft exposes recipe discovery query")
	_ok(craft.has_method("discover_recipe"), "craft exposes recipe discovery mutation")
	if not craft.has_method("is_recipe_discovered") or not craft.has_method("discover_recipe"):
		return
	_ok(craft.call("is_recipe_discovered", "ale_beer"), "basic ale_beer starts discovered")
	_ok(craft.call("is_recipe_discovered", "wine"), "basic wine starts discovered")
	_ok(craft.call("is_recipe_discovered", "herb_tea"), "basic herb_tea starts discovered")
	_ok(craft.call("is_recipe_discovered", "bread"), "basic bread starts discovered")
	_ok(craft.call("is_recipe_discovered", "meat_cooked"), "basic meat_cooked starts discovered")
	_ok(not craft.call("is_recipe_discovered", "malt_porridge"), "advanced pot recipe starts hidden")
	_ok(not craft.get_orderable_products(3).has("malt_porridge"), "hidden recipe is not offered by regular customers")
	_ok(craft.call("discover_recipe", "malt_porridge"), "discover_recipe returns true the first time")
	_ok(craft.call("is_recipe_discovered", "malt_porridge"), "discovered recipe becomes visible")
	_ok(craft.get_orderable_products(3).has("malt_porridge"), "discovered non-shop recipe can enter regular orders")


func _test_recipe_discovery_new_marker_can_be_cleared() -> void:
	var craft = CraftSystem.new()
	craft.load_data()
	_ok(craft.has_method("is_recipe_new"), "craft exposes recipe new marker query")
	_ok(craft.has_method("mark_recipe_new"), "craft exposes recipe new marker mutation")
	_ok(craft.has_method("clear_recipe_new"), "craft exposes recipe new marker clearing")
	if not craft.has_method("is_recipe_new") or not craft.has_method("mark_recipe_new") or not craft.has_method("clear_recipe_new"):
		return
	_ok(not craft.call("is_recipe_new", "herb_broth"), "advanced recipe does not start as a new marker")
	_ok(not craft.call("mark_recipe_new", "herb_broth"), "undiscovered recipe cannot be marked new")
	craft.call("discover_recipe", "herb_broth")
	_ok(craft.call("mark_recipe_new", "herb_broth"), "discovered recipe can be marked new")
	_ok(craft.call("is_recipe_new", "herb_broth"), "marked recipe reports as new")
	_ok(not craft.call("mark_recipe_new", "herb_broth"), "marking an already-new recipe is a no-op")
	_ok(craft.call("clear_recipe_new", "herb_broth"), "new recipe marker can be cleared")
	_ok(not craft.call("is_recipe_new", "herb_broth"), "cleared recipe no longer reports as new")


func _test_hand_combine_recipes_are_discoverable() -> void:
	var craft = CraftSystem.new()
	craft.load_data()
	_ok(craft.recipes.has("dough_meat"), "hand combine output should be indexed as a recipe: dough_meat")
	_ok(craft.recipes.has("ale_herb"), "hand combine output should be indexed as a recipe: ale_herb")
	_ok(craft.recipes.has("grape_herb"), "hand combine output should be indexed as a recipe: grape_herb")
	if not craft.recipes.has("dough_meat"):
		return
	var recipe: Dictionary = craft.recipes["dough_meat"]
	_ok(String(recipe.get("container", "")) == "hand", "hand combine recipe uses hand container")
	_ok(Array(recipe.get("ingredients", [])) == ["dough", "meat_raw"], "hand combine recipe preserves ingredient pair")
	_ok(not craft.is_recipe_discovered("dough_meat"), "hand combine starts hidden before first discovery")
	_ok(craft.discover_recipe("dough_meat"), "hand combine can be discovered through recipe API")
	_ok(craft.is_recipe_discovered("dough_meat"), "discovered hand combine is visible to recipe book")


func _test_intermediate_items_have_downstream_use() -> void:
	var craft := CraftSystem.new()
	craft.load_data()
	var recipe_ingredients := {}
	for product_key in craft.recipes.keys():
		for ingredient in Array(craft.recipes[product_key].get("ingredients", [])):
			recipe_ingredients[String(ingredient)] = true
	var dead_intermediates: Array[String] = []
	for item_key in craft.items.keys():
		var item: Dictionary = craft.items[item_key]
		if String(item.get("type", "")) != "intermediate":
			continue
		var key := String(item_key)
		if craft.has_operations(key) or recipe_ingredients.has(key):
			continue
		dead_intermediates.append(key)
	dead_intermediates.sort()
	_ok(dead_intermediates.is_empty(), "intermediate items should feed another operation or recipe: " + ", ".join(dead_intermediates))


func _test_recipe_expansion_items_unlocks_and_attributes() -> void:
	var craft := CraftSystem.new()
	craft.load_data()
	var file := FileAccess.open("res://data/food_attributes.json", FileAccess.READ)
	_ok(file != null, "food_attributes.json should exist")
	if file == null:
		return
	var attributes = JSON.parse_string(file.get_as_text())
	file.close()
	_ok(attributes is Dictionary, "food_attributes.json should parse")
	if not attributes is Dictionary:
		return
	var expected_products := [
		"charred_crust_broth",
		"charred_meat_plate",
		"bitter_black_ale",
		"ash_pot_stew",
		"sour_herb_wine",
		"black_malt_porridge",
		"herbal_lizard_roast",
		"mushroom_pie",
		"grape_tart",
		"wakeful_herb_juice",
		"roasted_malt_porridge",
		"mushroom_meat_pie",
		"roasted_mushroom_broth",
		"toasted_herb_broth",
		"warm_spiced_wine",
		"sour_roast_herb_wine",
		"double_char_black_ale",
		"grape_flour_porridge",
		"ash_flatbread",
		"charred_mushroom_meat_stew",
		"charred_lizard_herb_plate",
		"bitter_grape_dark_ale",
	]
	for product_key in expected_products:
		_ok(craft.items.has(product_key), "expanded recipe item exists: " + product_key)
		if craft.items.has(product_key):
			_ok(String(craft.items[product_key].get("type", "")) == "product", "expanded recipe item is a product: " + product_key)
		_ok(craft.recipes.has(product_key), "expanded recipe exists: " + product_key)
		_ok(attributes.has(product_key), "expanded recipe has appetite attributes: " + product_key)
	var shoppable := [
		"bitter_black_ale",
		"sour_herb_wine",
		"black_malt_porridge",
		"herbal_lizard_roast",
		"mushroom_pie",
		"grape_tart",
		"wakeful_herb_juice",
		"roasted_malt_porridge",
		"mushroom_meat_pie",
		"roasted_mushroom_broth",
		"toasted_herb_broth",
		"warm_spiced_wine",
		"sour_roast_herb_wine",
		"double_char_black_ale",
		"grape_flour_porridge",
		"ash_flatbread",
		"charred_mushroom_meat_stew",
		"charred_lizard_herb_plate",
		"bitter_grape_dark_ale",
	]
	var shop := ShopSystem.new()
	shop.load_config()
	for product_key in shoppable:
		_ok(craft.recipes.has(product_key) and bool(craft.recipes[product_key].get("requires_purchase", false)),
			"advanced expanded recipe requires purchase: " + product_key)
		_ok(shop.get_recipe_unlock_price(product_key) > 0, "advanced expanded recipe has shop price: " + product_key)


func _test_all_recipes_are_reachable_through_current_workspace_rules() -> void:
	var craft := CraftSystem.new()
	craft.load_data()
	var reachable := {}
	for item_key in craft.items.keys():
		var item: Dictionary = craft.items[item_key]
		if String(item.get("type", "")) == "material":
			reachable[String(item_key)] = true
	var changed := true
	while changed:
		changed = false
		var keys := _sorted_keys(reachable)
		for key in keys:
			for result in _single_workspace_results(craft, key):
				changed = _mark_reachable(reachable, result) or changed
		keys = _sorted_keys(reachable)
		for i in range(keys.size()):
			for j in range(i, keys.size()):
				var a := String(keys[i])
				var b := String(keys[j])
				if not _can_use_as_container_ingredient(craft, a) or not _can_use_as_container_ingredient(craft, b):
					continue
				changed = _mark_reachable(reachable, craft.query_recipe("pot", [a, b])) or changed
				changed = _mark_reachable(reachable, craft.query_recipe("barrel", [a, b])) or changed
				changed = _mark_reachable(reachable, craft.get_combine_result(a, b)) or changed
				changed = _mark_reachable(reachable, craft.query_recipe("hand", [a, b])) or changed
	var unreachable: Array[String] = []
	for product_key in craft.recipes.keys():
		if not reachable.has(String(product_key)):
			unreachable.append(String(product_key))
	unreachable.sort()
	_ok(unreachable.is_empty(), "all recipes should be reachable through current workspace rules: " + ", ".join(unreachable))


func _single_workspace_results(craft: CraftSystem, key: String) -> Array[String]:
	var results: Array[String] = []
	var grill_result := craft.query_recipe("grill", [key])
	if grill_result != "":
		results.append(grill_result)
	if not _can_use_as_container_ingredient(craft, key):
		return results
	var pot_result := craft.query_recipe("pot", [key])
	if pot_result != "":
		results.append(pot_result)
	var stir_result := String(craft.get_operations(key).get("stir", ""))
	if stir_result != "":
		results.append(stir_result)
	var barrel_result := craft.query_recipe("barrel", [key])
	if barrel_result != "":
		results.append(barrel_result)
	return results


func _can_use_as_container_ingredient(craft: CraftSystem, key: String) -> bool:
	return key != "" and not craft.is_product(key)


func _mark_reachable(reachable: Dictionary, key: String) -> bool:
	if key == "" or reachable.has(key):
		return false
	reachable[key] = true
	return true


func _sorted_keys(values: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key in values.keys():
		keys.append(String(key))
	keys.sort()
	return keys


func _test_shop_unlock_keys_exist_in_recipes() -> void:
	var craft := CraftSystem.new()
	craft.load_data()
	var file := FileAccess.open("res://data/shop.json", FileAccess.READ)
	_ok(file != null, "shop.json should exist")
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	_ok(data is Dictionary, "shop.json should parse")
	if not data is Dictionary:
		return
	var shop_recipe_keys: Array[String] = []
	for unlock in data.get("recipeUnlocks", []):
		var key := String(unlock["key"])
		shop_recipe_keys.append(key)
		_ok(craft.recipes.has(key), "shop recipe key should exist: " + key)
		if craft.recipes.has(key):
			_ok(bool(craft.recipes[key].get("requires_purchase", false)),
				"shop recipe should be marked requires_purchase: " + key)
	_ok(shop_recipe_keys.has("herb_broth"), "hidden herb_broth recipe should be sold in the shop")
	for product_key in craft.recipes.keys():
		var recipe: Dictionary = craft.recipes[product_key]
		if bool(recipe.get("requires_purchase", false)):
			_ok(shop_recipe_keys.has(String(product_key)),
				"requires_purchase recipe should have a shop unlock: " + String(product_key))


func _test_today_important_npc_resets_on_empty_day() -> void:
	var narrative := NarrativeManager.new()
	narrative.load_npc_data()
	_ok(narrative.select_today_important_npc(1) == "ryan", "Day 1 should select ryan")
	_ok(narrative.select_today_important_npc(7) == "", "empty day should clear stale NPC")
	_ok(narrative.today_important_npc == "", "stored NPC id should also be cleared")


func _test_material_icons_load() -> void:
	var gm = get_node("/root/GameManager")
	for key in ["ale", "grape", "flour", "meat_raw", "herb", "cave_mushroom", "rock_lizard_meat", "north_sour_grape", "black_malt"]:
		_ok(gm.try_load_material_icon(key) != null, "material icon should load: " + key)
	var tavern_item_keys := [
		"charred_crust_broth",
		"charred_meat_plate",
		"bitter_black_ale",
		"ash_pot_stew",
		"sour_herb_wine",
		"black_malt_porridge",
		"herbal_lizard_roast",
		"mushroom_pie",
		"grape_tart",
		"wakeful_herb_juice",
		"roasted_malt_porridge",
		"mushroom_meat_pie",
		"herbed_lizard_raw",
		"mushroom_pie_raw",
		"grape_tart_raw",
		"mushroom_meat_pie_raw",
		"flour_toasted",
		"flour_burnt",
		"rock_lizard_burnt",
		"black_malt_roasted",
		"black_malt_burnt",
		"grape_roasted",
		"grape_burnt",
		"north_sour_grape_roasted",
		"north_sour_grape_burnt",
		"herb_roasted",
		"herb_ash",
		"cave_mushroom_roasted",
		"cave_mushroom_burnt",
		"roasted_mushroom_broth",
		"toasted_herb_broth",
		"warm_spiced_wine",
		"sour_roast_herb_wine",
		"double_char_black_ale",
		"grape_flour_porridge",
		"ash_flatbread",
		"charred_mushroom_meat_stew",
		"charred_lizard_herb_plate",
		"bitter_grape_dark_ale",
	]
	for key in tavern_item_keys:
		var texture: Texture2D = gm.try_load_material_icon(key)
		_ok(texture != null, "tavern recipe item art should load: " + key)
		if texture != null:
			_ok(String(texture.resource_path).begins_with("res://assets/textures/tavern/items/"),
				"tavern recipe item art should use dedicated DeskItem texture: " + key)
