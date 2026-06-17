class_name GatheringToast
extends Panel

## Top reward toast for DayMap gathering. Text is rendered by Godot; the panel art is a texture.

const TOAST_WIDTH := 420.0
const TOAST_HEIGHT := 56.0
const DISPLAY_DURATION := 3.0
const FADE_DURATION := 0.4
const PANEL_TEXTURE := "res://assets/textures/daymap/ui/gathering_toast_panel.png"
const TOAST_FONT := preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")

var _label: Label
var _timer: Timer
var _current_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(TOAST_WIDTH, TOAST_HEIGHT)
	size = Vector2(TOAST_WIDTH, TOAST_HEIGHT)
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _toast_style())

	_label = Label.new()
	_label.name = "Content"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", TOAST_FONT)
	_label.add_theme_color_override("font_color", Color(0.27, 0.19, 0.12))
	_label.add_theme_font_size_override("font_size", 15)
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 44.0
	_label.offset_right = -44.0
	_label.offset_top = 8.0
	_label.offset_bottom = -8.0
	add_child(_label)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

	visible = false


func show_rewards(rewards: Dictionary, message: String) -> void:
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
	_timer.stop()
	modulate.a = 1.0

	var parts: Array[String] = []
	var keys := rewards.keys()
	keys.sort()
	for key in keys:
		var item_key := String(key)
		var count := int(rewards[key])
		parts.append("%s×%d" % [_resolve_name(item_key), count])

	if parts.is_empty():
		_label.text = message
	else:
		_label.text = "采集获得：" + "、".join(PackedStringArray(parts))

	if not parts.is_empty() and message.contains("传闻"):
		_label.text += " / 听到传闻"

	visible = true
	_timer.start(DISPLAY_DURATION)


func _on_timeout() -> void:
	_current_tween = create_tween()
	_current_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_current_tween.tween_callback(func():
		if is_instance_valid(self):
			visible = false
	)


func _resolve_name(key: String) -> String:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.craft != null:
		var item: Dictionary = gm.craft.get_item(key)
		if not item.is_empty():
			return String(item.get("name", key))
	return key


static func _toast_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var texture := load(PANEL_TEXTURE) as Texture2D
	if texture == null:
		return style
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(texture.get_width(), texture.get_height()))
	style.set_content_margin(SIDE_LEFT, 44.0)
	style.set_content_margin(SIDE_RIGHT, 44.0)
	style.set_content_margin(SIDE_TOP, 8.0)
	style.set_content_margin(SIDE_BOTTOM, 8.0)
	return style
