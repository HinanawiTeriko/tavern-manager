extends Node

const TITLE_SCENE := preload("res://scenes/ui/TitleScreen.tscn")
const SOURCE_DIR := "res://assets/source/title/"
const FULL_LAYER_SOURCES := {
	"Background": "title_pixel_bg_clean_native.png",
	"GlowOverlay": "title_pixel_glow_mask_native.png",
	"Logo": "title_pixel_logo_native.png",
	"UI/MenuBands": "title_pixel_menu_bands_native.png",
}
const RUNTIME_SCALE := 4
const MARKER_RUNTIME_SCALE := 2
const FULL_CANVAS_SIZE := Vector2(1280.0, 720.0)
const LOGO_REST_Y := 360.0
const NATIVE_PIXEL_SCALE := 4.0
const MENU_BUTTON_RECTS := {
	"UI/StartButton": Rect2(958.0, 165.0, 280.0, 50.0),
	"UI/ContinueButton": Rect2(958.0, 267.0, 280.0, 50.0),
	"UI/SettingsButton": Rect2(958.0, 369.0, 280.0, 50.0),
	"UI/QuitButton": Rect2(958.0, 473.0, 280.0, 50.0),
}


func _ready() -> void:
	var title_screen := TITLE_SCENE.instantiate()
	add_child(title_screen)

	var failures: Array[String] = []
	_check_textured_node(title_screen, "Background", failures)
	_check_textured_node(title_screen, "GlowOverlay", failures)
	_check_textured_node(title_screen, "Logo", failures)
	_check_textured_node(title_screen, "UI/MenuBands", failures)
	_check_textured_node(title_screen, "UI/MenuMarker", failures)
	for node_path in FULL_LAYER_SOURCES:
		var textured_node := title_screen.get_node_or_null(node_path)
		if textured_node != null:
			_check_native_runtime_dimensions(
				SOURCE_DIR + FULL_LAYER_SOURCES[node_path],
				textured_node.texture,
				node_path,
				failures,
			)
	var menu_marker := title_screen.get_node_or_null("UI/MenuMarker") as TextureRect
	if menu_marker != null:
		_check_native_runtime_dimensions(
			SOURCE_DIR + "title_pixel_menu_marker_native.png",
			menu_marker.texture,
			"UI/MenuMarker",
			failures,
			MARKER_RUNTIME_SCALE,
		)

	var start_button := title_screen.get_node("UI/StartButton") as Button
	var logo := title_screen.get_node("Logo") as Sprite2D
	var menu_bands := title_screen.get_node("UI/MenuBands") as TextureRect
	_check_title_font(title_screen.get_node("UI/StartButton"), failures)
	_check_title_font(title_screen.get_node("UI/ContinueButton"), failures)
	_check_title_font(title_screen.get_node("UI/SettingsButton"), failures)
	_check_title_font(title_screen.get_node("UI/QuitButton"), failures)
	_check_title_font(title_screen.get_node("UI/VersionLabel"), failures)
	var settings_button := title_screen.get_node("UI/SettingsButton") as Button
	_check(settings_button.text == "设置", "Title settings button must read 设置: got %s" % settings_button.text, failures)
	_check(start_button.position.x >= 900.0, "Title menu must be anchored in the right-side readability area", failures)
	_check(logo.position == Vector2(640.0, 360.0), "Title logo must be centered on the full canvas: got %s" % logo.position, failures)
	_check(menu_bands.position == Vector2.ZERO, "Title menu bands must start at the full-canvas origin: got %s" % menu_bands.position, failures)
	_check(menu_bands.size == FULL_CANVAS_SIZE, "Title menu bands must cover the full canvas: got %s" % menu_bands.size, failures)
	if menu_bands.texture != null:
		_check(menu_bands.size == Vector2(menu_bands.texture.get_size()), "Title menu bands must render at authored runtime size without scaling: rect=%s texture=%s" % [menu_bands.size, menu_bands.texture.get_size()], failures)
	var logo_texture_origin := logo.position
	if logo.texture != null:
		logo_texture_origin -= Vector2(logo.texture.get_size()) * 0.5
	var logo_visible_bounds := _visible_bounds_screen_space(logo.texture, logo_texture_origin, "Title logo", failures)
	var menu_visible_bounds := _visible_bounds_screen_space(menu_bands.texture, menu_bands.position, "Title menu bands", failures)
	_check(logo_visible_bounds.end.x <= menu_visible_bounds.position.x, "Title logo must not overlap visible menu art: logo_right=%s menu_left=%s" % [logo_visible_bounds.end.x, menu_visible_bounds.position.x], failures)
	_check_menu_button_layout(title_screen, failures)
	_check_no_bright_alpha_fringe(menu_bands.texture, "Title menu bands", failures)
	_check_neutral_alpha_fringe(logo.texture, "Title logo", 64, failures)
	_check_neutral_alpha_fringe(_menu_marker_texture(title_screen), "Title menu marker", 0, failures)
	_check_no_terminal_alpha_pixels(logo.texture, "Title logo", failures)
	_check_no_terminal_alpha_pixels(menu_bands.texture, "Title menu bands", failures)
	_check_menu_button_band_alignment(title_screen, menu_bands.texture, failures)
	title_screen._process(1.0)
	_check(is_zero_approx(fposmod(logo.position.y - LOGO_REST_Y, NATIVE_PIXEL_SCALE)), "Title logo ambient motion must remain on the authored 4 px grid: got y=%s" % logo.position.y, failures)
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


