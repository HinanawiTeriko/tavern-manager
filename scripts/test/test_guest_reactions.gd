extends Node

## GuestSystem 反应台词池单元测：每个 outcome 都能取到非空台词，未知 outcome 安全兜底。

var _checks := 0
var _failures := 0

func _ready() -> void:
	_test_known_outcomes()
	_test_unknown_outcome_safe()
	_finish()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-GUEST-REACT] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-GUEST-REACT] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-GUEST-REACT] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)

func _gm():
	return get_node("/root/GameManager")

func _test_known_outcomes() -> void:
	var g = _gm().guests
	for outcome in ["success", "fail_wrong", "fail_weird", "impatient"]:
		var line: String = g.get_reaction_line(outcome, "")
		_ok(line != "", outcome + " 返回非空台词")

func _test_unknown_outcome_safe() -> void:
	var g = _gm().guests
	var line: String = g.get_reaction_line("nonexistent_outcome", "")
	_ok(line != "", "未知 outcome 也返回非空兜底台词")
