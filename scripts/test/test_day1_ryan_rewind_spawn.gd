extends Node

var _checks := 0
var _failures := 0
var _tutorial_backup: Dictionary = {}


func _ready() -> void:
	var gm = get_node("/root/GameManager")
	var tm = get_node("/root/TutorialManager")
	_tutorial_backup = _capture_tutorial(tm)

	_ok(gm.has_method("_should_defer_important_guest_for_tutorial"), "GameManager exposes tutorial defer guard")
	if not gm.has_method("_should_defer_important_guest_for_tutorial"):
		_finish()
		return

	tm.tavern_first_entered = false
	tm._completed_steps = ["craft_intro", "craft_drag", "craft_recovery"]
	_ok(not gm._should_defer_important_guest_for_tutorial(tm), "Day 1 rewind does not defer Ryan when craft tutorial is already complete")

	tm.tavern_first_entered = false
	tm._completed_steps = []
	_ok(gm._should_defer_important_guest_for_tutorial(tm), "first real tavern entry still defers important NPC for craft tutorial")

	tm.tavern_first_entered = true
	tm._completed_steps = []
	_ok(not gm._should_defer_important_guest_for_tutorial(tm), "later tavern entries do not defer important NPC for first-entry tutorial")

	_finish()


func _capture_tutorial(tm: Node) -> Dictionary:
	return {
		"completed_steps": tm._completed_steps.duplicate(),
		"tavern_first_entered": tm.tavern_first_entered,
		"is_active": tm._is_active,
	}


func _restore_tutorial() -> void:
	if _tutorial_backup.is_empty():
		return
	var tm = get_node("/root/TutorialManager")
	tm._completed_steps = (_tutorial_backup.get("completed_steps", []) as Array).duplicate()
	tm.tavern_first_entered = bool(_tutorial_backup.get("tavern_first_entered", false))
	tm._is_active = bool(_tutorial_backup.get("is_active", false))


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DAY1-RYAN-REWIND] FAIL: " + msg)


func _finish() -> void:
	_restore_tutorial()
	if _failures == 0:
		print("[TEST-DAY1-RYAN-REWIND] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DAY1-RYAN-REWIND] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
