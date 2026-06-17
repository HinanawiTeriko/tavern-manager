extends Node

const OVERLAY_SCENE := "res://scenes/ui/ClockRewindOverlay.tscn"

var _checks := 0
var _failures := 0


func _ready() -> void:
	_ok(ResourceLoader.exists(OVERLAY_SCENE), "ClockRewindOverlay scene exists")
	if not ResourceLoader.exists(OVERLAY_SCENE):
		_finish()
		return

	var scene := load(OVERLAY_SCENE) as PackedScene
	var overlay = scene.instantiate()
	add_child(overlay)
	await get_tree().process_frame

	_ok(overlay.has_signal("rewind_completed"), "overlay exposes rewind_completed signal")
	_ok(overlay.has_signal("rewind_cancelled"), "overlay exposes rewind_cancelled signal")
	_ok(overlay.has_method("open_with_events"), "overlay exposes open_with_events")
	_ok(overlay.has_method("set_rewind_progress_for_test"), "overlay exposes set_rewind_progress_for_test")
	_ok(overlay.has_method("get_rewind_progress"), "overlay exposes get_rewind_progress")
	_ok(overlay.get_node_or_null("Shade") is ColorRect, "overlay has Shade node")
	_ok(overlay.get_node_or_null("ClockRoot/ClockFace") is TextureRect, "overlay has ClockFace node")
	_ok(overlay.get_node_or_null("ClockRoot/ClockHand") is TextureRect, "overlay has ClockHand node")
	_ok(overlay.get_node_or_null("EventPanel/EventList") is VBoxContainer, "overlay has EventList node")
	_ok(overlay.get_node_or_null("EventPanel/PromptLabel") is Label, "overlay has PromptLabel node")
	_ok(overlay.get_node_or_null("CancelBtn") is Button, "overlay has CancelBtn node")
	_test_runtime_art_paths(overlay)

	var signal_counts := {"completed": 0, "cancelled": 0}
	overlay.rewind_completed.connect(func(): signal_counts["completed"] = int(signal_counts["completed"]) + 1)
	overlay.rewind_cancelled.connect(func(): signal_counts["cancelled"] = int(signal_counts["cancelled"]) + 1)
	overlay.open_with_events([
		{"type": "purchase_material", "label": "麦芽", "detail": "x2 / -4G"},
		{"type": "location", "label": "菌菇林地", "detail": "获得 沉睡花粉 x1"},
		{"type": "settlement", "label": "今日结算", "detail": "+12G / +1 REP"},
	])
	_ok(overlay.visible, "open_with_events makes overlay visible")
	_ok(_event_label_count(overlay) == 3, "overlay renders event labels")

	overlay.set_rewind_progress_for_test(0.5)
	_ok(is_equal_approx(float(overlay.get_rewind_progress()), 0.5), "test hook sets rewind progress")
	_ok(_visible_event_label_count(overlay) == 2, "progress reveals events incrementally")

	overlay.set_rewind_progress_for_test(1.0)
	overlay.set_rewind_progress_for_test(1.0)
	_ok(int(signal_counts["completed"]) == 1, "full rewind emits completion once")
	_ok(not overlay.visible, "completed overlay hides itself")

	overlay.open_with_events([])
	var cancel_btn := overlay.get_node("CancelBtn") as Button
	cancel_btn.pressed.emit()
	_ok(int(signal_counts["cancelled"]) == 1, "cancel button emits rewind_cancelled")
	_ok(not overlay.visible, "cancelled overlay hides itself")

	overlay.queue_free()
	await get_tree().process_frame
	_finish()


func _event_label_count(overlay: Node) -> int:
	var list := overlay.get_node("EventPanel/EventList") as VBoxContainer
	return list.get_child_count()


func _visible_event_label_count(overlay: Node) -> int:
	var count := 0
	var list := overlay.get_node("EventPanel/EventList") as VBoxContainer
	for child in list.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			count += 1
	return count


func _test_runtime_art_paths(overlay: Node) -> void:
	var face := overlay.get_node("ClockRoot/ClockFace") as TextureRect
	var hand := overlay.get_node("ClockRoot/ClockHand") as TextureRect
	var panel := overlay.get_node("EventPanel/EventPanelArt") as TextureRect
	_ok(face.texture != null and String(face.texture.resource_path).ends_with("assets/textures/ui/restart_day/restart_day_clock_face.png"), "clock face uses runtime texture")
	_ok(hand.texture != null and String(hand.texture.resource_path).ends_with("assets/textures/ui/restart_day/restart_day_clock_hand.png"), "clock hand uses runtime texture")
	_ok(panel.texture != null and String(panel.texture.resource_path).ends_with("assets/textures/ui/restart_day/restart_day_event_panel.png"), "event panel uses runtime texture")
	var cancel_btn := overlay.get_node("CancelBtn") as Button
	for state in ["normal", "hover", "pressed"]:
		var style := cancel_btn.get_theme_stylebox(state) as StyleBoxTexture
		_ok(style != null and style.texture != null, "cancel button has %s texture style" % state)
		if style != null and style.texture != null:
			_ok(String(style.texture.resource_path).ends_with("assets/textures/ui/restart_day/restart_day_button_%s.png" % state), "cancel button uses restart day %s art" % state)


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-CLOCK-REWIND] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-CLOCK-REWIND] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-CLOCK-REWIND] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
