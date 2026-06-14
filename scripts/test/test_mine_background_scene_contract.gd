extends Node

const MINE_SCENE := preload("res://scenes/ui/MineInvestigation.tscn")
const BACKGROUND_PATH := "res://assets/ui/generated/investigation/mine_background/mine_background.png"
const PIXEL_FONT_PATH := "res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"
const LEAVE_BUTTON_NORMAL := "res://assets/ui/generated/investigation/mine_ui/mine_leave_button_normal.png"
const LEAVE_BUTTON_HOVER := "res://assets/ui/generated/investigation/mine_ui/mine_leave_button_hover.png"
const LEAVE_BUTTON_PRESSED := "res://assets/ui/generated/investigation/mine_ui/mine_leave_button_pressed.png"
const LEAVE_BUTTON_SIZE := Vector2(280, 100)

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_scene_background_contract()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MINE-BACKGROUND] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-MINE-BACKGROUND] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MINE-BACKGROUND] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_scene_background_contract() -> void:
	var scene := MINE_SCENE.instantiate()
	add_child(scene)
	await get_tree().process_frame
	var background := scene.get_node_or_null("Background")
	var background_art := scene.get_node_or_null("BackgroundArt")
	var blood_trail := scene.get_node_or_null("BloodTrail")
	var observation_label := scene.get_node_or_null("UI/ObservationLabel") as Label
	var hint_label := scene.get_node_or_null("UI/HintLabel") as Label
	var leave_button := scene.get_node_or_null("UI/LeaveButton") as Button
	_ok(background is ColorRect, "legacy Background node remains a ColorRect fallback")
	_ok(background_art is Sprite2D, "BackgroundArt Sprite2D exists")
	_ok(blood_trail is ColorRect, "legacy BloodTrail node remains present")
	if background != null and background_art != null:
		_ok(background.z_index < background_art.z_index, "Background fallback renders below BackgroundArt")
	if background_art != null:
		var sprite := background_art as Sprite2D
		_ok(sprite.position == Vector2(640, 360), "BackgroundArt is centered on the 1280x720 scene")
		_ok(sprite.texture != null, "BackgroundArt has a texture")
		if sprite.texture != null:
			_ok(sprite.texture.resource_path == BACKGROUND_PATH, "BackgroundArt uses the runtime background texture")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "BackgroundArt uses nearest texture filtering")
	if blood_trail != null:
		_ok(not blood_trail.visible, "legacy BloodTrail is hidden rather than deleted")
	_ok(scene.get_node_or_null("World") is Node2D, "World node path is preserved")
	_ok(scene.get_node_or_null("World/Ground") is StaticBody2D, "World/Ground path is preserved")
	_ok(scene.get_node_or_null("DragCtrl") is Node, "DragCtrl path is preserved")
	_ok(scene.get_node_or_null("UI/ObservationLabel") is Label, "ObservationLabel path is preserved")
	_ok(scene.get_node_or_null("UI/HintLabel") is Label, "HintLabel path is preserved")
	_ok(scene.get_node_or_null("UI/LeaveButton") is Button, "LeaveButton path is preserved")
	_assert_pixel_font(observation_label, "ObservationLabel")
	_assert_pixel_font(hint_label, "HintLabel")
	_assert_pixel_font(leave_button, "LeaveButton")
	if observation_label != null:
		_ok(observation_label.get_theme_font_size("font_size") == 20, "ObservationLabel uses compact pixel font size")
	if hint_label != null:
		_ok(hint_label.get_theme_font_size("font_size") == 16, "HintLabel uses compact pixel font size")
	if leave_button != null:
		_ok(leave_button.size == LEAVE_BUTTON_SIZE, "LeaveButton uses authored 280x100 mine button bounds")
		_assert_stylebox_texture(leave_button, "normal", LEAVE_BUTTON_NORMAL)
		_assert_stylebox_texture(leave_button, "hover", LEAVE_BUTTON_HOVER)
		_assert_stylebox_texture(leave_button, "pressed", LEAVE_BUTTON_PRESSED)
	scene.queue_free()


func _assert_pixel_font(control: Control, label_name: String) -> void:
	_ok(control != null, label_name + " exists for font check")
	if control == null:
		return
	var font := control.get_theme_font("font")
	_ok(font != null and font.resource_path == PIXEL_FONT_PATH, label_name + " uses fusion-pixel font")


func _assert_stylebox_texture(button: Button, style_name: String, expected_path: String) -> void:
	var stylebox := button.get_theme_stylebox(style_name) as StyleBoxTexture
	_ok(stylebox != null, "LeaveButton " + style_name + " style is a StyleBoxTexture")
	if stylebox == null:
		return
	_ok(stylebox.texture != null, "LeaveButton " + style_name + " style has a texture")
	if stylebox.texture != null:
		_ok(stylebox.texture.resource_path == expected_path, "LeaveButton " + style_name + " style uses authored texture")
