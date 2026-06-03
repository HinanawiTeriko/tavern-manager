extends Node

const TEST_PATH := "user://test_settings_panel.cfg"


func _ready() -> void:
	var panel: SettingsPanel = preload("res://scenes/ui/SettingsPanel.tscn").instantiate()
	add_child(panel)
	var manager := SettingsManager.new(TEST_PATH)
	manager.clear_settings()
	manager.load_settings()
	panel.configure(manager)
	panel.open()
	assert(panel.visible)
	assert(panel.is_open())
	var mode := panel.get_node("Shade/Panel/Mode") as OptionButton
	var resolution := panel.get_node("Shade/Panel/Resolution") as OptionButton
	var volume := panel.get_node("Shade/Panel/Volume") as HSlider
	var volume_track := panel.get_node("Shade/Panel/VolumeTrack") as TextureRect
	assert(mode.get_popup().has_theme_stylebox_override("panel"))
	assert(resolution.get_popup().has_theme_stylebox_override("panel"))
	assert(mode.get_popup().get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH)
	assert(resolution.get_popup().get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH)
	_assert_popup_icons(mode.get_popup())
	_assert_popup_icons(resolution.get_popup())
	assert(volume.has_theme_stylebox_override("slider"))
	assert(volume.has_theme_icon_override("grabber"))
	assert(volume.get_theme_icon("grabber").resource_path == ThemeColors.MENU_BRUSH_SLIDER_GRABBER)
	assert(volume_track.texture.resource_path == ThemeColors.MENU_BRUSH_SLIDER_TRACK)
	panel._on_mode_selected(1)
	assert(manager.fullscreen)
	panel._on_resolution_selected(1)
	assert(manager.resolution == Vector2i(1600, 900))
	panel._on_volume_changed(42.0)
	assert(manager.master_volume_percent == 42.0)
	panel.close()
	assert(not panel.visible)
	assert(not panel.is_open())
	manager.set_master_volume_percent(100.0)
	manager.clear_settings()
	panel.free()
	print("[TEST-SETTINGS-PANEL] ALL PASS")
	get_tree().quit()


func _assert_popup_icons(popup: PopupMenu) -> void:
	for icon_name in ["checked", "unchecked", "radio_checked", "radio_unchecked", "submenu", "submenu_mirrored"]:
		assert(popup.has_theme_icon_override(icon_name))
