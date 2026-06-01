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
	_check_no_bright_alpha_fringe(menu_bands.texture, failures)
	_check_neutral_alpha_fringe(logo.texture, "Title logo", 64, failures)
	_check_neutral_alpha_fringe(_menu_marker_texture(title_screen), "Title menu marker", 0, failures)
	_check_no_terminal_alpha_pixels(logo.texture, "Title logo", failures)
	_check_no_terminal_alpha_pixels(menu_bands.texture, "Title menu bands", failures)
	_check_menu_button_band_alignment(title_screen, menu_bands.texture, failures)
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


func _check_no_bright_alpha_fringe(texture: Texture2D, failures: Array[String]) -> void:
	var image := texture.get_image()
	var bright_edge_pixels := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if not _touches_transparency(image, x, y):
				continue
			if max(color.r, max(color.g, color.b)) >= 0.35:
				bright_edge_pixels += 1
	_check(bright_edge_pixels == 0, "Title menu bands must not contain bright opaque fringe pixels: %s found" % bright_edge_pixels, failures)


func _menu_marker_texture(title_screen: Node) -> Texture2D:
	return title_screen.get_node("UI/MenuMarker").texture


func _check_neutral_alpha_fringe(texture: Texture2D, label: String, max_allowed: int, failures: Array[String]) -> void:
	var image := texture.get_image()
	var neutral_edge_pixels := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if not _touches_transparency(image, x, y):
				continue
			var brightest: float = maxf(color.r, maxf(color.g, color.b))
			var darkest: float = minf(color.r, minf(color.g, color.b))
			if darkest >= 0.66 and brightest - darkest <= 0.14:
				neutral_edge_pixels += 1
	_check(neutral_edge_pixels <= max_allowed, "%s must not contain neutral pale fringe pixels: %s found, maximum %s" % [label, neutral_edge_pixels, max_allowed], failures)


func _check_no_terminal_alpha_pixels(texture: Texture2D, label: String, failures: Array[String]) -> void:
	var image := texture.get_image()
	var terminal_pixels := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			var support := 0
			for neighbor_y in range(maxi(0, y - 1), mini(image.get_height(), y + 2)):
				for neighbor_x in range(maxi(0, x - 1), mini(image.get_width(), x + 2)):
					if neighbor_x == x and neighbor_y == y:
						continue
					if image.get_pixel(neighbor_x, neighbor_y).a > 0.0:
						support += 1
			if support <= 1:
				terminal_pixels += 1
	_check(terminal_pixels == 0, "%s must not contain terminal alpha pixels: %s found" % [label, terminal_pixels], failures)


func _check_menu_button_band_alignment(title_screen: Node, texture: Texture2D, failures: Array[String]) -> void:
	var image := texture.get_image()
	var band_tops: Array[int] = []
	var previous_row_visible := false
	for y in image.get_height():
		var row_visible := false
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				row_visible = true
				break
		if row_visible and not previous_row_visible:
			band_tops.append(y)
		previous_row_visible = row_visible
	var button_paths := ["UI/StartButton", "UI/ContinueButton", "UI/RestartButton", "UI/QuitButton"]
	_check(band_tops.size() == button_paths.size(), "Title menu bands and buttons must have the same count", failures)
	if band_tops.size() != button_paths.size():
		return
	var menu_bands := title_screen.get_node("UI/MenuBands") as TextureRect
	for index in button_paths.size():
		var button := title_screen.get_node(button_paths[index]) as Button
		var band_top: float = menu_bands.position.y + band_tops[index]
		_check(is_equal_approx(button.position.y - band_top, 3.0), "%s must sit 3 px below its menu band top: got %s" % [button.name, button.position.y - band_top], failures)


func _touches_transparency(image: Image, x: int, y: int) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := Vector2i(x, y) + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= image.get_width() or neighbor.y >= image.get_height():
			return true
		if image.get_pixelv(neighbor).a <= 0.0:
			return true
	return false


func _check(condition: bool, failure: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(failure)
