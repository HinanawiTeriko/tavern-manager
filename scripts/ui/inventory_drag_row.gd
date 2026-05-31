class_name InventoryDragRow
extends Button

var item_key: String = ""


func configure(key: String, display_text: String) -> void:
	item_key = key
	text = display_text


func _get_drag_data(_at_position: Vector2):
	if item_key == "":
		return null
	var preview := Label.new()
	preview.text = text
	preview.add_theme_color_override("font_color", Color.WHITE)
	set_drag_preview(preview)
	return {"item_key": item_key}
