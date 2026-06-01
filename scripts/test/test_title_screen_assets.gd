extends Node

const TITLE_SCENE := preload("res://scenes/ui/TitleScreen.tscn")


func _ready() -> void:
	var title_screen := TITLE_SCENE.instantiate()
	add_child(title_screen)

	var failures: Array[String] = []
	_check_textured_node(title_screen, "Background", failures)
	_check_textured_node(title_screen, "GlowOverlay", failures)
	_check_textured_node(title_screen, "Logo", failures)
	_check_textured_node(title_screen, "UI/MenuBands", failures)
	_check_textured_node(title_screen, "UI/MenuMarker", failures)

	var start_button := title_screen.get_node("UI/StartButton") as Button
	var logo := title_screen.get_node("Logo") as Sprite2D
	var menu_bands := title_screen.get_node("UI/MenuBands") as TextureRect
	_check_title_font(title_screen.get_node("UI/StartButton"), failures)
	_check_title_font(title_screen.get_node("UI/ContinueButton"), failures)
	_check_title_font(title_screen.get_node("UI/RestartButton"), failures)
	_check_title_font(title_screen.get_node("UI/QuitButton"), failures)
	_check_title_font(title_screen.get_node("UI/VersionLabel"), failures)
	_check(start_button.position.x >= 900.0, "Title menu must be anchored in the right-side readability area", failures)
	var logo_right := logo.position.x + logo.texture.get_width() * 0.5
	_check(logo_right <= menu_bands.offset_left, "Title logo must not overlap the runtime menu area: logo_right=%s menu_left=%s" % [logo_right, menu_bands.offset_left], failures)
	_check(not title_screen.get_node("UI/TitlePanel").visible, "Legacy title panel must be hidden", failures)
	_check(not title_screen.get_node("UI/SubtitleLabel").visible, "Legacy subtitle must be hidden", failures)
	_check(not title_screen.get_node("UI/HintLabel").visible, "Legacy hint must be hidden", failures)

	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
		return
	print("TEST_TITLE_SCREEN_ASSETS_PASS")
	get_tree().quit()


func _check_textured_node(root: Node, path: String, failures: Array[String]) -> void:
	var node := root.get_node_or_null(path)
	if node == null:
		failures.append("Missing title-screen layer: %s" % path)
		return
	_check(node.texture != null, "Missing texture on title-screen layer: %s" % path, failures)


func _check_title_font(node: Control, failures: Array[String]) -> void:
	var font := node.get_theme_font("font")
	_check(font != null, "Missing title font on %s" % node.name, failures)
	if font != null:
		_check(font.resource_path == "res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf", "Wrong title font on %s: %s" % [node.name, font.resource_path], failures)


func _check(condition: bool, failure: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(failure)
