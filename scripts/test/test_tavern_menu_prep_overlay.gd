extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_overlay_menu_remains_clickable_during_menu_preparation()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TAVERN-MENU-PREP-OVERLAY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TAVERN-MENU-PREP-OVERLAY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TAVERN-MENU-PREP-OVERLAY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_overlay_menu_remains_clickable_during_menu_preparation() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame

	tavern.configure_menu_preparation([], [])
	await get_tree().process_frame

	var prep_panel := tavern.get_node_or_null("MenuPrepPanel") as Control
	var overlay_menu := tavern.get_node("OverlayMenu") as Control
	_ok(prep_panel != null and prep_panel.visible, "menu preparation panel is visible before opening the legacy menu")
	_ok(not overlay_menu.visible, "legacy overlay menu starts closed")

	tavern.toggle_menu()
	await get_tree().process_frame

	_ok(overlay_menu.visible, "legacy overlay menu opens during menu preparation")
	_ok(prep_panel != null and not prep_panel.visible,
		"menu preparation panel stops blocking input while the legacy overlay menu is open")
	_ok(tavern.get_children().find(overlay_menu) > tavern.get_children().find(prep_panel),
		"legacy overlay menu is above the menu preparation panel in GUI input order")

	tavern.toggle_menu()
	await get_tree().process_frame
	_ok(not overlay_menu.visible, "legacy overlay menu closes from menu toggle during menu preparation")
	_ok(prep_panel != null and prep_panel.visible, "menu preparation panel remains available after closing the legacy menu")

	tavern.queue_free()
	await get_tree().process_frame
