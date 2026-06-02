class_name SettingsPanel
extends Control

signal closed

var _settings: SettingsManager
var _syncing := false

@onready var _panel: Panel = $Shade/Panel
@onready var _mode: OptionButton = $Shade/Panel/Mode
@onready var _resolution: OptionButton = $Shade/Panel/Resolution
@onready var _volume: HSlider = $Shade/Panel/Volume
@onready var _volume_value: Label = $Shade/Panel/VolumeValue


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ThemeColors.style_brush_panel(_panel)
	ThemeColors.style_brush_button($Shade/Panel/CloseButton)
	ThemeColors.style_brush_option_button(_mode)
	ThemeColors.style_brush_option_button(_resolution)
	ThemeColors.style_brush_slider(_volume)
	ThemeColors.style_brush_label($Shade/Panel/Title, 22, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Shade/Panel/ModeLabel)
	ThemeColors.style_brush_label($Shade/Panel/ResolutionLabel)
	ThemeColors.style_brush_label($Shade/Panel/VolumeLabel)
	ThemeColors.style_brush_label(_volume_value, 16, ThemeColors.AMBER_PRIMARY)
	_mode.clear()
	_mode.add_item("窗口化")
	_mode.add_item("全屏")
	_resolution.clear()
	for size in SettingsManager.RESOLUTIONS:
		_resolution.add_item("%d x %d" % [size.x, size.y])
	_mode.item_selected.connect(_on_mode_selected)
	_resolution.item_selected.connect(_on_resolution_selected)
	_volume.value_changed.connect(_on_volume_changed)
	$Shade/Panel/CloseButton.pressed.connect(close)
	hide()
	_sync_from_settings()


func configure(settings: SettingsManager) -> void:
	_settings = settings
	_sync_from_settings()


func open() -> void:
	show()
	_sync_from_settings()


func close() -> void:
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


func _on_mode_selected(index: int) -> void:
	if not _syncing and _settings != null:
		_settings.set_fullscreen(index == 1)


func _on_resolution_selected(index: int) -> void:
	if not _syncing and _settings != null:
		_settings.set_resolution(SettingsManager.RESOLUTIONS[index])


func _on_volume_changed(value: float) -> void:
	_volume_value.text = "%d%%" % int(value)
	if not _syncing and _settings != null:
		_settings.set_master_volume_percent(value)


func _sync_from_settings() -> void:
	if _settings == null or not is_node_ready():
		return
	_syncing = true
	_mode.select(1 if _settings.fullscreen else 0)
	_resolution.select(SettingsManager.RESOLUTIONS.find(_settings.resolution))
	_volume.value = _settings.master_volume_percent
	_volume_value.text = "%d%%" % int(_settings.master_volume_percent)
	_syncing = false
