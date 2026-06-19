extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_daily_wind_repeats_across_days()
	_test_same_location_grants_only_one_wind_per_day()
	_test_daily_wind_restore_preserves_same_day_cap()
	_test_wind_pool_depth()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RUMOR-DAILY-WIND] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RUMOR-DAILY-WIND] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RUMOR-DAILY-WIND] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _new_rumor_system():
	var script := load("res://scripts/systems/rumor_system.gd")
	_ok(script != null, "RumorSystem script loads")
	if script == null:
		return null
	var rumors = script.new()
	_ok(rumors.load_data(), "rumor data loads")
	return rumors


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_ok(file != null, "json file is readable: " + path)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_ok(parsed is Dictionary, "json file parses as dictionary: " + path)
	if not parsed is Dictionary:
		return {}
	return parsed


func _test_daily_wind_repeats_across_days() -> void:
	var rumors = _new_rumor_system()
	if rumors == null:
		return
	rumors.start_day(2)
	var day_two: Dictionary = rumors.grant_location_rumor("mercenary_board", 2, {"ryan_warhammer_lead": true})
	_ok(bool(day_two.get("success", false)), "day two board wind is available")
	_ok(String(day_two.get("id", "")) == "mercenary_board_mine_shift", "day two board wind uses the Ryan lead rumor")
	var same_day: Dictionary = rumors.grant_location_rumor("mercenary_board", 2, {"ryan_warhammer_lead": true})
	_ok(not bool(same_day.get("success", true)), "same board wind does not repeat on the same day")
	rumors.start_day(3)
	var next_day: Dictionary = rumors.grant_location_rumor("mercenary_board", 3, {"ryan_warhammer_lead": true})
	_ok(bool(next_day.get("success", false)), "board wind can repeat on a later day")
	_ok(String(next_day.get("id", "")) == "mercenary_board_mine_shift",
		"later-day board wind can reuse the current rumor when no newer one is available")
	rumors.start_day(4)
	var day_four: Dictionary = rumors.grant_location_rumor("mercenary_board", 4, {"ryan_warhammer_lead": true})
	_ok(bool(day_four.get("success", false)), "board wind grants again when a newer entry opens")
	_ok(String(day_four.get("id", "")) == "mercenary_board_quarry_breakfast",
		"newly opened board wind is preferred over repeating an older rumor")


func _test_same_location_grants_only_one_wind_per_day() -> void:
	var rumors = _new_rumor_system()
	if rumors == null:
		return
	rumors.start_day(18)
	var first: Dictionary = rumors.grant_location_rumor("mushroom_forest", 18)
	_ok(bool(first.get("success", false)), "day eighteen forest wind grants one eligible rumor")
	_ok(String(first.get("id", "")) == "mushroom_forest_sleepy_pollen_watch",
		"latest eligible forest wind is chosen first")
	var second: Dictionary = rumors.grant_location_rumor("mushroom_forest", 18)
	_ok(not bool(second.get("success", true)),
		"same location grants at most one wind notice per day even if several entries are eligible")
	rumors.start_day(19)
	var repeated: Dictionary = rumors.grant_location_rumor("mushroom_forest", 19)
	_ok(bool(repeated.get("success", false)), "latest forest wind can repeat on a later day")


func _test_daily_wind_restore_preserves_same_day_cap() -> void:
	var rumors = _new_rumor_system()
	if rumors == null:
		return
	rumors.start_day(2)
	rumors.grant_location_rumor("mercenary_board", 2, {"ryan_warhammer_lead": true})
	var restored = _new_rumor_system()
	if restored == null:
		return
	restored.restore_state(rumors.capture_state())
	var same_day: Dictionary = restored.grant_location_rumor("mercenary_board", 2, {"ryan_warhammer_lead": true})
	_ok(not bool(same_day.get("success", true)), "restored state keeps the same-day location cap")
	restored.start_day(3)
	var next_day: Dictionary = restored.grant_location_rumor("mercenary_board", 3, {"ryan_warhammer_lead": true})
	_ok(bool(next_day.get("success", false)), "restored heard wind can repeat on the next day")


func _test_wind_pool_depth() -> void:
	var data := _load_json_dictionary("res://data/rumors.json")
	var rumor_list: Array = data.get("rumors", [])
	_ok(rumor_list.size() >= 36, "rumor pool has enough entries for a longer day-map loop")
	var by_location: Dictionary = {}
	var late_count := 0
	for raw in rumor_list:
		if not raw is Dictionary:
			continue
		var rumor: Dictionary = raw
		var location_id := String(rumor.get("location", ""))
		by_location[location_id] = int(by_location.get(location_id, 0)) + 1
		if int(rumor.get("dayMin", 1)) >= 14:
			late_count += 1
	for location_id in ["mushroom_forest", "dark_river", "grape_trellis", "mill_farm"]:
		_ok(int(by_location.get(location_id, 0)) >= 4,
			"repeatable material location has a deeper wind pool: " + location_id)
	for location_id in ["market_shop", "mercenary_board"]:
		_ok(int(by_location.get(location_id, 0)) >= 6,
			"frequent town location has a deeper wind pool: " + location_id)
	_ok(late_count >= 8, "rumor pool keeps adding new wind from day fourteen onward")
