extends Node

const TEST_PATH := "user://test_settings_panel.cfg"

var _checks := 0
var _failures := 0


func _ready() -> void:
	var panel: SettingsPanel = preload("res://scenes/ui/SettingsPanel.tscn").instantiate()
	add_child(panel)
	var manager := SettingsManager.new(TEST_PATH)
	manager.clear_settings()
	manager.load_settings()
	panel.configure(manager)
	panel.open()
	_ok(panel.visible, "settings panel opens")
	_ok(panel.is_open(), "settings panel reports open")
	_ok(panel.get_node_or_null("Shade/Panel/QuitBtn") == null, "settings panel does not create a quit game button")
	var tutorial_reset_count := [0]
	panel.tutorial_reset_requested.connect(func(): tutorial_reset_count[0] += 1)
	var reset_tutorial_btn := panel.get_node_or_null("Shade/Panel/ResetTutorialButton") as Button
	_ok(reset_tutorial_btn != null, "settings panel exposes a reset tutorial button")
	_ok(reset_tutorial_btn != null and reset_tutorial_btn.text == "重置教程", "reset tutorial button uses clear text")
	if reset_tutorial_btn != null:
		reset_tutorial_btn.emit_signal("pressed")
	_ok(tutorial_reset_count[0] == 1, "reset tutorial button emits one tutorial reset request")
	var mode := panel.get_node("Shade/Panel/Mode") as OptionButton
	var resolution := panel.get_node("Shade/Panel/Resolution") as OptionButton
	var volume := panel.get_node("Shade/Panel/Volume") as HSlider
	var volume_track := panel.get_node("Shade/Panel/VolumeTrack") as TextureRect
	_ok(mode.get_popup().has_theme_stylebox_override("panel"), "mode popup uses brush panel")
	_ok(resolution.get_popup().has_theme_stylebox_override("panel"), "resolution popup uses brush panel")
	_ok(mode.get_popup().get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH, "mode popup uses menu font")
	_ok(resolution.get_popup().get_theme_font("font").resource_path == ThemeColors.MENU_FONT_PATH, "resolution popup uses menu font")
	_assert_popup_icons(mode.get_popup())
	_assert_popup_icons(resolution.get_popup())
	_ok(volume.has_theme_stylebox_override("slider"), "volume slider uses brush style")
	_ok(volume.has_theme_icon_override("grabber"), "volume slider uses brush grabber")
	_ok(volume.get_theme_icon("grabber").resource_path == ThemeColors.MENU_BRUSH_SLIDER_GRABBER, "volume slider grabber texture is correct")
	_ok(volume_track.texture.resource_path == ThemeColors.MENU_BRUSH_SLIDER_TRACK, "volume slider track texture is correct")
	panel._on_mode_selected(1)
	_ok(manager.fullscreen, "mode selection updates fullscreen")
	panel._on_resolution_selected(1)
	_ok(manager.resolution == Vector2i(1600, 900), "resolution selection updates settings")
	panel._on_volume_changed(42.0)
	_ok(manager.master_volume_percent == 42.0, "volume selection updates settings")
	panel.close()
	_ok(not panel.visible, "settings panel closes")
	_ok(not panel.is_open(), "settings panel reports closed")
	manager.set_master_volume_percent(100.0)
	manager.clear_settings()
	panel.free()
	_finish()


func _assert_popup_icons(popup: PopupMenu) -> void:
	for icon_name in ["checked", "unchecked", "radio_checked", "radio_unchecked", "submenu", "submenu_mirrored"]:
		_ok(popup.has_theme_icon_override(icon_name), "popup icon override exists: " + icon_name)


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-SETTINGS-PANEL] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-SETTINGS-PANEL] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-SETTINGS-PANEL] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
