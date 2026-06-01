extends Node


func _ready() -> void:
	var panel := Panel.new()
	ThemeColors.style_brush_panel(panel)
	assert(panel.get_theme_stylebox("panel") != null)
	var button := Button.new()
	button.text = "设置"
	ThemeColors.style_brush_button(button)
	assert(button.get_theme_stylebox("normal") != null)
	# 像素字：菜单按钮使用 fusion-pixel 字体。
	var btn_font := button.get_theme_font("font")
	assert(btn_font != null)
	assert(btn_font.resource_path == ThemeColors.MENU_FONT_PATH)
	var marker := button.get_node("BrushHoverMarker") as TextureRect
	assert(marker != null)
	# 居中短下划线：按钮中间 40%，约 3px 高，随按钮缩放。
	assert(is_equal_approx(marker.anchor_left, 0.3))
	assert(is_equal_approx(marker.anchor_right, 0.7))
	assert(is_equal_approx(marker.anchor_top, 1.0))
	assert(is_equal_approx(marker.anchor_bottom, 1.0))
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
