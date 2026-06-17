extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_add_remove_real_deduction()
	_test_capability_queries()
	_test_game_manager_routes_through_system()
	_test_shortcut_bindings_are_item_key_references()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-INVENTORY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-INVENTORY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-INVENTORY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_add_remove_real_deduction() -> void:
	var inv := InventorySystem.new()
	inv.set_initial({"ale": 5})
	_ok(inv.get_count("ale") == 5, "initial ale count should be 5")
	inv.add("ale", 2)
	_ok(inv.get_count("ale") == 7, "add should increase count")
	_ok(inv.remove("ale", 3), "remove with enough stock should succeed")
	_ok(inv.get_count("ale") == 4, "remove should really deduct")
	_ok(not inv.remove("ale", 99), "remove beyond stock should fail")
	_ok(inv.get_count("ale") == 4, "failed remove should not change count")
	_ok(inv.remove("ale", 4), "remove all should succeed")
	_ok(inv.get_count("ale") == 0, "depleted key should report 0")
	_ok(not inv.has("ale"), "depleted key should not be present")
	inv.add("ale", -1)
	_ok(inv.get_count("ale") == 0, "negative add should be a no-op")
	_ok(not inv.remove("ale", 0), "remove with zero amount should fail")


func _test_capability_queries() -> void:
	var inv := InventorySystem.new()
	inv.load_items(_load_items())
	_ok(inv.is_material("ale"), "ale should be material")
	_ok(not inv.is_material("ale_beer"), "ale_beer should not be material")
	_ok(inv.is_product("ale_beer"), "ale_beer should be product")
	_ok(not inv.is_product("ale"), "ale should not be product")
	_ok(inv.is_story_item("sleep_powder"), "sleep_powder should be story item")
	_ok(not inv.is_story_item("ale"), "ale should not be story item")
	_ok(inv.get_capabilities("ale") == ["material"], "ale capabilities should be [material]")
	_ok(inv.get_capabilities("unknown_key").is_empty(), "unknown key should have no capabilities")
	inv.set_initial({"sleep_powder": 1, "ale": 3})
	var story := inv.get_story_items()
	_ok(story.has("sleep_powder"), "held story items should include sleep_powder")
	_ok(not story.has("ale"), "held story items should exclude plain material")


func _load_items() -> Dictionary:
	var file := FileAccess.open("res://data/items.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data


func _test_game_manager_routes_through_system() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.inventory_sys is InventorySystem, "GameManager should own an InventorySystem")
	_ok(gm.inventory == gm.inventory_sys.materials, "gm.inventory should reference the system stock")
	var before: int = gm.inventory_sys.get_count("ale")
	gm.add_to_inventory("ale", 2)
	_ok(gm.inventory_sys.get_count("ale") == before + 2, "add_to_inventory should route through system")
	_ok(int(gm.inventory.get("ale", 0)) == before + 2, "gm.inventory read view should reflect the write")
	_ok(gm.remove_from_inventory("ale", 2), "remove_from_inventory should route through system")
	_ok(gm.inventory_sys.get_count("ale") == before, "remove should restore previous count")
	gm.add_to_inventory("sleep_powder", 1)
	_ok(gm.narrative.dialogue_vars.get("has_sleep_powder", false) == true, "adding sleep_powder should set has_sleep_powder narrative flag")
	gm.remove_from_inventory("sleep_powder", 1)


func _test_shortcut_bindings_are_item_key_references() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	_ok(gm.has_method("get_shortcut_bindings"), "GameManager exposes shortcut binding snapshot")
	_ok(gm.has_method("bind_shortcut_item"), "GameManager exposes shortcut bind API")
	_ok(gm.has_method("can_bind_shortcut_item"), "GameManager exposes shortcut bind validation")
	var defaults: Array = gm.get_shortcut_bindings()
	_ok(defaults.size() == 10, "shortcut binding array has ten slots")
	_ok(defaults[0] == "ale", "default slot0 is ale")
	_ok(defaults[1] == "grape", "default slot1 is grape")
	_ok(gm.can_bind_shortcut_item("north_sour_grape"), "rare material can bind to shortcut")
	_ok(not gm.can_bind_shortcut_item("toby_contract"), "story item cannot bind to shortcut")
	_ok(not gm.can_bind_shortcut_item("wine"), "product cannot bind to shortcut")
	_ok(gm.bind_shortcut_item(0, "north_sour_grape"), "binding rare material succeeds")
	_ok(gm.get_shortcut_bindings()[0] == "north_sour_grape", "slot0 stores rare material key")
	_ok(gm.bind_shortcut_item(1, "north_sour_grape"), "rebinding same key to another slot succeeds")
	var moved: Array = gm.get_shortcut_bindings()
	_ok(moved[0] == "", "old duplicate binding is cleared")
	_ok(moved[1] == "north_sour_grape", "new duplicate binding is kept")
	_ok(not gm.bind_shortcut_item(2, "wine"), "binding product fails")
