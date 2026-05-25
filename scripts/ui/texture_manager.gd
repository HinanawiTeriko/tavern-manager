class_name TextureManager
extends RefCounted

static func try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func try_load_style_box(path: String) -> StyleBoxTexture:
	var tex: Texture2D = try_load(path)
	if tex == null:
		return null
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.region_rect = Rect2(0, 0, tex.get_width(), tex.get_height())
	return sb
