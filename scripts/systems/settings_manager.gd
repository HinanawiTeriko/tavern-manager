class_name SettingsManager
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const DEFAULT_MASTER_VOLUME_PERCENT := 100.0

var _path: String
var fullscreen := false
var resolution := DEFAULT_RESOLUTION
var master_volume_percent := DEFAULT_MASTER_VOLUME_PERCENT


func _init(path: String = SETTINGS_PATH) -> void:
	_path = path


func load_and_apply() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	reset_defaults()
	var config := ConfigFile.new()
	if config.load(_path) != OK:
		return
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	resolution = _normalize_resolution(Vector2i(
		int(config.get_value("display", "width", DEFAULT_RESOLUTION.x)),
		int(config.get_value("display", "height", DEFAULT_RESOLUTION.y)),
	))
	master_volume_percent = clampf(
		float(config.get_value("audio", "master_volume_percent", DEFAULT_MASTER_VOLUME_PERCENT)),
		0.0,
		100.0,
	)


func save_settings() -> int:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	config.set_value("audio", "master_volume_percent", master_volume_percent)
	return config.save(_path)


func clear_settings() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_display()
	save_settings()


func set_resolution(value: Vector2i) -> void:
	resolution = _normalize_resolution(value)
	_apply_display()
	save_settings()


func set_master_volume_percent(value: float) -> void:
	master_volume_percent = clampf(value, 0.0, 100.0)
	_apply_audio()
	save_settings()


func apply_all() -> void:
	_apply_display()
	_apply_audio()


func reset_defaults() -> void:
	fullscreen = false
	resolution = DEFAULT_RESOLUTION
	master_volume_percent = DEFAULT_MASTER_VOLUME_PERCENT


func _normalize_resolution(value: Vector2i) -> Vector2i:
	return value if RESOLUTIONS.has(value) else DEFAULT_RESOLUTION


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if not fullscreen:
		DisplayServer.window_set_size(resolution)


func _apply_audio() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	var muted := master_volume_percent <= 0.0
	AudioServer.set_bus_mute(bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume_percent / 100.0))
