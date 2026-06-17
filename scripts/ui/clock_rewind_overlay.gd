class_name ClockRewindOverlay
extends Control

signal rewind_completed
signal rewind_cancelled

const PIXEL_FONT: Font = preload("res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf")
const CLOCK_FACE := "res://assets/textures/ui/restart_day/restart_day_clock_face.png"
const CLOCK_HAND := "res://assets/textures/ui/restart_day/restart_day_clock_hand.png"
const EVENT_PANEL := "res://assets/textures/ui/restart_day/restart_day_event_panel.png"
const BUTTON_NORMAL := "res://assets/textures/ui/restart_day/restart_day_button_normal.png"
const BUTTON_HOVER := "res://assets/textures/ui/restart_day/restart_day_button_hover.png"
const BUTTON_PRESSED := "res://assets/textures/ui/restart_day/restart_day_button_pressed.png"
const MAX_REPLAY_EVENTS := 24

var _events: Array = []
var _event_labels: Array[Label] = []
var _progress := 0.0
var _completed := false
var _dragging := false
var _last_drag_angle := 0.0
var _dragged_reverse_radians := 0.0

@onready var _clock_face: TextureRect = $ClockRoot/ClockFace
@onready var _clock_hand: TextureRect = $ClockRoot/ClockHand
@onready var _event_panel_art: TextureRect = $EventPanel/EventPanelArt
@onready var _event_list: VBoxContainer = $EventPanel/EventList
@onready var _prompt_label: Label = $EventPanel/PromptLabel
@onready var _cancel_btn: Button = $CancelBtn


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_cancel_btn.pressed.connect(_cancel)
	_apply_runtime_art()
	_apply_static_text_style()


func open_with_events(events: Array) -> void:
	_events = events.duplicate(true)
	if _events.size() > MAX_REPLAY_EVENTS:
		_events = _events.slice(_events.size() - MAX_REPLAY_EVENTS)
	_completed = false
	_dragging = false
	_dragged_reverse_radians = 0.0
	visible = true
	_render_events()
	_set_progress(0.0, false)
	grab_focus()


func get_rewind_progress() -> float:
	return _progress


func set_rewind_progress_for_test(value: float) -> void:
	_set_progress(value, true)


func _gui_input(event: InputEvent) -> void:
	if not visible or _completed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _clock_face.get_global_rect().has_point(event.global_position):
			_dragging = true
			_last_drag_angle = _angle_to_clock_center(event.global_position)
			accept_event()
		elif _dragging:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var angle := _angle_to_clock_center(event.global_position)
		var delta := wrapf(angle - _last_drag_angle, -PI, PI)
		var reverse_delta := -delta
		if reverse_delta > 0.0:
			_dragged_reverse_radians += reverse_delta
		else:
			_dragged_reverse_radians = maxf(0.0, _dragged_reverse_radians + reverse_delta * 0.35)
		_last_drag_angle = angle
		_set_progress(clampf(_dragged_reverse_radians / TAU, 0.0, 1.0), true)
		accept_event()


func _angle_to_clock_center(global_point: Vector2) -> float:
	var rect := _clock_face.get_global_rect()
	return (global_point - rect.get_center()).angle()


func _set_progress(value: float, allow_complete: bool) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_clock_hand.rotation = -TAU * _progress
	_refresh_event_visibility()
	if allow_complete and _progress >= 1.0:
		_complete()


func _complete() -> void:
	if _completed:
		return
	_completed = true
	_dragging = false
	visible = false
	rewind_completed.emit()


func _cancel() -> void:
	if not visible:
		return
	_dragging = false
	visible = false
	rewind_cancelled.emit()


func _render_events() -> void:
	for child in _event_list.get_children():
		child.queue_free()
	_event_labels.clear()
	var index := 1
	for event in _events:
		if not event is Dictionary:
			continue
		var label := Label.new()
		label.name = "Event%d" % index
		label.text = _event_text(event as Dictionary)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(360, 30)
		label.add_theme_font_override("font", PIXEL_FONT)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.86, 0.76, 0.62, 1.0))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0.025, 0.02, 0.018, 0.9))
		_event_list.add_child(label)
		_event_labels.append(label)
		index += 1
	if _event_labels.is_empty():
		var label := Label.new()
		label.name = "EventEmpty"
		label.text = "今天没有可回放的记录"
		label.add_theme_font_override("font", PIXEL_FONT)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.62, 0.56, 0.48, 1.0))
		_event_list.add_child(label)
		_event_labels.append(label)


func _event_text(event: Dictionary) -> String:
	var label := String(event.get("label", ""))
	var detail := String(event.get("detail", ""))
	if label == "":
		label = String(event.get("type", ""))
	if detail == "":
		return label
	return "%s  %s" % [label, detail]


func _refresh_event_visibility() -> void:
	var reveal_count := ceili(_progress * float(_event_labels.size()))
	for i in range(_event_labels.size()):
		var label := _event_labels[i]
		label.visible = i < reveal_count
		label.modulate.a = 1.0 if label.visible else 0.0


func _apply_static_text_style() -> void:
	_prompt_label.text = "拖动指针倒回今日"
	_prompt_label.add_theme_font_override("font", PIXEL_FONT)
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.45, 1.0))
	_prompt_label.add_theme_constant_override("outline_size", 3)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.014, 0.01, 0.9))

	_cancel_btn.text = "取消"
	_cancel_btn.add_theme_font_override("font", PIXEL_FONT)
	_cancel_btn.add_theme_font_size_override("font_size", 15)
	_cancel_btn.add_theme_color_override("font_color", Color(0.86, 0.76, 0.62, 1.0))
	_cancel_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.82, 0.46, 1.0))
	_cancel_btn.add_theme_color_override("font_pressed_color", Color(0.72, 0.64, 0.52, 1.0))
	_cancel_btn.focus_mode = Control.FOCUS_ALL


func _apply_runtime_art() -> void:
	_clock_face.texture = _load_runtime_texture(CLOCK_FACE)
	_clock_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clock_hand.texture = _load_runtime_texture(CLOCK_HAND)
	_clock_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_event_panel_art.texture = _load_runtime_texture(EVENT_PANEL)
	_event_panel_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cancel_btn.add_theme_stylebox_override("normal", _make_texture_style(BUTTON_NORMAL))
	_cancel_btn.add_theme_stylebox_override("hover", _make_texture_style(BUTTON_HOVER))
	_cancel_btn.add_theme_stylebox_override("pressed", _make_texture_style(BUTTON_PRESSED))


func _load_runtime_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path(path)
	return texture


func _make_texture_style(path: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _load_runtime_texture(path)
	return style
