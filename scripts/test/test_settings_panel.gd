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
