extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_dialogue_mode_highlights_current_customer()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TAVERN-DIALOGUE-HIGHLIGHT] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TAVERN-DIALOGUE-HIGHLIGHT] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TAVERN-DIALOGUE-HIGHLIGHT] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_dialogue_mode_highlights_current_customer() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	var overlay := tavern.get_node_or_null("DialogueOverlay") as ColorRect
	var customer_sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	_ok(overlay != null, "Tavern keeps DialogueOverlay for dialogue dimming")
	_ok(customer_sprite != null, "Tavern keeps CustomerSprite for speaker highlight")
	if overlay == null or customer_sprite == null:
		tavern.queue_free()
		return

	tavern.show_customer("莱恩", "麦芽酒", "ryan")
	var normal_z := customer_sprite.z_index
	var normal_modulate := customer_sprite.modulate
	_ok(normal_z < overlay.z_index, "normal customer portrait remains behind the dialogue overlay layer")

	tavern.set_dialogue_mode(true)
	_ok(overlay.visible, "dialogue mode shows the dimming overlay")
	_ok(customer_sprite.z_index > overlay.z_index, "dialogue mode lifts the current speaker above the dimming overlay")
	_ok(customer_sprite.modulate.r > normal_modulate.r, "dialogue mode brightens the current speaker portrait")
	_ok(customer_sprite.modulate.g >= normal_modulate.g, "dialogue mode keeps the speaker readable instead of tinting it dark")

	tavern.set_dialogue_mode(false)
	_ok(not overlay.visible, "leaving dialogue mode hides the dimming overlay")
	_ok(customer_sprite.z_index == normal_z, "leaving dialogue mode restores the customer portrait layer")
	_ok(customer_sprite.modulate == normal_modulate, "leaving dialogue mode restores the customer portrait color")

	tavern.set_dialogue_mode(true)
	tavern.hide_customer()
	_ok(customer_sprite.z_index == normal_z, "hiding a customer clears dialogue highlight layering")
	_ok(customer_sprite.modulate == normal_modulate, "hiding a customer clears dialogue highlight color")

	tavern.queue_free()
