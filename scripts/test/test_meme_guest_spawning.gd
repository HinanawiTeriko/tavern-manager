extends Node

const GuestSystem := preload("res://scripts/systems/guest_system.gd")

var _checks := 0
var _failures := 0


func _ready() -> void:
	_check_meme_guest_data_and_spawn_contract()
	_finish()


func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _menu_items() -> Array:
	return [
		{
			"key": "hearty_stew",
			"name": "Hearty Stew",
			"price": 12,
			"tags": ["main"],
			"flavor_tags": ["savory"]
		}
	]


func _check_meme_guest_data_and_spawn_contract() -> void:
	var system = GuestSystem.new(Callable(self, "_menu_items"))
	_ok(system.has_method("_meme_guest_entries_for_day"), "meme guest day query should exist")
	_ok(system.has_method("_spawn_meme_guest"), "meme guest spawn helper should exist")
	if not system.has_method("_meme_guest_entries_for_day") or not system.has_method("_spawn_meme_guest"):
		return

	var meme_entries: Array = system.call("_meme_guest_entries_for_day", 1)
	_ok(meme_entries.size() >= 2, "meme guests should be available on day 1")

	var doge := {}
	var snack_cat := {}
	for entry in meme_entries:
		if String(entry.get("id", "")) == "meme_doge":
			doge = entry
		if String(entry.get("id", "")) == "meme_snack_cat":
			snack_cat = entry

	_ok(not doge.is_empty(), "meme_doge should load")
	_ok(not snack_cat.is_empty(), "meme_snack_cat should load")
	if doge.is_empty() or snack_cat.is_empty():
		return

	system.call("_spawn_meme_guest", doge, _menu_items())
	var doge_guest = system.current_guest
	_ok(system.has_guest, "doge should set has_guest")
	_ok(doge_guest != null, "doge should spawn")
	_ok(String(doge_guest.npc_id) == "meme_doge", "doge npc_id should match portrait key")
	_ok(String(doge_guest.get_meta("meme_guest_id", "")) == "meme_doge", "doge should carry meme_guest_id")
	_ok(String(doge_guest.get_meta("physics_law_id", "")) == "low_gravity", "doge should carry low gravity law")
	_ok(String(doge_guest.get_meta("portrait_id", "")) == "meme_doge", "doge should carry portrait id")
	_ok(String(doge_guest.get_meta("regular_customer_id", "")) == "", "meme guests should not enter regular-customer memory")

	var cat_system = GuestSystem.new(Callable(self, "_menu_items"))
	cat_system.call("_spawn_meme_guest", snack_cat, _menu_items())
	var cat_guest = cat_system.current_guest
	_ok(cat_system.has_guest, "snack cat should set has_guest")
	_ok(cat_guest != null, "snack cat should spawn")
	_ok(String(cat_guest.npc_id) == "meme_snack_cat", "snack cat npc_id should match portrait key")
	_ok(String(cat_guest.get_meta("physics_law_id", "")) == "heavy_gravity", "snack cat should carry heavy gravity law")


func _finish() -> void:
	print("Meme guest spawn checks: %d failures: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
