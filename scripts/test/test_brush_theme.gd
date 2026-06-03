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
	assert(is_equal_approx(marker.anchor_left, 0.5))
	assert(is_equal_approx(marker.anchor_right, 0.5))
	assert(is_equal_approx(marker.anchor_top, 1.0))
	assert(is_equal_approx(marker.anchor_bottom, 1.0))
	assert(is_equal_approx(marker.offset_left, -48.0))
	assert(is_equal_approx(marker.offset_right, 48.0))
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
	_assert_brush_popup_icons(popup)

	var option := OptionButton.new()
	ThemeColors.style_brush_option_button(option)
	assert(option.get_popup().get_theme_stylebox("panel") != null)
	_assert_brush_popup_icons(option.get_popup())

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
	var grabber_texture := load(ThemeColors.MENU_BRUSH_SLIDER_GRABBER) as Texture2D
	assert(grabber_texture.get_width() <= 20)
	assert(grabber_texture.get_height() <= 40)
	assert(_count_nontransparent_colors(ThemeColors.MENU_BRUSH_SLIDER_GRABBER) >= 8)
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


func _count_nontransparent_colors(path: String) -> int:
	var image := Image.load_from_file(path)
	assert(image != null)
	var colors := {}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.01:
				colors[color.to_html(true)] = true
	return colors.size()


func _assert_brush_popup_icons(popup: PopupMenu) -> void:
	for icon_name in ["checked", "unchecked", "radio_checked", "radio_unchecked", "submenu", "submenu_mirrored"]:
		assert(popup.has_theme_icon_override(icon_name))
		var icon := popup.get_theme_icon(icon_name)
		assert(icon != null)
		assert(icon.get_width() <= 16)
		assert(icon.get_height() <= 16)
