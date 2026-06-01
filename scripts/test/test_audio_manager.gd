extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var audio := AudioManager.new()
	for event_key in [
		"drop", "collision", "ingredient_drop", "barrel_shake", "grill_sizzle",
		"pot_stir", "product_ready", "serve_success", "serve_fail", "page_turn",
		"new_document",
	]:
		_ok(audio.has_event(event_key), "event exists: " + event_key)
		_ok(FileAccess.file_exists(audio.get_event_path(event_key)), "wav exists: " + event_key)
	_ok(not audio.play_event("missing_event"), "unknown event is ignored safely")
	audio.free()
	_test_hook_wiring()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-AUDIO] FAIL: " + msg)


func _test_hook_wiring() -> void:
	_expect_tokens("res://scripts/game_manager.gd", [
		"func play_audio_event", "\"serve_success\"", "\"serve_fail\"", "\"new_document\"",
	])
	_expect_tokens("res://scripts/test/desk_item.gd", ["\"collision\""])
	_expect_tokens("res://scripts/test/brewery.gd", [
		"\"ingredient_drop\"", "\"barrel_shake\"", "\"product_ready\"",
	])
	_expect_tokens("res://scripts/ui/kitchen_container.gd", [
		"\"ingredient_drop\"", "\"grill_sizzle\"", "\"pot_stir\"", "\"product_ready\"",
	])
	_expect_tokens("res://scripts/ui/bar_workspace.gd", ["\"drop\""])
	_expect_tokens("res://scripts/ui/document_overlay.gd", ["\"page_turn\""])


func _expect_tokens(path: String, tokens: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	_ok(file != null, "hook file exists: " + path)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	for token in tokens:
		_ok(text.contains(token), "%s contains %s hook" % [path, token])


func _finish() -> void:
	if _failures == 0:
		print("[TEST-AUDIO] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-AUDIO] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
