extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_container_unlock_by_day()
	_test_recovery_target_by_capability()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-WORKSPACE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-WORKSPACE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-WORKSPACE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_container_unlock_by_day() -> void:
	var ws := WorkspaceSystem.new()
	_ok(ws.unlocked_containers(1) == ["barrel"], "day1 unlocks barrel only")
	_ok(ws.unlocked_containers(2) == ["barrel", "grill"], "day2 unlocks barrel+grill")
	_ok(ws.unlocked_containers(3) == ["barrel", "grill", "pot", "spoon"], "day3 unlocks all")
	_ok(ws.is_container_unlocked("grill", 2), "grill unlocked on day2")
	_ok(not ws.is_container_unlocked("pot", 2), "pot locked on day2")


func _test_recovery_target_by_capability() -> void:
	var ws := WorkspaceSystem.new()
	_ok(ws.recovery_target(["material"]) == "backpack", "material -> backpack")
	_ok(ws.recovery_target(["story_item"]) == "backpack", "story_item -> backpack")
	_ok(ws.recovery_target(["product"]) == "recycle", "product -> recycle")
	_ok(ws.recovery_target(["tool"]) == "dock", "tool -> dock")
	_ok(ws.recovery_target(["container"]) == "dock", "container -> dock")
	_ok(ws.recovery_target(["readable"]) == "doc_dock", "readable -> doc_dock")
	_ok(ws.recovery_target(["story_item", "readable"]) == "backpack", "story+readable -> backpack (story wins)")
	_ok(ws.recovery_target([]) == "backpack", "empty caps -> backpack (safe default)")
