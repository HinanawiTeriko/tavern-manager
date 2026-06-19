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
	_ok(meme_entries.size() >= 8, "eight meme guests should be available on day 1")

	var doge := {}
	var snack_cat := {}
	var cheems := {}
	var popcat := {}
	var tomori_penguin := {}
	var doro := {}
	var anon_face := {}
	var yellow_laugh := {}
	var expected_new_laws := {
		"meme_tomori_penguin": "gugu_waddle_physics",
		"meme_doro": "orunji_bounce_physics",
		"meme_anon_face": "anon_hia_laugh_physics",
		"meme_yellow_laugh": "nailong_belly_laugh_physics",
	}
	var expected_new_arrival_lines := {
		"meme_tomori_penguin": "咕咕嘎嘎。",
		"meme_doro": "欧润吉。",
		"meme_anon_face": "hii... hia?",
		"meme_yellow_laugh": "哈哈哈哈哈！",
	}
	var expected_new_success_lines := {
		"meme_tomori_penguin": "咕咕嘎嘎！",
		"meme_doro": "欧润吉！",
		"meme_anon_face": "hiiiiiii! hiaaaaaa!",
		"meme_yellow_laugh": "哈哈哈哈哈哈！",
	}
	for entry in meme_entries:
		if String(entry.get("id", "")) == "meme_doge":
			doge = entry
		if String(entry.get("id", "")) == "meme_snack_cat":
			snack_cat = entry
		if String(entry.get("id", "")) == "meme_cheems":
			cheems = entry
		if String(entry.get("id", "")) == "meme_popcat":
			popcat = entry
		if String(entry.get("id", "")) == "meme_tomori_penguin":
			tomori_penguin = entry
		if String(entry.get("id", "")) == "meme_doro":
			doro = entry
		if String(entry.get("id", "")) == "meme_anon_face":
			anon_face = entry
		if String(entry.get("id", "")) == "meme_yellow_laugh":
			yellow_laugh = entry

	_ok(not doge.is_empty(), "meme_doge should load")
	_ok(not snack_cat.is_empty(), "meme_snack_cat should load")
	_ok(not cheems.is_empty(), "meme_cheems should load")
	_ok(not popcat.is_empty(), "meme_popcat should load")
	_ok(not tomori_penguin.is_empty(), "meme_tomori_penguin should load")
	_ok(not doro.is_empty(), "meme_doro should load")
	_ok(not anon_face.is_empty(), "meme_anon_face should load")
	_ok(not yellow_laugh.is_empty(), "meme_yellow_laugh should load")
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
	_ok(String(doge_guest.get_meta("arrival_line", "")) != "", "doge should carry animal-like arrival line")
	_ok(String(doge_guest.get_meta("regular_customer_id", "")) == "", "meme guests should not enter regular-customer memory")
	_ok(not doge_guest.has_dialogue, "meme guest arrival lines should not use important NPC dialogue flow")
	_ok(
		system.get_reaction_line("success", doge_guest.npc_id) == "wow... such serve. very snack.",
		"doge should use meme-specific success reaction after delivery")

	var cat_system = GuestSystem.new(Callable(self, "_menu_items"))
	cat_system.call("_spawn_meme_guest", snack_cat, _menu_items())
	var cat_guest = cat_system.current_guest
	_ok(cat_system.has_guest, "snack cat should set has_guest")
	_ok(cat_guest != null, "snack cat should spawn")
	_ok(String(cat_guest.npc_id) == "meme_snack_cat", "snack cat npc_id should match portrait key")
	_ok(String(cat_guest.get_meta("physics_law_id", "")) == "heavy_gravity", "snack cat should carry heavy gravity law")
	_ok(String(cat_guest.get_meta("arrival_line", "")) != "", "snack cat should carry animal-like arrival line")
	_ok(not cat_guest.has_dialogue, "snack cat should stay outside important NPC dialogue flow")
	_ok(
		cat_system.get_reaction_line("success", cat_guest.npc_id) == "mrrp. crunch crunch. mine.",
		"snack cat should use meme-specific success reaction after delivery")

	if cheems.is_empty() or popcat.is_empty():
		return

	var cheems_system = GuestSystem.new(Callable(self, "_menu_items"))
	cheems_system.call("_spawn_meme_guest", cheems, _menu_items())
	var cheems_guest = cheems_system.current_guest
	_ok(cheems_system.has_guest, "cheems should set has_guest")
	_ok(cheems_guest != null, "cheems should spawn")
	_ok(String(cheems_guest.npc_id) == "meme_cheems", "cheems npc_id should match portrait key")
	_ok(String(cheems_guest.get_meta("physics_law_id", "")) == "slippery_physics", "cheems should carry slippery physics law")
	_ok(String(cheems_guest.get_meta("arrival_line", "")) != "", "cheems should carry animal-like arrival line")
	_ok(not cheems_guest.has_dialogue, "cheems should stay outside important NPC dialogue flow")
	_ok(
		cheems_system.get_reaction_line("fail_wrong", cheems_guest.npc_id) == "bonk... wrong noms.",
		"cheems should use meme-specific wrong-order reaction after delivery")

	var popcat_system = GuestSystem.new(Callable(self, "_menu_items"))
	popcat_system.call("_spawn_meme_guest", popcat, _menu_items())
	var popcat_guest = popcat_system.current_guest
	_ok(popcat_system.has_guest, "popcat should set has_guest")
	_ok(popcat_guest != null, "popcat should spawn")
	_ok(String(popcat_guest.npc_id) == "meme_popcat", "popcat npc_id should match portrait key")
	_ok(String(popcat_guest.get_meta("physics_law_id", "")) == "bouncy_physics", "popcat should carry bouncy physics law")
	_ok(String(popcat_guest.get_meta("arrival_line", "")) != "", "popcat should carry animal-like arrival line")
	_ok(not popcat_guest.has_dialogue, "popcat should stay outside important NPC dialogue flow")
	_ok(
		popcat_system.get_reaction_line("success", popcat_guest.npc_id) == "pop. pop. POP!",
		"popcat should use meme-specific success reaction after delivery")

	for new_entry in [tomori_penguin, doro, anon_face, yellow_laugh]:
		if new_entry.is_empty():
			continue
		var guest_system = GuestSystem.new(Callable(self, "_menu_items"))
		guest_system.call("_spawn_meme_guest", new_entry, _menu_items())
		var guest = guest_system.current_guest
		var meme_id := String(new_entry.get("id", ""))
		_ok(guest_system.has_guest, meme_id + " should set has_guest")
		_ok(guest != null, meme_id + " should spawn")
		if guest == null:
			continue
		_ok(String(guest.npc_id) == meme_id, meme_id + " npc_id should match portrait key")
		_ok(String(guest.get_meta("meme_guest_id", "")) == meme_id, meme_id + " should carry meme_guest_id")
		_ok(String(guest.get_meta("portrait_id", "")) == meme_id, meme_id + " should carry portrait id")
		_ok(
			String(guest.get_meta("physics_law_id", "")) == String(expected_new_laws.get(meme_id, "")),
			meme_id + " should carry its themed physics law")
		_ok(
			String(guest.get_meta("arrival_line", "")) == String(expected_new_arrival_lines.get(meme_id, "")),
			meme_id + " should carry its designed arrival line")
		_ok(not guest.has_dialogue, meme_id + " should stay outside important NPC dialogue flow")
		_ok(
			guest_system.get_reaction_line("success", guest.npc_id) == String(expected_new_success_lines.get(meme_id, "")),
			meme_id + " should use its designed success reaction")


func _finish() -> void:
	print("Meme guest spawn checks: %d failures: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
