extends Node

const TOBY_SCENE := preload("res://scenes/ui/TobyLodgingInvestigation.tscn")
const BACKGROUND_PATH := "res://assets/ui/generated/investigation/toby_lodging/background.png"
const PIXEL_FONT_PATH := "res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"
const LEAVE_BUTTON_NORMAL := "res://assets/ui/generated/investigation/toby_lodging/ui/leave_button_normal.png"
const LEAVE_BUTTON_HOVER := "res://assets/ui/generated/investigation/toby_lodging/ui/leave_button_hover.png"
const LEAVE_BUTTON_PRESSED := "res://assets/ui/generated/investigation/toby_lodging/ui/leave_button_pressed.png"
const LEAVE_BUTTON_SIZE := Vector2(280, 100)
const EXPECTED_RUNTIME_SIZES := {
	"oil_lamp": Vector2(72, 96),
	"hard_bread": Vector2(80, 48),
	"oversized_coat": Vector2(176, 112),
	"contract_fragment_a": Vector2(68, 52),
	"contract_fragment_b": Vector2(64, 56),
	"contract_fragment_c": Vector2(76, 48),
}
const EXPECTED_TEXTURES := {
	"oil_lamp": "res://assets/ui/generated/investigation/toby_lodging/items/oil_lamp.png",
	"hard_bread": "res://assets/ui/generated/investigation/toby_lodging/items/hard_bread.png",
	"oversized_coat": "res://assets/ui/generated/investigation/toby_lodging/items/oversized_coat.png",
	"contract_fragment_a": "res://assets/ui/generated/investigation/toby_lodging/items/contract_fragment_a.png",
	"contract_fragment_b": "res://assets/ui/generated/investigation/toby_lodging/items/contract_fragment_b.png",
	"contract_fragment_c": "res://assets/ui/generated/investigation/toby_lodging/items/contract_fragment_c.png",
}
const EXPECTED_COLLISION_PROFILES := {
	"oil_lamp": {"size": Vector2(44, 70), "offset": Vector2(0, 8)},
	"hard_bread": {"size": Vector2(60, 30), "offset": Vector2(0, 4)},
	"oversized_coat": {"size": Vector2(140, 76), "offset": Vector2(0, 10)},
	"contract_fragment_a": {"size": Vector2(48, 34), "offset": Vector2(0, 2)},
	"contract_fragment_b": {"size": Vector2(46, 36), "offset": Vector2(0, 2)},
	"contract_fragment_c": {"size": Vector2(52, 32), "offset": Vector2(0, 2)},
}

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_toby_lodging_scene_art_contract()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TOBY-ART] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TOBY-ART] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TOBY-ART] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_toby_lodging_scene_art_contract() -> void:
	var scene := TOBY_SCENE.instantiate()
	add_child(scene)
	await get_tree().process_frame
	var background := scene.get_node_or_null("Background")
	var background_art := scene.get_node_or_null("BackgroundArt")
	var observation_label := scene.get_node_or_null("UI/ObservationLabel") as Label
	var hint_label := scene.get_node_or_null("UI/HintLabel") as Label
	var leave_button := scene.get_node_or_null("UI/LeaveButton") as Button
	_ok(background is ColorRect, "legacy Background node remains a ColorRect fallback")
	_ok(background_art is Sprite2D, "BackgroundArt Sprite2D exists")
	if background != null and background_art != null:
		_ok(background.z_index < background_art.z_index, "Background fallback renders below BackgroundArt")
	if background_art != null:
		var sprite := background_art as Sprite2D
		_ok(sprite.position == Vector2(640, 360), "BackgroundArt is centered on the 1280x720 scene")
		_ok(sprite.texture != null, "BackgroundArt has a texture")
		if sprite.texture != null:
			_ok(sprite.texture.resource_path == BACKGROUND_PATH, "BackgroundArt uses the runtime lodging texture")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "BackgroundArt uses nearest texture filtering")
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
		_ok(leave_button.size == LEAVE_BUTTON_SIZE, "LeaveButton uses authored 280x100 button bounds")
		_assert_stylebox_texture(leave_button, "normal", LEAVE_BUTTON_NORMAL)
		_assert_stylebox_texture(leave_button, "hover", LEAVE_BUTTON_HOVER)
		_assert_stylebox_texture(leave_button, "pressed", LEAVE_BUTTON_PRESSED)
	_assert_toby_items(scene)
	scene.queue_free()


func _assert_toby_items(scene: Node) -> void:
	var world := scene.get_node_or_null("World")
	_ok(world != null, "World exists for item art check")
	if world == null:
		return
	var counts := {}
	for child in world.get_children():
		if child is MineItem:
			var item := child as MineItem
			counts[item.item_tag] = int(counts.get(item.item_tag, 0)) + 1
			if EXPECTED_RUNTIME_SIZES.has(item.item_tag):
				_assert_item_art(item)
	_ok(int(counts.get("oil_lamp", 0)) == 1, "one oil lamp spawned")
	_ok(int(counts.get("hard_bread", 0)) == 1, "one hard bread spawned")
	_ok(int(counts.get("oversized_coat", 0)) == 1, "one oversized coat spawned")
	_ok(int(counts.get("contract_fragment", 0)) == 0, "generic contract_fragment is no longer spawned")
	_ok(int(counts.get("contract_fragment_a", 0)) == 1, "contract fragment A spawned once")
	_ok(int(counts.get("contract_fragment_b", 0)) == 1, "contract fragment B spawned once")
	_ok(int(counts.get("contract_fragment_c", 0)) == 1, "contract fragment C spawned once")


func _assert_item_art(item: MineItem) -> void:
	var sprite := item.get_node_or_null("TextureVisual") as Sprite2D
	_ok(sprite != null, item.item_tag + " creates TextureVisual")
	if sprite != null:
		_ok(sprite.texture != null, item.item_tag + " texture is loaded")
		_ok(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, item.item_tag + " uses nearest filtering")
		_ok(sprite.scale == Vector2.ONE, item.item_tag + " uses 1:1 runtime scale")
		if sprite.texture != null:
			_ok(sprite.texture.get_size() == EXPECTED_RUNTIME_SIZES[item.item_tag], item.item_tag + " runtime size matches authored art")
			_ok(sprite.texture.resource_path == EXPECTED_TEXTURES[item.item_tag], item.item_tag + " uses lodging runtime texture")
	_ok(item.kind == "fragment" or not item.item_tag.begins_with("contract_fragment_"), item.item_tag + " keeps fragment kind for assembly")
	_ok(not item.get_node("Visual").visible, item.item_tag + " hides debug polygon visual")
	_ok(not item.get_node("Label").visible, item.item_tag + " hides debug label")
	_assert_rect_collision(item)


func _assert_rect_collision(item: MineItem) -> void:
	var shape := item.get_node_or_null("Shape") as CollisionShape2D
	_ok(shape != null, item.item_tag + " keeps Shape collision node")
	if shape == null:
		return
	var rect := shape.shape as RectangleShape2D
	_ok(rect != null, item.item_tag + " uses rectangle collision")
	var profile: Dictionary = EXPECTED_COLLISION_PROFILES[item.item_tag]
	if rect != null:
		_ok(rect.size == profile["size"], item.item_tag + " collision size matches authored profile")
	_ok(shape.position == profile["offset"], item.item_tag + " collision offset matches authored profile")


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