func _check_native_runtime_dimensions(
	native_path: String,
	texture: Texture2D,
	label: String,
	failures: Array[String],
	scale: int = RUNTIME_SCALE
) -> void:
	var native := Image.new()
	var load_error := native.load(ProjectSettings.globalize_path(native_path))
	_check(load_error == OK and not native.is_empty(), "%s native source must load: %s" % [label, native_path], failures)
	if load_error != OK or native.is_empty():
		return
	var runtime := _texture_image(texture, label, failures)
	if runtime == null:
		return
	_check(runtime.get_width() == native.get_width() * scale, "%s runtime width must be native width * %s" % [label, scale], failures)
	_check(runtime.get_height() == native.get_height() * scale, "%s runtime height must be native height * %s" % [label, scale], failures)


func _check_menu_button_layout(title_screen: Node, failures: Array[String]) -> void:
	for node_path in MENU_BUTTON_RECTS:
		var button := title_screen.get_node_or_null(node_path) as Button
		_check(button != null, "Missing title menu button: %s" % node_path, failures)
		if button == null:
			continue
		var expected: Rect2 = MENU_BUTTON_RECTS[node_path]
		_check(button.position == expected.position, "%s must use authored position %s: got %s" % [button.name, expected.position, button.position], failures)
		_check(button.size == expected.size, "%s must use authored size %s: got %s" % [button.name, expected.size, button.size], failures)


func _visible_bounds_screen_space(texture: Texture2D, screen_origin: Vector2, label: String, failures: Array[String]) -> Rect2:
	var visible_bounds := _visible_bounds(texture, label, failures)
	return Rect2(screen_origin + Vector2(visible_bounds.position), Vector2(visible_bounds.size))


func _visible_bounds(texture: Texture2D, label: String, failures: Array[String]) -> Rect2i:
	var image := _texture_image(texture, label, failures)
	if image == null:
		return Rect2i()
	var first := Vector2i(image.get_width(), image.get_height())
	var last := Vector2i.ZERO
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			first.x = mini(first.x, x)
			first.y = mini(first.y, y)
			last.x = maxi(last.x, x + 1)
			last.y = maxi(last.y, y + 1)
	_check(last != Vector2i.ZERO, "%s runtime image must contain visible alpha" % label, failures)
	if last == Vector2i.ZERO:
		return Rect2i()
	return Rect2i(first, last - first)


func _texture_image(texture: Texture2D, label: String, failures: Array[String]) -> Image:
	_check(texture != null, "%s runtime texture must load" % label, failures)
	if texture == null:
		return null
	var image := texture.get_image()
	_check(image != null and not image.is_empty(), "%s runtime image must load" % label, failures)
	if image == null or image.is_empty():
		return null
	return image


func _check_no_bright_alpha_fringe(texture: Texture2D, label: String, failures: Array[String]) -> void:
	var image := _texture_image(texture, label, failures)
	if image == null:
		return
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
	var image := _texture_image(texture, label, failures)
	if image == null:
		return
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
	var image := _texture_image(texture, label, failures)
	if image == null:
		return
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
	var image := _texture_image(texture, "Title menu bands", failures)
	if image == null:
		return
	var bands := _segment_band_bounds(image)
	var button_paths := ["UI/StartButton", "UI/ContinueButton", "UI/SettingsButton", "UI/QuitButton"]
	_check(bands.size() == button_paths.size(), "Title menu bands and buttons must have the same count: got %s" % bands.size(), failures)
	if bands.size() != button_paths.size():
		return
	var menu_bands := title_screen.get_node("UI/MenuBands") as TextureRect
	for index in button_paths.size():
		var button := title_screen.get_node(button_paths[index]) as Button
		var band_center: Vector2 = menu_bands.position + bands[index].get_center()
		var button_center: Vector2 = button.position + button.size * 0.5
		_check(absf(button_center.x - band_center.x) <= 6.0, "%s text must be horizontally centered on its menu band: button_cx=%s band_cx=%s" % [button.name, button_center.x, band_center.x], failures)
		_check(absf(button_center.y - band_center.y) <= 6.0, "%s text must be vertically centered on its menu band: button_cy=%s band_cy=%s" % [button.name, button_center.y, band_center.y], failures)


func _segment_band_bounds(image: Image) -> Array[Rect2]:
	var bands: Array[Rect2] = []
	var width := image.get_width()
	var height := image.get_height()
	var y := 0
	while y < height:
		if not _row_has_opaque(image, y):
			y += 1
			continue
		var top := y
		while y < height and _row_has_opaque(image, y):
			y += 1
		var bottom := y - 1
		var left := width
		var right := 0
		for row in range(top, bottom + 1):
			for x in width:
				if image.get_pixel(x, row).a > 0.0:
					left = mini(left, x)
					right = maxi(right, x)
		bands.append(Rect2(left, top, right - left + 1, bottom - top + 1))
	return bands


func _row_has_opaque(image: Image, y: int) -> bool:
	for x in image.get_width():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false


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
