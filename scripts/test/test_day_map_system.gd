extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_day2_investigation_chain()
	_test_game_manager_routes_visits()
	_test_get_locations_breadcrumb()
	_test_board_requires_lead()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DAYMAP] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DAYMAP] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DAYMAP] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_day2_investigation_chain() -> void:
	var map := DayMapSystem.new()
	_ok(map.load_data(), "locations data loads")
	map.start_day(2)
	map.set_lead_flag("ryan_warhammer_lead", true)
	_ok(map.stamina == 4, "day2 starts with four stamina")
	_ok(not map.visit("abandoned_mine").get("success", false), "mine is blocked before board clue")
	_ok(map.stamina == 4, "blocked visit does not spend stamina")
	var board := map.visit("mercenary_board")
	_ok(board.get("success", false), "board visit succeeds")
	_ok(map.stamina == 3, "board spends one stamina")
	var mine := map.visit("abandoned_mine")
	_ok(mine.get("documents", []).has("bloodied_contract"), "mine grants bloodied contract")
	_ok(not map.visit("guild_counter").get("success", false), "guild counter requires read evidence")
	map.set_document_read("bloodied_contract", true)
	var counter := map.visit("guild_counter")
	_ok(counter.get("documents", []).has("alternative_contract"), "counter grants alternative contract")
	_ok(map.stamina == 0, "positive route spends all day2 stamina")

	map.start_day(2)
	var forest := map.visit("mushroom_forest")
	_ok(forest.get("rewards", []).has("sleep_powder"), "day2 mushroom forest grants sleep powder")


func _test_game_manager_routes_visits() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.day_map is DayMapSystem, "GameManager owns DayMapSystem")
	gm.start_day_map(2)
	var before: int = gm.inventory_sys.get_count("sleep_powder")
	_ok(gm.visit_day_location("mushroom_forest").get("success", false), "GameManager routes forest visit")
	_ok(gm.inventory_sys.get_count("sleep_powder") == before + 1, "forest reward enters inventory")
	_ok(gm.narrative.get_var("has_sleep_powder") == true, "forest reward triggers narrative hook")
	gm.narrative.set_var("ryan_warhammer_lead", true)
	gm.start_day_map(2)
	_ok(_location_ids(gm.day_map.get_locations()).has("mercenary_board"), "GM exposes board after lead set")
	gm.visit_day_location("mercenary_board")
	gm.visit_day_location("abandoned_mine")
	_ok(gm.documents.owns_document("bloodied_contract"), "mine document enters DocumentSystem")
	_ok(gm.inventory_sys.get_count("bloodied_contract") == 0, "evidence not in story bag before reading")
	gm.request_open_document("bloodied_contract")
	_ok(gm.inventory_sys.get_count("bloodied_contract") == 1, "read evidence enters story bag (spec 8.3)")
	gm.request_open_document("bloodied_contract")
	_ok(gm.inventory_sys.get_count("bloodied_contract") == 1, "re-reading evidence does not duplicate it")
	gm.visit_day_location("guild_counter")
	_ok(gm.documents.owns_document("alternative_contract"), "read evidence unlocks counter document")


func _location_ids(locations: Array) -> Array:
	var ids := []
	for loc in locations:
		ids.append(String(loc.get("id", "")))
	return ids


func _test_get_locations_breadcrumb() -> void:
	var map := DayMapSystem.new()
	map.load_data()
	map.start_day(2)
	map.set_lead_flag("ryan_warhammer_lead", true)
	var ids_before := _location_ids(map.get_locations())
	_ok(not ids_before.has("abandoned_mine"), "mine hidden before board clue")
	_ok(not ids_before.has("guild_counter"), "counter hidden before reading evidence")
	_ok(ids_before.has("mercenary_board"), "board visible with lead")
	map.visit("mercenary_board")
	var ids_after_board := _location_ids(map.get_locations())
	_ok(ids_after_board.has("abandoned_mine"), "mine appears after board clue")
	_ok(not ids_after_board.has("guild_counter"), "counter still hidden before read")
	map.visit("abandoned_mine")
	map.set_document_read("bloodied_contract", true)
	var ids_after_read := _location_ids(map.get_locations())
	_ok(ids_after_read.has("guild_counter"), "counter appears after reading evidence")


func _test_board_requires_lead() -> void:
	var map := DayMapSystem.new()
	map.load_data()
	map.start_day(2)
	_ok(not _location_ids(map.get_locations()).has("mercenary_board"), "board hidden without lead")
	_ok(not map.visit("mercenary_board").get("success", false), "board blocked without lead")
	map.set_lead_flag("ryan_warhammer_lead", true)
	_ok(_location_ids(map.get_locations()).has("mercenary_board"), "board appears with lead")
	_ok(map.visit("mercenary_board").get("success", false), "board visit succeeds with lead")
