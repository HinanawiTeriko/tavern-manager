extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_day2_investigation_chain()
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
