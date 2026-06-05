extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var day_map_scene := preload("res://scenes/ui/DayMap.tscn")
	var view = day_map_scene.instantiate()
	add_child(view)
	await get_tree().process_frame
	_test_document_buttons(view.get_node("UILayer/DocumentOverlay"))
	_test_ledger_buttons(view.get_node("UILayer/DocumentOverlay"))
	view.queue_free()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DOCUMENT-OVERLAY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DOCUMENT-OVERLAY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DOCUMENT-OVERLAY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_document_buttons(overlay: DocumentOverlay) -> void:
	overlay.open_document({"kind": "evidence", "pages": ["document page 1", "document page 2"]})
	var previous_button: Button = overlay.get_node("Panel/PreviousBtn")
	var next_button: Button = overlay.get_node("Panel/NextBtn")
	_ok(previous_button.disabled, "document previous button starts disabled")
	_ok(not next_button.disabled, "document next button is enabled with a second page")
	next_button.pressed.emit()
	_ok(overlay.get_current_page_text() == "document page 2", "document next button opens the second page")
	_ok(next_button.disabled, "document next button disables on the last page")
	_ok(not previous_button.disabled, "document previous button enables after advancing")
	previous_button.pressed.emit()
	_ok(overlay.get_current_page_text() == "document page 1", "document previous button returns to the first page")


func _test_ledger_buttons(overlay: DocumentOverlay) -> void:
	overlay.open_document({"kind": "ledger", "pages": ["ledger page 1", "ledger page 2", "ledger page 3"]})
	var previous_button: Button = overlay.get_node("Panel/PreviousBtn")
	var next_button: Button = overlay.get_node("Panel/NextBtn")
	_ok(overlay.get_current_page_text() == "ledger page 1", "ledger opens the left page")
	_ok(overlay.get_right_page_text() == "ledger page 2", "ledger opens the right page")
	_ok(not next_button.disabled, "ledger next button is enabled with a third page")
	next_button.pressed.emit()
	_ok(overlay.get_current_page_text() == "ledger page 3", "ledger next button advances by one spread")
	_ok(overlay.get_right_page_text() == "", "ledger leaves the final right page blank")
	_ok(not previous_button.disabled, "ledger previous button enables after advancing")
	previous_button.pressed.emit()
	_ok(overlay.get_current_page_text() == "ledger page 1", "ledger previous button returns to the first spread")
