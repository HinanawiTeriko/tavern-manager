extends Node

const MINE_SCENE := preload("res://scenes/ui/MineInvestigation.tscn")
const BACKGROUND_PATH := "res://assets/ui/generated/investigation/mine_background/mine_background.png"

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_scene_background_contract()
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
	var background := scene.get_node_or_null("Background")
	var background_art := scene.get_node_or_null("BackgroundArt")
	var blood_trail := scene.get_node_or_null("BloodTrail")
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
	scene.free()
