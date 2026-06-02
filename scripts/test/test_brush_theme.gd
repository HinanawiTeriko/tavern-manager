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
	var popup := PopupMenu.new()
	ThemeColors.style_brush_popup(popup)
	assert(popup.get_theme_stylebox("panel") != null)
	assert(popup.get_theme_stylebox("hover") != null)
	assert(popup.get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH)

	var option := OptionButton.new()
	ThemeColors.style_brush_option_button(option)
	assert(option.get_popup().get_theme_stylebox("panel") != null)

	var slider := HSlider.new()
	ThemeColors.style_brush_slider(slider)
	assert(slider.get_theme_stylebox("slider") != null)
	assert(slider.get_theme_icon("grabber") != null)
	assert(slider.get_theme_icon("grabber_highlight") != null)

	var content_panel := PanelContainer.new()
	ThemeColors.style_brush_content_panel(content_panel)
	assert(content_panel.get_theme_stylebox("panel") != null)

	var slot := ColorRect.new()
	ThemeColors.style_shortcut_slot(slot)
	assert(slot.get_node_or_null("BrushBackground") != null)
	ThemeColors.set_shortcut_slot_hover(slot, true)
	assert(slot.get_node("BrushBackground").modulate == ThemeColors.AMBER_PRIMARY)
	ThemeColors.set_shortcut_slot_hover(slot, false)
	assert(slot.get_node("BrushBackground").modulate == Color.WHITE)

	assert(ResourceLoader.exists(ThemeColors.MENU_BRUSH_SLIDER_TRACK))
	assert(ResourceLoader.exists(ThemeColors.MENU_BRUSH_SLIDER_GRABBER))
	panel.free()
	button.free()
	tab_button.free()
	popup.free()
	option.free()
	slider.free()
	content_panel.free()
	slot.free()
	print("[TEST-BRUSH-THEME] ALL PASS")
	get_tree().quit()
