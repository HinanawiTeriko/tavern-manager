extends Node

const TEST_PATH := "user://test_settings.cfg"


func _ready() -> void:
	_test_missing_file_uses_defaults()
	_test_save_and_reload()
	_test_setters_persist()
	_test_invalid_values_are_normalized()
	print("[TEST-SETTINGS] ALL PASS")
	get_tree().quit()


func _new_manager() -> SettingsManager:
	var manager := SettingsManager.new(TEST_PATH)
	manager.clear_settings()
	return manager


func _test_missing_file_uses_defaults() -> void:
	var manager := _new_manager()
	manager.load_settings()
	assert(not manager.fullscreen)
	assert(manager.resolution == Vector2i(1280, 720))
	assert(manager.master_volume_percent == 100.0)


func _test_save_and_reload() -> void:
	var manager := _new_manager()
	manager.fullscreen = true
	manager.resolution = Vector2i(1600, 900)
	manager.master_volume_percent = 35.0
	assert(manager.save_settings() == OK)
	var reloaded := SettingsManager.new(TEST_PATH)
	reloaded.load_settings()
	assert(reloaded.fullscreen)
	assert(reloaded.resolution == Vector2i(1600, 900))
	assert(reloaded.master_volume_percent == 35.0)
	reloaded.apply_all()
	reloaded.master_volume_percent = 100.0
	reloaded.apply_all()
	reloaded.clear_settings()


func _test_invalid_values_are_normalized() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "width", 123)
	config.set_value("display", "height", 456)
	config.set_value("audio", "master_volume_percent", 180.0)
	assert(config.save(TEST_PATH) == OK)
	var manager := SettingsManager.new(TEST_PATH)
	manager.load_settings()
	assert(manager.resolution == Vector2i(1280, 720))
	assert(manager.master_volume_percent == 100.0)
	manager.clear_settings()


func _test_setters_persist() -> void:
	var manager := _new_manager()
	manager.set_fullscreen(true)
	manager.set_resolution(Vector2i(1920, 1080))
	manager.set_master_volume_percent(0.0)
	var reloaded := SettingsManager.new(TEST_PATH)
	reloaded.load_settings()
	assert(reloaded.fullscreen)
	assert(reloaded.resolution == Vector2i(1920, 1080))
	assert(reloaded.master_volume_percent == 0.0)
	manager.set_master_volume_percent(100.0)
	manager.clear_settings()
