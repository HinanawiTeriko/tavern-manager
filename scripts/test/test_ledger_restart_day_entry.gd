extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var gm = get_node("/root/GameManager")
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null:
		tm.first_ledger_shown = true

	var data := LedgerData.new()
	data.day = 2
	data.gold_today = 12
	data.rep_today = 1
	data.gold_total = 42
	data.rep_total = 3
	data.guests_served = 2
	data.orders_success = 2
	data.orders_failed = 0
	data.guest_entries = []
	data.npc_fates = []
	gm.current_ledger_data = data
	gm.clear_current_day_events()
	gm.add_current_day_event({"type": "location", "label": "测试记录", "detail": "用于结算页"})

	var scene := preload("res://scenes/ui/LedgerScreen.tscn")
	var screen = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame

	_test_restart_button(screen)
	_test_overlay_entry(screen)

	screen.queue_free()
	gm.current_ledger_data = null
	gm.clear_current_day_events()
	await get_tree().process_frame
	_finish()


func _test_restart_button(screen: Node) -> void:
	_ok(screen.get_node_or_null("UI/ContinueBtn") is Button, "ContinueBtn contract remains")
	var button := screen.get_node_or_null("UI/RestartDayBtn") as Button
	_ok(button != null, "RestartDayBtn exists on settlement screen")
	if button == null:
		return
	_ok(button.text == "重写今日", "RestartDayBtn uses Godot-rendered label")
	var font: Font = button.get_theme_font("font")
	_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"), "RestartDayBtn uses pixel font")
	for state in ["normal", "hover", "pressed"]:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		_ok(style != null and style.texture != null, "RestartDayBtn has %s texture style" % state)
		if style != null and style.texture != null:
			_ok(String(style.texture.resource_path).ends_with("assets/textures/ui/restart_day/restart_day_button_%s.png" % state), "RestartDayBtn uses restart day %s art" % state)


func _test_overlay_entry(screen: Node) -> void:
	var button := screen.get_node_or_null("UI/RestartDayBtn") as Button
	var overlay := screen.get_node_or_null("ClockRewindOverlay") as Control
	_ok(overlay != null, "LedgerScreen owns ClockRewindOverlay")
	if button == null or overlay == null:
		return
	_ok(not overlay.visible, "ClockRewindOverlay starts hidden")
	button.pressed.emit()
	_ok(overlay.visible, "RestartDayBtn opens ClockRewindOverlay")
	var event_list := overlay.get_node("EventPanel/EventList") as VBoxContainer
	_ok(event_list.get_child_count() == 1, "ClockRewindOverlay receives current day events")
	var cancel_btn := overlay.get_node("CancelBtn") as Button
	cancel_btn.pressed.emit()
	_ok(not overlay.visible, "ClockRewindOverlay can close after entry test")


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-LEDGER-RESTART] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-LEDGER-RESTART] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-LEDGER-RESTART] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
