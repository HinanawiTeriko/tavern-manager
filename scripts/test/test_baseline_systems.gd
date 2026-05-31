extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_orderable_products_respect_purchase_unlock()
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
	for unlock in data.get("recipeUnlocks", []):
		_ok(craft.recipes.has(unlock["key"]), "shop recipe key should exist: " + unlock["key"])


func _test_today_important_npc_resets_on_empty_day() -> void:
	var narrative := NarrativeManager.new()
	narrative.load_npc_data()
	_ok(narrative.select_today_important_npc(1) == "ryan", "Day 1 should select ryan")
	_ok(narrative.select_today_important_npc(5) == "", "empty day should clear stale NPC")
	_ok(narrative.today_important_npc == "", "stored NPC id should also be cleared")


func _test_material_icons_load() -> void:
	var gm = get_node("/root/GameManager")
	for key in ["ale", "grape", "flour", "meat_raw", "herb"]:
		_ok(gm.try_load_material_icon(key) != null, "material icon should load: " + key)
