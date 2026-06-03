class_name InventoryDragRow
extends Button

signal open_requested(item_key: String)

var item_key: String = ""
var is_readable: bool = false


func configure(key: String, display_text: String, item_icon: Texture2D) -> void:
	item_key = key
	text = display_text
	icon = item_icon
	expand_icon = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	ThemeColors.style_brush_button(self, 14)


func configure_readable(key: String, display_text: String, item_icon: Texture2D) -> void:
	configure(key, display_text, item_icon)
	is_readable = true
	# 可阅读物品加上视觉标记
	text = "📄 " + display_text


func _get_drag_data(_at_position: Vector2):
	if item_key == "":
		return null
	var preview := Label.new()
	preview.text = text
	ThemeColors.style_brush_label(preview, 14)
	set_drag_preview(preview)
	return {"item_key": item_key}


func _gui_input(event: InputEvent) -> void:
	if not is_readable:
		return
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.double_click:
		open_requested.emit(item_key)
		accept_event()
