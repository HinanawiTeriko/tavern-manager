extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var file := FileAccess.open("res://data/tutorial_steps.json", FileAccess.READ)
	_ok(file != null, "tutorial data exists")
	if file == null:
		_finish()
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_ok(parsed is Dictionary, "tutorial data parses")
	if not parsed is Dictionary:
		_finish()
		return
	var text := JSON.stringify(parsed)
	for stale in ["[+]", "[-]", "分配体力", "合成台", "混合区", "结果槽", "撒粉区"]:
		_ok(not text.contains(stale), "stale tutorial term removed: " + stale)
	_test_daymap_tutorial_matches_current_continue_flow(parsed)
	for required in ["访问", "酒桶", "右键", "整理桌面", "Tab", "E"]:
		_ok(text.contains(required), "Ryan slice tutorial mentions: " + required)
	_finish()


func _test_daymap_tutorial_matches_current_continue_flow(parsed: Dictionary) -> void:
	var gather_steps: Array = parsed.get("gather", [])
	var ids := []
	var text := JSON.stringify(gather_steps)
	for step in gather_steps:
		ids.append(String(step.get("id", "")))
		_ok(String(step.get("highlight_node", "")) != "GoButton",
			"daymap tutorial must not point to removed GoButton")
		_ok(String(step.get("title", "")) != "进入夜晚",
			"daymap tutorial must not show removed 进入夜晚 step")
	_ok(not ids.has("gather_go"), "daymap tutorial removes stale gather_go step")
	_ok(not text.contains("继续 → 夜晚"), "daymap tutorial must not mention removed continue-to-night flow")
	_ok(text.contains("你的酒馆") and text.contains("开门营业"),
		"daymap tutorial explains the current tavern marker night-entry flow")


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RYAN-TUTORIAL] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RYAN-TUTORIAL] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RYAN-TUTORIAL] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
