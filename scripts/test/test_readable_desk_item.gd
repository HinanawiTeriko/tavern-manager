extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_double_click_requests_open()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-READABLE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-READABLE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-READABLE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_double_click_requests_open() -> void:
	var item = preload("res://scenes/ui/readable_desk_item.tscn").instantiate()
	add_child(item)
	var opened: Array[String] = []
	item.open_requested.connect(func(document_id: String): opened.append(document_id))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	item._input_event(null, click, 0)
	_ok(opened == ["ledger"], "double click requests ledger open")
