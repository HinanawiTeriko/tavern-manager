extends Node

const BALLOON_SCENE_PATH := "res://scenes/ui/DialogueBalloon.tscn"
const BALLOON_SCRIPT_PATH := "res://scripts/ui/dialogue_balloon.gd"
const PANEL_TEXTURE := "res://assets/textures/ui/dialogue_box/dialogue_panel.png"

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_project_dialogue_balloon_scene_contract()
	_test_game_manager_uses_project_balloon()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DIALOGUE-BALLOON] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DIALOGUE-BALLOON] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DIALOGUE-BALLOON] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_project_dialogue_balloon_scene_contract() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	_ok(ResourceLoader.exists(BALLOON_SCENE_PATH), "project dialogue balloon scene exists")
	if not ResourceLoader.exists(BALLOON_SCENE_PATH):
		return
	var scene := load(BALLOON_SCENE_PATH) as PackedScene
	_ok(scene != null, "project dialogue balloon scene loads")
	if scene == null:
		return
	var balloon := scene.instantiate()
	add_child(balloon)
	await get_tree().process_frame

	_ok(balloon is CanvasLayer, "dialogue balloon root remains CanvasLayer")
	_ok(balloon.get_script() != null and balloon.get_script().resource_path == BALLOON_SCRIPT_PATH, "dialogue balloon uses project styling script")
	_ok(balloon.has_method("start"), "dialogue balloon keeps Dialogue Manager start method")
	_ok(balloon.get("will_block_other_input") != null, "dialogue balloon keeps will_block_other_input property")

	var balloon_control := balloon.get_node_or_null("Balloon") as Control
	if balloon_control != null:
		balloon_control.show()
		await get_tree().process_frame
		await get_tree().process_frame
	var panel := balloon.get_node_or_null("Balloon/MarginContainer/PanelContainer") as PanelContainer
	var character_label := balloon.get_node_or_null("Balloon/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/CharacterLabel") as RichTextLabel
	var dialogue_label := balloon.get_node_or_null("Balloon/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/DialogueLabel") as RichTextLabel
	var responses_menu := balloon.get_node_or_null("Balloon/ResponsesMenu") as VBoxContainer
	var response_example := balloon.get_node_or_null("Balloon/ResponsesMenu/ResponseExample") as Button
	var progress := balloon.get_node_or_null("Balloon/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/Control/Progress") as Polygon2D
	var progress_art := balloon.get_node_or_null("Balloon/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/Control/ProgressArt") as TextureRect

	_ok(balloon_control != null, "keeps Balloon node")
	_ok(panel != null, "keeps PanelContainer node")
	_ok(character_label != null, "keeps CharacterLabel node")
	_ok(dialogue_label != null, "keeps DialogueLabel node")
	_ok(responses_menu != null, "keeps ResponsesMenu node")
	_ok(response_example != null, "keeps ResponseExample button")
	_ok(progress != null, "keeps legacy Progress polygon node")
	_ok(progress_art != null, "keeps ProgressArt compatibility node")

	if panel != null:
		var panel_style := panel.get_theme_stylebox("panel") as StyleBoxTexture
		_ok(_style_texture_path(panel_style) == PANEL_TEXTURE, "panel uses dialogue panel runtime art")
		if panel_style != null and panel_style.texture != null:
			var texture_size := Vector2(panel_style.texture.get_width(), panel_style.texture.get_height())
			_ok(_size_matches(panel.size, texture_size), "dialogue panel renders at exact runtime texture size without container compression")
	if character_label != null:
		_ok(_style_texture_path(character_label.get_theme_stylebox("normal")) == "", "character label renders speaker text without nameplate art")
		_ok(character_label.get_theme_font("normal_font").resource_path == ThemeColors.MENU_FONT_PATH, "character label uses pixel font")
	if dialogue_label != null:
		_ok(dialogue_label.get_theme_font("normal_font").resource_path == ThemeColors.MENU_FONT_PATH, "dialogue label uses pixel font")
	if response_example != null:
		_ok(_style_texture_path(response_example.get_theme_stylebox("normal")) == "", "response template keeps plugin fallback art, not project dialogue-box art")
	if progress != null:
		_ok(not progress.visible, "legacy polygon progress indicator is hidden")
	if progress_art != null:
		_ok(progress_art.texture == null, "ProgressArt keeps compatibility node without arrow art")
		_ok(not progress_art.visible, "ProgressArt remains hidden after arrow art removal")

	balloon.queue_free()


func _test_game_manager_uses_project_balloon() -> void:
	var file := FileAccess.open("res://scripts/game_manager.gd", FileAccess.READ)
	_ok(file != null, "GameManager script is readable")
	if file == null:
		return
	var text := file.get_as_text()
	_ok("res://scenes/ui/DialogueBalloon.tscn" in text, "GameManager references project dialogue balloon scene")
	_ok("show_dialogue_balloon_scene" in text, "GameManager uses custom Dialogue Manager balloon scene API")
	_ok(not "show_example_dialogue_balloon(dialogue_resource" in text, "GameManager no longer uses plugin example balloon directly")


func _style_texture_path(style: StyleBox) -> String:
	var texture_style := style as StyleBoxTexture
	if texture_style == null or texture_style.texture == null:
		return ""
	return String(texture_style.texture.resource_path)


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return String(texture.resource_path)


func _size_matches(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
