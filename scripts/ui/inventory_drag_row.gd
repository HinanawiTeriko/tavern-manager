class_name InventoryDragRow
extends Button

var item_key: String = ""


func configure(key: String, display_text: String, item_icon: Texture2D) -> void:
	item_key = key
	text = display_text
	icon = item_icon
	expand_icon = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	ThemeColors.style_brush_button(self, 14)


func _get_drag_data(_at_position: Vector2):
	if item_key == "":
		return null
	var preview := Label.new()
	preview.text = text
	ThemeColors.style_brush_label(preview, 14)
	set_drag_preview(preview)
	return {"item_key": item_key}
