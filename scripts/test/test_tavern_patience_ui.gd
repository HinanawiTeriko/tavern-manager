extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_tavern_patience_ui_contract()
	_test_important_guest_patience_ratio_uses_important_guest_max()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TAVERN-PATIENCE-UI] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TAVERN-PATIENCE-UI] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TAVERN-PATIENCE-UI] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return String(texture.resource_path)


func _stylebox_texture_path(control: Control, style_name: String) -> String:
	var stylebox := control.get_theme_stylebox(style_name) as StyleBoxTexture
	if stylebox == null:
		return ""
	return _texture_path(stylebox.texture)


func _test_tavern_patience_ui_contract() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	var timer := tavern.get_node_or_null("CustomerArea/TimerBar") as ProgressBar
	_ok(timer != null, "TimerBar remains the public Tavern patience ProgressBar path")
	if timer != null:
		_ok(timer.size == Vector2(300, 28), "TimerBar uses the production 300x28 patience bar layout")
		_ok(_stylebox_texture_path(timer, "background") == "res://assets/textures/ui/bar_patience_bg.png",
			"TimerBar uses patience background art")
		_ok(_stylebox_texture_path(timer, "fill") == "res://assets/textures/ui/bar_patience_fill.png",
			"TimerBar uses patience fill art")
		tavern.update_timer(0.42)
		_ok(is_equal_approx(timer.value, 42.0), "TavernView.update_timer still drives TimerBar value")

	var icon := tavern.get_node_or_null("CustomerArea/PatienceIcon") as TextureRect
	_ok(icon != null, "Tavern adds a PatienceIcon beside TimerBar")
	if icon != null:
		_ok(icon.size == Vector2(32, 32), "PatienceIcon uses the 32x32 runtime icon size")
		_ok(_texture_path(icon.texture) == "res://assets/textures/ui/icon_patience.png",
			"PatienceIcon uses the runtime patience icon")
		_ok(icon.texture != null and icon.texture.get_size() == Vector2(32, 32),
			"PatienceIcon loaded texture is the current 32x32 runtime export")
		_ok(icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "PatienceIcon uses nearest texture filtering")

	var ledger := tavern.get_node_or_null("BarWorkspace/World/Ledger") as ReadableDeskItem
	_ok(ledger != null, "Ledger compatibility node remains at BarWorkspace/World/Ledger")
	if ledger != null:
		_ok(not ledger.visible, "Tavern work-surface ledger entrance is hidden")
		_ok(not ledger.input_pickable, "Tavern work-surface ledger entrance no longer receives click input")
		_ok(ledger.document_id == "ledger", "hidden ledger compatibility node still targets the ledger document")

	tavern.queue_free()
	await get_tree().process_frame


func _test_important_guest_patience_ratio_uses_important_guest_max() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("_guest_patience_ratio"), "GameManager exposes a testable guest patience ratio helper")
	if not gm.has_method("_guest_patience_ratio"):
		return
	var important := GuestData.new()
	important.type = GuestData.GuestType.IMPORTANT
	important.patience = GuestData.BASE_PATIENCE * 1.5 - 1.0
	var important_ratio: float = gm._guest_patience_ratio(important)
	_ok(important_ratio < 1.0, "important guest patience bar starts moving before dropping below base patience")
	_ok(important_ratio > 0.95, "important guest patience ratio still starts near full")

	var normal := GuestData.new()
	normal.type = GuestData.GuestType.NORMAL
	normal.patience = GuestData.BASE_PATIENCE * 0.5
	_ok(is_equal_approx(gm._guest_patience_ratio(normal), 0.5), "normal guest patience ratio still uses base patience")
