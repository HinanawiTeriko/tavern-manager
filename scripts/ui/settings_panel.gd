class_name SettingsPanel
extends Control

signal closed
signal tutorial_reset_requested

var _settings: SettingsManager
var _syncing := false

@onready var _panel: Panel = $Shade/Panel
@onready var _mode: OptionButton = $Shade/Panel/Mode
@onready var _resolution: OptionButton = $Shade/Panel/Resolution
@onready var _volume: HSlider = $Shade/Panel/Volume
@onready var _volume_value: Label = $Shade/Panel/VolumeValue
@onready var _bgm_volume: HSlider
@onready var _bgm_volume_value: Label
@onready var _reset_tutorial_button: Button = $Shade/Panel/ResetTutorialButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ThemeColors.style_brush_panel(_panel)
	ThemeColors.style_brush_button($Shade/Panel/CloseButton)
	ThemeColors.style_brush_button(_reset_tutorial_button, 14)
	ThemeColors.style_brush_option_button(_mode)
	ThemeColors.style_brush_option_button(_resolution)
	ThemeColors.style_brush_slider(_volume)
	ThemeColors.style_brush_label($Shade/Panel/Title, 22, ThemeColors.AMBER_PRIMARY)
	ThemeColors.style_brush_label($Shade/Panel/ModeLabel)
	ThemeColors.style_brush_label($Shade/Panel/ResolutionLabel)
	ThemeColors.style_brush_label($Shade/Panel/VolumeLabel)
	ThemeColors.style_brush_label(_volume_value, 16, ThemeColors.AMBER_PRIMARY)

	# BGM 音量 — 轨道贴图（与主音量样式一致）
	var bgm_track := TextureRect.new()
	bgm_track.name = "BGMVolumeTrack"
	bgm_track.layout_mode = 0
	bgm_track.offset_left = 200; bgm_track.offset_top = 260
	bgm_track.offset_right = 400; bgm_track.offset_bottom = 276
	bgm_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bgm_track.texture = preload("res://assets/textures/ui/menu_brush_slider_track.png")
	bgm_track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bgm_track.stretch_mode = TextureRect.STRETCH_KEEP
	$Shade/Panel.add_child(bgm_track)

	_bgm_volume = HSlider.new()
	_bgm_volume.name = "BGMVolume"
	_bgm_volume.layout_mode = 0
	_bgm_volume.offset_left = 200; _bgm_volume.offset_top = 252
	_bgm_volume.offset_right = 400; _bgm_volume.offset_bottom = 284
	_bgm_volume.max_value = 100.0
	_bgm_volume.value = 80.0
	ThemeColors.style_brush_slider(_bgm_volume)
	$Shade/Panel.add_child(_bgm_volume)

	var bgm_label := Label.new()
	bgm_label.name = "BGMVolumeLabel"
	bgm_label.layout_mode = 0
	bgm_label.offset_left = 40; bgm_label.offset_top = 254
	bgm_label.offset_right = 180; bgm_label.offset_bottom = 286
	bgm_label.text = "游戏音乐"
	bgm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ThemeColors.style_brush_label(bgm_label)
	$Shade/Panel.add_child(bgm_label)

	_bgm_volume_value = Label.new()
	_bgm_volume_value.name = "BGMVolumeValue"
	_bgm_volume_value.layout_mode = 0
	_bgm_volume_value.offset_left = 408; _bgm_volume_value.offset_top = 254
	_bgm_volume_value.offset_right = 460; _bgm_volume_value.offset_bottom = 286
	_bgm_volume_value.text = "80%"
	_bgm_volume_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ThemeColors.style_brush_label(_bgm_volume_value, 16, ThemeColors.AMBER_PRIMARY)
	$Shade/Panel.add_child(_bgm_volume_value)
	_mode.clear()
	_mode.add_item("窗口化")
	_mode.add_item("全屏")
	_resolution.clear()
	for size in SettingsManager.RESOLUTIONS:
		_resolution.add_item("%d x %d" % [size.x, size.y])
	_mode.item_selected.connect(_on_mode_selected)
	_resolution.item_selected.connect(_on_resolution_selected)
	_volume.value_changed.connect(_on_volume_changed)
	_bgm_volume.value_changed.connect(_on_bgm_volume_changed)
	_reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)
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


func _on_bgm_volume_changed(value: float) -> void:
	_bgm_volume_value.text = "%d%%" % int(value)
	if not _syncing and _settings != null:
		_settings.set_bgm_volume_percent(value)


func _on_reset_tutorial_pressed() -> void:
	tutorial_reset_requested.emit()


func _sync_from_settings() -> void:
	if _settings == null or not is_node_ready():
		return
	_syncing = true
	_mode.select(1 if _settings.fullscreen else 0)
	_resolution.select(SettingsManager.RESOLUTIONS.find(_settings.resolution))
	_volume.value = _settings.master_volume_percent
	_volume_value.text = "%d%%" % int(_settings.master_volume_percent)
	_bgm_volume.value = _settings.bgm_volume_percent
	_bgm_volume_value.text = "%d%%" % int(_settings.bgm_volume_percent)
	_syncing = false
