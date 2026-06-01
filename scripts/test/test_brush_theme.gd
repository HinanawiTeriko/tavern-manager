extends Node


func _ready() -> void:
	var panel := Panel.new()
	ThemeColors.style_brush_panel(panel)
	assert(panel.get_theme_stylebox("panel") != null)
	var button := Button.new()
	button.text = "设置"
	ThemeColors.style_brush_button(button)
	assert(button.get_theme_stylebox("normal") != null)
	assert(button.get_node_or_null("BrushHoverMarker") != null)
	ThemeColors.set_brush_selected(button, true)
	assert(button.get_node("BrushHoverMarker").visible)
	ThemeColors.set_brush_selected(button, false)
	assert(not button.get_node("BrushHoverMarker").visible)
	var tab_button := Button.new()
	ThemeColors.style_brush_tab_button(tab_button)
	assert(tab_button.get_theme_stylebox("normal") != null)
	panel.free()
	button.free()
	tab_button.free()
	print("[TEST-BRUSH-THEME] ALL PASS")
	get_tree().quit()
