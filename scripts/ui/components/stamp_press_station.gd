class_name StampPressStation
extends Node2D

signal stamp_completed(target_tag: String)

const HANDLE_REST_OFFSET := Vector2(0, -86)
const HEAD_REST_OFFSET := Vector2(0, -18)
const PIN_REST_OFFSET := Vector2(68, -92)
const HANDLE_TRAVEL := 72.0
const HEAD_TRAVEL_RATIO := 0.72
const HANDLE_HIT_SIZE := Vector2(128, 180)
const COMPLETE_THRESHOLD := 0.92
const BASE_TEXTURE := "res://assets/ui/generated/investigation/clearing_table/stamp_station/stamp_station_base.png"
const HANDLE_TEXTURE := "res://assets/ui/generated/investigation/clearing_table/stamp_station/stamp_station_handle.png"
const HEAD_TEXTURE := "res://assets/ui/generated/investigation/clearing_table/stamp_station/stamp_station_head.png"
const PIN_TEXTURE := "res://assets/ui/generated/investigation/clearing_table/stamp_station/stamp_station_pin.png"
const IMPRINT_TEXTURE := "res://assets/ui/generated/investigation/clearing_table/stamp_station/stamp_station_imprint.png"
const SOCKET_IDLE_TEXTURE := "res://assets/ui/generated/investigation/clearing_table/stamp_station/stamp_station_socket_idle.png"
const SOCKET_READY_TEXTURE := "res://assets/ui/generated/investigation/clearing_table/stamp_station/stamp_station_socket_ready.png"
const SOCKET_BLOCKED_TEXTURE := "res://assets/ui/generated/investigation/clearing_table/stamp_station/stamp_station_socket_blocked.png"

enum PressState {
	DISABLED,
	READY,
	PRESSING,
	BLOCKED,
	COMPLETED,
}

@onready var _base: Sprite2D = $Base
@onready var _handle: Sprite2D = $Handle
@onready var _head: Sprite2D = $Head
@onready var _pin: Sprite2D = $Pin
@onready var _socket_highlight: Sprite2D = $SocketHighlight
@onready var _imprint_template: Sprite2D = $ImprintTemplate

var _state: PressState = PressState.DISABLED
var _target_tag := ""
var _target_node: Node2D = null
var _can_press := false
var _dragging := false
var _drag_start_y := 0.0
var _drag_start_progress := 0.0
var _press_progress := 0.0
var _socket_idle_texture: Texture2D = null
var _socket_ready_texture: Texture2D = null
var _socket_blocked_texture: Texture2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_component_textures()
	_apply_progress(0.0)
	_set_state(PressState.DISABLED)


func arm(target_tag: String, target_node: Node2D, can_press: bool) -> void:
	_target_tag = target_tag
	_target_node = target_node
	_can_press = can_press
	_dragging = false
	_apply_progress(0.0)
	_set_state(PressState.READY if _can_press else PressState.DISABLED)


func set_press_enabled(can_press: bool) -> void:
	_can_press = can_press
	if _target_tag == "" or _state == PressState.COMPLETED:
		return
	if _dragging:
		return
	_set_state(PressState.READY if _can_press else PressState.DISABLED)


func disarm() -> void:
	_target_tag = ""
	_target_node = null
	_can_press = false
	_dragging = false
	_apply_progress(0.0)
	_set_state(PressState.DISABLED)


func target_tag() -> String:
	return _target_tag


func is_armed() -> bool:
	return _target_tag != "" and _can_press and _state != PressState.COMPLETED


func press_progress() -> float:
	return _press_progress


func handle_grab_global_position() -> Vector2:
	return to_global(HANDLE_REST_OFFSET)


func handle_pressed_global_position() -> Vector2:
	return to_global(HANDLE_REST_OFFSET + Vector2(0, HANDLE_TRAVEL))


func socket_global_position() -> Vector2:
	if _socket_highlight != null:
		return _socket_highlight.global_position
	return to_global(Vector2(0, 70))


func imprint_texture() -> Texture2D:
	return _imprint_template.texture if _imprint_template != null else null


