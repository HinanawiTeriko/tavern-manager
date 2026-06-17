class_name TextureManager
extends RefCounted

static var _cache: Dictionary = {}

static func try_load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[path] = tex
		return tex
	var image := Image.new()
	var err := image.load(path)
	if err == OK:
		var tex := ImageTexture.create_from_image(image)
		tex.take_over_path(path)
		_cache[path] = tex
		return tex
	return null

static func try_load_style_box(path: String) -> StyleBoxTexture:
	var tex: Texture2D = try_load(path)
	if tex == null:
		return null
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.region_rect = Rect2(0, 0, tex.get_width(), tex.get_height())
	return sb

static func clear_cache() -> void:
	_cache.clear()
