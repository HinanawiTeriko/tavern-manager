extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_load_intro()
	_test_handoff_flag()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-INTRO] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-INTRO] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-INTRO] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_load_intro() -> void:
	var data := IntroSequence.load_intro("res://data/intro.json")
	_ok(data.has("beats"), "load_intro returns dict with beats")
	var beats: Array = data["beats"]
	_ok(beats.size() >= 4, "intro has at least 4 beats")
	_ok(beats[0].has("text") and beats[0].has("fade_in") and beats[0].has("hold"), "beat carries text/fade_in/hold")
	_ok(String(beats[beats.size() - 1].get("text", "")).contains("推开"), "last beat is the door-push (match-cut anchor)")
	_ok(beats[beats.size() - 1].get("camera", null) != null, "last beat carries a camera segment")
	var empty := IntroSequence.load_intro("res://data/__no_such__.json")
	_ok(empty.get("beats", []).is_empty(), "missing file degrades to empty beats")


func _test_handoff_flag() -> void:
	var gm = get_node("/root/GameManager")
	# 默认不交接
	_ok(gm.consume_intro_handoff() == false, "handoff defaults to false")
	# 置位后只兑现一次
	gm._pending_intro_handoff = true
	_ok(gm.consume_intro_handoff() == true, "first consume returns true")
	_ok(gm.consume_intro_handoff() == false, "second consume returns false (one-shot)")
