extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_board_postings()
	_finish()


func _test_board_postings() -> void:
	var day1 := _sys(1)
	_ok(_ids(day1.get_locations()).has("mercenary_board"), "Day1 board is visible")
	_ok(_eff(day1, "mercenary_board").get("active_posting", "x") == "", "Day1 board has no active posting")

	var day2_idle := _sys(2)
	_ok(day2_idle.visit("mercenary_board").get("success", false), "idle board can be visited")
	_ok(not _ids(day2_idle.get_locations()).has("abandoned_mine"), "idle board does not unlock mine")

	var day2_lead := _sys(2)
	day2_lead.set_lead_flag("ryan_warhammer_lead", true)
	_ok(_eff(day2_lead, "mercenary_board").get("active_posting", "") == "ryan_warhammer",
		"Day2 Ryan posting activates with lead")
	day2_lead.visit("mercenary_board")
	_ok(_ids(day2_lead.get_locations()).has("abandoned_mine"), "Ryan posting unlocks mine")

	var expired := _sys(2)
	expired.set_lead_flag("ryan_warhammer_lead", true)
	expired.mark_revealed("mercenary_board")
	expired.mark_posting_announced("mercenary_board")
	expired.start_day(3)
	expired.set_lead_flag("ryan_warhammer_lead", true)
	_ok(_eff(expired, "mercenary_board").get("active_posting", "x") == "",
		"expired posting returns board to idle")
	_ok(not _ids(expired.get_updated_locations()).has("mercenary_board"),
		"expired posting does not replay a camera update")
	var expired_visit := expired.visit("mercenary_board")
	_ok(String(expired_visit.get("unlockedFlag", "")) == "", "expired posting has no stale unlock")

	var day6 := _sys(6)
	day6.set_lead_flag("ryan_warhammer_lead", true)
	var day6_board := _eff(day6, "mercenary_board")
	_ok(day6_board.get("active_posting", "") == "toby_commission", "Day6 Toby posting replaces Ryan posting")
	var day6_visit := day6.visit("mercenary_board")
	_ok(String(day6_visit.get("unlockedFlag", "")) == "toby_name_lead", "Day6 board unlocks Toby name lead")
	_ok(String(day6_visit.get("activePosting", "")) == "toby_commission", "Day6 visit reports Toby posting")
	_ok(not _ids(day6.get_locations()).has("toby_lodging"), "Day6 board does not directly reveal Toby lodging")
	_ok(not _ids(day6.get_locations()).has("fixer_den"), "Day6 board does not directly reveal fixer")
	_ok(not (day6_visit.get("documents", []) as Array).has("toby_contract"), "Day6 board does not grant Toby contract")

	var update := _sys(2)
	update.mark_revealed("mercenary_board")
	_ok(not _ids(update.get_updated_locations()).has("mercenary_board"), "freshly revealed idle board has no update")
	update.set_lead_flag("ryan_warhammer_lead", true)
	_ok(_ids(update.get_updated_locations()).has("mercenary_board"), "new active posting enters update list")
	update.mark_posting_announced("mercenary_board")
	_ok(not _ids(update.get_updated_locations()).has("mercenary_board"), "announced active posting does not repeat")

	_ok(not _ids(day6.get_locations()).has("toby_board"), "toby_board is merged into mercenary_board")


func _sys(day: int) -> DayMapSystem:
	var s := DayMapSystem.new()
	s.load_data()
	s.start_day(day)
	return s


func _ids(locs: Array) -> Array:
	var result := []
	for loc in locs:
		result.append(String(loc.get("id", "")))
	return result


func _eff(s: DayMapSystem, id: String) -> Dictionary:
	for loc in s.get_locations():
		if String(loc.get("id", "")) == id:
			return loc
	return {}


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-POSTINGS] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-POSTINGS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-POSTINGS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