func _input(event: InputEvent) -> void:
	if _target_tag == "" or _state == PressState.COMPLETED:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if _handle_hit_test(mouse_event.global_position):
				if not _can_press:
					_set_state(PressState.BLOCKED)
					_apply_progress(0.0)
					get_viewport().set_input_as_handled()
					return
				_dragging = true
				_drag_start_y = mouse_event.global_position.y
				_drag_start_progress = _press_progress
				_set_state(PressState.PRESSING)
				get_viewport().set_input_as_handled()
		elif _dragging:
			_dragging = false
			if _press_progress >= COMPLETE_THRESHOLD and _can_press:
				_complete_press()
			else:
				_cancel_press()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var delta_y := motion.global_position.y - _drag_start_y
		var progress := _drag_start_progress + delta_y / HANDLE_TRAVEL
		_apply_progress(clampf(progress, 0.0, 1.0))
		get_viewport().set_input_as_handled()


func _handle_hit_test(global_pos: Vector2) -> bool:
	var local_pos := to_local(global_pos)
	var rect := Rect2(HANDLE_REST_OFFSET - HANDLE_HIT_SIZE * 0.5, HANDLE_HIT_SIZE)
	return rect.has_point(local_pos)


func _complete_press() -> void:
	_dragging = false
	_apply_progress(1.0)
	_set_state(PressState.COMPLETED)
	stamp_completed.emit(_target_tag)


func _cancel_press() -> void:
	_apply_progress(0.0)
	_set_state(PressState.READY if _can_press else PressState.DISABLED)


func _apply_progress(progress: float) -> void:
	_press_progress = clampf(progress, 0.0, 1.0)
	var travel := Vector2(0, HANDLE_TRAVEL * _press_progress)
	_handle.position = HANDLE_REST_OFFSET + travel
	_head.position = HEAD_REST_OFFSET + travel * HEAD_TRAVEL_RATIO
	_pin.position = PIN_REST_OFFSET + travel * 0.35


func _set_state(state: PressState) -> void:
	_state = state
	_base.modulate = Color.WHITE
	_handle.modulate = Color.WHITE
	_head.modulate = Color.WHITE
	_pin.modulate = Color.WHITE
	match _state:
		PressState.DISABLED:
			_socket_highlight.texture = _socket_idle_texture
			_socket_highlight.modulate = Color(1, 1, 1, 0.64)
			_handle.modulate = Color(0.72, 0.72, 0.72, 0.80)
			_head.modulate = Color(0.72, 0.72, 0.72, 0.80)
		PressState.READY, PressState.PRESSING, PressState.COMPLETED:
			_socket_highlight.texture = _socket_ready_texture
			_socket_highlight.modulate = Color.WHITE
		PressState.BLOCKED:
			_socket_highlight.texture = _socket_blocked_texture
			_socket_highlight.modulate = Color.WHITE


func _load_component_textures() -> void:
	_base.texture = _load_texture(BASE_TEXTURE)
	_handle.texture = _load_texture(HANDLE_TEXTURE)
	_head.texture = _load_texture(HEAD_TEXTURE)
	_pin.texture = _load_texture(PIN_TEXTURE)
	_imprint_template.texture = _load_texture(IMPRINT_TEXTURE)
	_socket_idle_texture = _load_texture(SOCKET_IDLE_TEXTURE)
	_socket_ready_texture = _load_texture(SOCKET_READY_TEXTURE)
	_socket_blocked_texture = _load_texture(SOCKET_BLOCKED_TEXTURE)
	_socket_highlight.texture = _socket_idle_texture


func _load_texture(path: String) -> Texture2D:
	var texture := TextureManager.try_load(path)
	if texture != null:
		return texture
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("StampPressStation texture missing or invalid: " + path)
		return null
	return ImageTexture.create_from_image(image)


func _add_imprint_to_target() -> void:
	if _target_node == null or not is_instance_valid(_target_node):
		return
	if _target_node.get_node_or_null("StampImprint") != null:
		return
	var imprint := Sprite2D.new()
	imprint.name = "StampImprint"
	imprint.texture = _imprint_template.texture
	imprint.centered = true
	imprint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imprint.z_index = 90
	imprint.position = Vector2.ZERO
	imprint.scale = Vector2(0.55, 0.55)
	imprint.modulate = Color(0.13, 0.11, 0.10, 0.72)
	_target_node.add_child(imprint)
