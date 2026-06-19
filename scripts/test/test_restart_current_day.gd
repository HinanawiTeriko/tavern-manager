extends Node

var _checks := 0
var _failures := 0
var _had_original_save := false
var _original_save: Dictionary = {}


func _ready() -> void:
	var gm = get_node("/root/GameManager")
	_had_original_save = gm.save_sys.has_save()
	_original_save = gm.save_sys.read()
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 2
	gm.start_day_map(2)
	gm.economy.gold = 200
	_ok(gm.has_method("capture_day_start_snapshot"), "GameManager exposes capture_day_start_snapshot")
	_ok(gm.has_method("add_current_day_event"), "GameManager exposes add_current_day_event")
	_ok(gm.has_method("get_current_day_events"), "GameManager exposes get_current_day_events")
	_ok(gm.has_method("get_today_rumors"), "GameManager exposes today rumor lookup")
	if not gm.has_method("capture_day_start_snapshot") \
		or not gm.has_method("add_current_day_event") \
		or not gm.has_method("get_current_day_events") \
		or not gm.has_method("get_today_rumors"):
		_finish()
		return
	var initial_ale_count: int = gm.inventory_sys.get_count("ale")
	gm.capture_day_start_snapshot()
	_ok(gm.buy_material("ale", 2), "buying material succeeds")
	_ok(gm.buy_recipe_unlock("herbal_ale"), "buying recipe unlock succeeds")
	_ok(gm.buy_ability("slam_pot"), "buying ability succeeds")
	var visit_result: Dictionary = gm.visit_day_location("mushroom_forest")
	_ok(bool(visit_result.get("success", false)), "visiting day location succeeds")
	gm.narrative.set_var("ryan_warhammer_lead", true)
	_force_location_wind_chance(gm, "mercenary_board", 1.0)
	var rumor_result: Dictionary = gm.visit_day_location("mercenary_board")
	_ok(bool(rumor_result.get("success", false)), "visiting rumor location succeeds")
	_ok(rumor_result.has("rumor"), "day visit can grant a rumor after checkpoint")
	_ok(gm.get_today_rumors().size() > 0, "rumor is active before restart")
	gm.economy.add_gold(12)
	gm.narrative.set_var("ryan_informed", true)
	var event_types := _event_types(gm.get_current_day_events())
	_ok(event_types.has("purchase_material"), "event log records material purchases")
	_ok(event_types.has("recipe_unlock"), "event log records recipe unlocks")
	_ok(event_types.has("ability_unlock"), "event log records ability unlocks")
	_ok(event_types.has("location"), "event log records day map visits")

	gm.restart_current_day()

	_ok(gm.economy.current_day == 2, "restart keeps current day")
	_ok(gm.day_cycle.phase == DayCycleSystem.DayPhase.DAY, "restart returns to day phase")
	_ok(gm.economy.gold == 200, "restart restores gold from morning checkpoint")
	_ok(not gm.craft.is_recipe_unlocked("herbal_ale"), "restart restores recipe unlocks from morning checkpoint")
	_ok(not gm.craft.is_slam_unlocked("pot"), "restart restores ability unlocks from morning checkpoint")
	_ok(gm.inventory_sys.get_count("ale") == initial_ale_count, "restart restores purchased materials from morning checkpoint")
	_ok(gm.inventory_sys.get_count("sleep_powder") == 0, "restart restores inventory from morning checkpoint")
	_ok(gm.narrative.get_var("ryan_informed") == false, "restart restores narrative vars from morning checkpoint")
	_ok(gm.get_today_rumors().is_empty(), "restart restores rumors from morning checkpoint")
	_ok(gm.get_current_day_events().is_empty(), "restart clears event log")
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RESTART-DAY] FAIL: " + msg)


func _event_types(events: Array) -> Array[String]:
	var types: Array[String] = []
	for event in events:
		if not event is Dictionary:
			continue
		var event_type := String((event as Dictionary).get("type", ""))
		if event_type != "" and not types.has(event_type):
			types.append(event_type)
	return types


func _force_location_wind_chance(gm: Node, location_id: String, chance: float) -> void:
	if gm == null or gm.day_map == null or not gm.day_map._locations.has(location_id):
		return
	var location: Dictionary = gm.day_map._locations[location_id].duplicate(true)
	location["windChance"] = chance
	gm.day_map._locations[location_id] = location


func _finish() -> void:
	_restore_original_save()
	if _failures == 0:
		print("[TEST-RESTART-DAY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RESTART-DAY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _restore_original_save() -> void:
	var gm = get_node("/root/GameManager")
	if _had_original_save:
		gm.save_sys.write(_original_save)
	else:
		gm.save_sys.clear()
